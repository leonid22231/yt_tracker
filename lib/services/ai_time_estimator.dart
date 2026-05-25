import 'dart:convert';

import 'package:youtrack_timer/agent/cursor_agent_client.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/utils/date_utils.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

/// Оценка времени через Cursor Agent по контексту задач.
class AiTimeEstimator {
  AiTimeEstimator(this._agent);

  final CursorAgentClient _agent;

  static const _systemPrompt = '''
Ты аналитик трудозатрат в YouTrack. По истории задач оцени, сколько минут разумно 
списать на каждую задачу в каждый рабочий день периода.

Правила:
- Сумма минут на каждый рабочий день = minutesPerWorkDay (см. данные).
- Задачи с isDaily=true — каждый рабочий день, обычно 30–90 мин.
- Обычные задачи (не daily): НЕ дроби на все дни периода. Предпочитай 1–3 дня с основной активностью.
- Крупные блоки (2–4 ч за раз) лучше, чем по 30–60 мин на каждый день подряд.
- Если existingWorkItems уже есть на несколько дней — дополнительные минуты только на дни без списания или с малым списанием.
- Учитывай смены статуса, комментарии, интенсивность активности.
- ОБЯЗАТЕЛЬНО учитывай taskEstimateMinutes / taskEstimateRemainingMinutes — оценка задачи в YouTrack.
- Сумма ДОПОЛНИТЕЛЬНЫХ минут по задаче за период не должна превышать taskEstimateRemainingMinutes (если поле задано).
- Если оценка уже покрыта existingWorkItems — 0 дополнительных минут по этой задаче.
- ОБЯЗАТЕЛЬНО учитывай existingWorkItems — уже списанное **мной** время (existingWorkItemsScope=currentUserOnly; чужие записи в задаче не включены).
- В estimates указывай ДОПОЛНИТЕЛЬНЫЕ минуты к уже списанному мной, не дублируй existingWorkItems.
- Если на день уже списано >= лимита дня по этой задаче — 0 минут в estimates для этого дня.
- Если задача неактивна в день — 0 минут, не включай в JSON.
- Только рабочие дни (пн–пт) из списка workingDays.

Ответь ТОЛЬКО валидным JSON без markdown:
{
  "summary": "краткий вывод",
  "estimates": [
    {
      "issueIdReadable": "PROJ-1",
      "day": "2024-01-15",
      "minutes": 120,
      "confidence": 0.85,
      "reasoning": "почему столько"
    }
  ]
}
''';

  static const _recalculationPrompt = '''
РЕЖИМ ПЕРЕСЧЁТА (пользователь изменил лимиты или часы в день):
- Распредели время заново с учётом existingWorkItems и existingMinutesByDay.
- На каждый день: сумма ДОПОЛНИТЕЛЬНЫХ estimates по всем задачам <= minutesPerWorkDay минус existingMinutesByDay[день].
- userBudgetMinutesForPeriod (если задано у задачи) — жёсткий лимит ДОПОЛНИТЕЛЬНЫХ минут на задачу за весь период; распредели по активным дням.
- previousPlan — предыдущее распределение (ориентир пропорций, не копируй слепо).
- excludedFromPlan — ТОЛЬКО idReadable задач, которые пользователь убрал (остальные в issues — в плане).
- После твоего ответа приложение само добьёт недозаполненные дни другими задачами из пула.
''';

  Future<AiEstimationResult> estimate({
    required List<IssueContext> contexts,
    required DateTime periodStart,
    required DateTime periodEnd,
    int minutesPerWorkDay = 480,
    bool isRecalculation = false,
    Map<String, int> issueBudgetMinutesByIssueId = const {},
    List<PlannedEntry> previousPlan = const [],
    List<String> excludedIssueIdsReadable = const [],
    String? userHint,
    /// Все задачи с вашим списанным временем (в т.ч. не assignee) — для лимита дня.
    List<IssueContext> existingContexts = const [],
  }) async {
    final workingDays = DateUtils.workingDays(periodStart, periodEnd);
    final daysFormatted =
        workingDays.map(DateUtils.formatForQuery).toList();
    final forExisting =
        existingContexts.isNotEmpty ? existingContexts : contexts;
    final existingByDay = _existingMinutesByDay(forExisting);

    final issuesJson = contexts.map((c) {
      final json = c.toJson();
      final budget = issueBudgetMinutesByIssueId[c.issue.id];
      if (budget != null && budget > 0) {
        json['userBudgetMinutesForPeriod'] = budget;
      }
      return json;
    }).toList();

    final payload = {
      'periodStart': DateUtils.formatForQuery(periodStart),
      'periodEnd': DateUtils.formatForQuery(periodEnd),
      'workingDays': daysFormatted,
      'minutesPerWorkDay': minutesPerWorkDay,
      'existingMinutesByDay': existingByDay,
      'issues': issuesJson,
      if (isRecalculation) 'recalculation': true,
      if (isRecalculation && previousPlan.isNotEmpty)
        'previousPlan': previousPlan
            .map(
              (e) => {
                'issueIdReadable': e.issue.idReadable,
                'day': DateUtils.formatForQuery(e.date),
                'minutes': e.minutes,
              },
            )
            .toList(),
      if (isRecalculation && excludedIssueIdsReadable.isNotEmpty)
        'excludedFromPlan': excludedIssueIdsReadable,
      if (userHint != null && userHint.trim().isNotEmpty)
        'userHint': userHint.trim(),
    };

    final promptParts = [_systemPrompt];
    if (isRecalculation) promptParts.add(_recalculationPrompt);
    if (userHint != null && userHint.trim().isNotEmpty) {
      promptParts.add('Пожелание пользователя:\n${userHint.trim()}');
    }
    final prompt =
        '${promptParts.join('\n')}\n\nДанные:\n${jsonEncode(payload)}';

    final raw = await _agent.completePrompt(prompt);
    return _parseResponse(
      raw,
      workingDays,
      minutesPerWorkDay,
      existingByDay,
      contexts,
    );
  }

  /// Сжимает распределение: обычная задача — не более 3 дней в периоде.
  List<TimeEstimate> _consolidateEstimates(
    List<TimeEstimate> estimates,
    List<IssueContext> contexts,
  ) {
    final dailyIds = contexts
        .where((c) => c.issue.isDaily)
        .map((c) => c.issue.idReadable)
        .toSet();

    final byIssue = <String, List<TimeEstimate>>{};
    for (final e in estimates) {
      byIssue.putIfAbsent(e.issueIdReadable, () => []).add(e);
    }

    const maxDaysPerIssue = 3;
    final result = <TimeEstimate>[];

    for (final entry in byIssue.entries) {
      if (dailyIds.contains(entry.key)) {
        result.addAll(entry.value.where((e) => e.minutes > 0));
        continue;
      }

      final sorted = List<TimeEstimate>.from(entry.value)
        ..sort((a, b) => b.minutes.compareTo(a.minutes));

      final kept = sorted.take(maxDaysPerIssue).toList();
      final dropped = sorted.skip(maxDaysPerIssue);
      var overflow = dropped.fold<int>(0, (s, e) => s + e.minutes);

      if (kept.isNotEmpty && overflow > 0) {
        final top = kept.first;
        kept[0] = TimeEstimate(
          issueIdReadable: top.issueIdReadable,
          date: top.date,
          minutes: top.minutes + overflow,
          reasoning: top.reasoning,
          confidence: top.confidence,
        );
        overflow = 0;
      }

      result.addAll(kept.where((e) => e.minutes > 0));
    }

    return result;
  }

  Map<String, int> _existingMinutesByDay(List<IssueContext> contexts) {
    final map = <String, int>{};
    for (final ctx in contexts) {
      for (final w in ctx.existingWorkItems) {
        final key = DateUtils.formatForQuery(w.date);
        map[key] = (map[key] ?? 0) + w.minutes;
      }
    }
    return map;
  }

  AiEstimationResult _parseResponse(
    String raw,
    List<DateTime> workingDays,
    int minutesPerWorkDay,
    Map<String, int> existingMinutesByDay,
    List<IssueContext> planContexts,
  ) {
    final jsonStr = _extractJson(raw);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final estimatesRaw = map['estimates'] as List<dynamic>? ?? [];
    final estimates = estimatesRaw
        .map((e) => TimeEstimate.fromJson(e as Map<String, dynamic>))
        .where((e) => e.minutes > 0 && e.issueIdReadable.isNotEmpty)
        .toList();

    final consolidated = _consolidateEstimates(estimates, planContexts);
    final normalized = _normalizePerDay(
      consolidated,
      workingDays,
      minutesPerWorkDay,
      existingMinutesByDay,
    );

    return AiEstimationResult(
      estimates: normalized,
      summary: map['summary'] as String? ?? '',
      usedAi: true,
    );
  }

  /// Приводит сумму по каждому дню к [minutesPerWorkDay] (пропорционально).
  List<TimeEstimate> _normalizePerDay(
    List<TimeEstimate> estimates,
    List<DateTime> workingDays,
    int minutesPerWorkDay,
    Map<String, int> existingMinutesByDay,
  ) {
    final byDay = <String, List<TimeEstimate>>{};
    for (final e in estimates) {
      final key = DateUtils.formatForQuery(e.date);
      byDay.putIfAbsent(key, () => []).add(e);
    }

    final result = <TimeEstimate>[];
    for (final day in workingDays) {
      final key = DateUtils.formatForQuery(day);
      final dayEstimates = byDay[key] ?? [];
      if (dayEstimates.isEmpty) continue;

      final existingOnDay = existingMinutesByDay[key] ?? 0;
      final targetNew =
          (minutesPerWorkDay - existingOnDay).clamp(0, minutesPerWorkDay);
      if (targetNew == 0) continue;

      final total = dayEstimates.fold<int>(0, (s, e) => s + e.minutes);
      if (total == 0) continue;

      var allocated = 0;
      for (var i = 0; i < dayEstimates.length; i++) {
        final e = dayEstimates[i];
        int minutes;
        if (i == dayEstimates.length - 1) {
          minutes = targetNew - allocated;
        } else {
          minutes = (e.minutes * targetNew / total).round();
          allocated += minutes;
        }
        if (minutes > 0) {
          result.add(
            TimeEstimate(
              issueIdReadable: e.issueIdReadable,
              date: day,
              minutes: minutes,
              reasoning: e.reasoning,
              confidence: e.confidence,
            ),
          );
        }
      }
    }
    return result;
  }

  String _extractJson(String raw) {
    final trimmed = raw.trim();
    final fenceStart = trimmed.indexOf('```');
    if (fenceStart >= 0) {
      var inner = trimmed.substring(fenceStart + 3);
      if (inner.startsWith('json')) inner = inner.substring(4);
      final fenceEnd = inner.indexOf('```');
      if (fenceEnd >= 0) inner = inner.substring(0, fenceEnd);
      return inner.trim();
    }
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    return trimmed;
  }
}

/// Собирает контексты задач для AI.
Future<List<IssueContext>> buildIssueContexts({
  required YouTrackClient client,
  required List<YouTrackIssue> issues,
  required DateTime start,
  required DateTime end,
}) async {
  final startDay = DateUtils.dateOnly(start);
  final endDay = DateUtils.dateOnly(end);

  await client.currentUser();

  final contexts = <IssueContext>[];
  for (final issue in issues) {
    final activities = await client.fetchActivities(
      issue.id,
      start: start,
      end: end,
    );

    final allWorkItems = await client.fetchWorkItems(issue.id);
    final inPeriod = allWorkItems.where((w) {
      final d = DateUtils.dateOnly(w.date);
      return !d.isBefore(startDay) && !d.isAfter(endDay);
    }).toList();

    AppLog.instance.debug(
      LogCategory.youtrack,
      '${issue.idReadable}: work items всего ${allWorkItems.length}, '
      'в периоде ${inPeriod.length} '
      '(${inPeriod.fold<int>(0, (s, w) => s + w.minutes)} мин)',
    );

    contexts.add(
      IssueContext(
        issue: issue,
        activities: activities,
        existingWorkItems: inPeriod,
      ),
    );
  }
  return contexts;
}
