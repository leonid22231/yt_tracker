import 'dart:convert';

import 'package:youtrack_timer/agent/cursor_agent_client.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/loading_progress.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
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

ПРИОРИТЕТ userHint (если поле userHint задано в данных) — ЖЁСТКОЕ ПРАВИЛО:
- userHint — ГЛАВНЫЙ И ВЫСШИЙ приоритет. Выполняй ДОСЛОВНО, даже если история/оценки/
  previousPlan/эвристики противоречат.
- Короткие формы обязательны к разбору. Примеры:
  • «МИТАП 1Ч KIOSK-114» / «митап 1 ч KIOSK-114» / «meetup 60м KIOSK-114»
    → КАЖДЫЙ день из workingDays (кроме excludedDates и дат без митапа):
      estimate на issueIdReadable=KIOSK-114, minutes = max(0, 60 - уже списано мной
      на этот день по KIOSK-114). Это ЕЖЕДНЕВНАЯ задача, НЕ «1–3 дня».
  • «болел 23 июня» → 0 минут на этот день по всем задачам.
  • «с 10 по 20 митапы по 2 ч на PROJ-1» → каждый рабочий день диапазона:
      PROJ-1 по 120 мин (дополнение к YT).
- Если в userHint указан id задачи (PROJ-123) и длительность митапа — задача ДОЛЖНА
  присутствовать в estimates на ВСЕ рабочие дни периода (кроме исключений).
  Пропуск дня = ошибка. Не заменяй митап другими задачами.
- userHint сильнее правила «обычные задачи на 1–3 дня».

Правила:
- Сумма минут на каждый рабочий день = minutesPerWorkDay (см. данные).
- Задачи с isDaily=true — каждый рабочий день, обычно 30–90 мин.
- Задача митапа из userHint / meetupSettings — тоже каждый рабочий день
  (как isDaily), пока не указано иное.
- Обычные задачи (не daily и не митап): НЕ дроби на все дни периода.
  Предпочитай 1–3 дня с основной активностью.
- Крупные блоки (2–4 ч за раз) лучше, чем по 30–60 мин на каждый день подряд —
  это правило НЕ для митапа.
- Если existingWorkItems уже есть на несколько дней — дополнительные минуты только на дни без списания или с малым списанием (кроме митапа: добивай до целевых минут).
- Учитывай смены статуса, комментарии, интенсивность активности.
- ОБЯЗАТЕЛЬНО учитывай taskEstimateMinutes / taskEstimateRemainingMinutes — оценка задачи в YouTrack.
- Сумма ДОПОЛНИТЕЛЬНЫХ минут по задаче за период не должна превышать taskEstimateRemainingMinutes (если поле задано). Для митапа из userHint/meetupSettings этот потолок НЕ применяй — митап важнее оценки.
- Если оценка уже покрыта existingWorkItems — 0 дополнительных минут по этой задаче (кроме митапа).
- ОБЯЗАТЕЛЬНО учитывай existingWorkItems — уже списанное **мной** время (existingWorkItemsScope=currentUserOnly; чужие записи в задаче не включены).
- В estimates указывай ДОПОЛНИТЕЛЬНЫЕ минуты к уже списанному мной, не дублируй existingWorkItems.
- Если на день уже списано >= лимита дня по этой задаче — 0 минут в estimates для этого дня.
- Если задача неактивна в день — 0 минут, не включай в JSON (кроме митапа/daily).
- Только рабочие дни (пн–пт) из списка workingDays.
- excludedDates — дни, на которые НЕЛЬЗЯ ставить estimates (0 минут, не включай в JSON).
- meetupSettings (если задано) — minutesPerDay это ЦЕЛЕВОЙ итог митапа в день 
  (уже списанное в existingWorkItems + новые estimates). В estimates ставь только 
  ДОПОЛНИТЕЛЬНЫЕ минуты: max(0, minutesPerDay - списано на этот день по issueIdReadable).
  Если в YT уже >= minutesPerDay — 0 минут в estimates для этого дня по митапу.
  Митап из meetupSettings и из userHint равнозначны; при конфликте бери явное поле meetupSettings.

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
- userHint (если есть) — ВЫСШИЙ ПРИОРИТЕТ. Пересчитывай план строго по userHint; 
  не сохраняй прежнее распределение, если оно ему противоречит.
- «МИТАП 1Ч KIOSK-114» и аналоги — снова на КАЖДЫЙ workingDay (дополнение до целевых минут).
- Распредели время заново с учётом existingWorkItems и existingMinutesByDay.
- На каждый день: сумма ДОПОЛНИТЕЛЬНЫХ estimates по всем задачам <= minutesPerWorkDay минус existingMinutesByDay[день].
- userBudgetMinutesForPeriod (если задано у задачи) — жёсткий лимит ДОПОЛНИТЕЛЬНЫХ минут на задачу за весь период; распредели по активным дням. На митап не распространяется.
- previousPlan — предыдущее распределение (ориентир пропорций, не копируй слепо).
- excludedFromPlan — ТОЛЬКО idReadable задач, которые пользователь убрал (остальные в issues — в плане).
- excludedDates и userHint имеют приоритет над previousPlan и активностью в задачах: 
  на исключённые/больничные дни estimates = 0; митапы и прочее из userHint — как указано.
- После твоего ответа приложение само добьёт недозаполненные дни другими задачами из пула
  и заново выровняет митап — но ты всё равно обязан включить митап во все дни.
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
    PlanCalculationOptions calculationOptions = const PlanCalculationOptions(),
    /// Все задачи с вашим списанным временем (в т.ч. не assignee) — для лимита дня.
    List<IssueContext> existingContexts = const [],
  }) async {
    final options = calculationOptions.resolveMeetupFromHint();
    final hint = userHint?.trim().isNotEmpty == true
        ? userHint!.trim()
        : options.trimmedHint;
    final workingDays = options.workingDays(periodStart, periodEnd);
    final excludedFormatted = options.normalizedExcludedDates
        .map(DateUtils.formatForQuery)
        .toList();
    final meetup = options.meetup;
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
      if (excludedFormatted.isNotEmpty) 'excludedDates': excludedFormatted,
      if (meetup.isConfigured) 'meetupSettings': meetup.toJson(),
      if (hint != null) 'userHint': hint,
    };

    final promptParts = [_systemPrompt];
    if (isRecalculation) promptParts.add(_recalculationPrompt);
    if (hint != null) {
      promptParts.add(
        'ПРИОРИТЕТ userHint — ОБЯЗАТЕЛЬНО СЛЕДУЙ ДОСЛОВНО '
        '(главный источник правды; короткие формы вроде '
        '«МИТАП 1Ч KIOSK-114» = ежедневно 60 мин на KIOSK-114):\n'
        '$hint',
      );
    }
    if (excludedFormatted.isNotEmpty) {
      promptParts.add(
        'Исключённые даты (не ставь время): ${excludedFormatted.join(', ')}',
      );
    }
    if (meetup.isConfigured) {
      final meetupExcluded = meetup.normalizedExcludedDates
          .map(DateUtils.formatForQuery)
          .toList()
        ..sort();
      var meetupLine =
          'ЖЁСТКИЙ МИТАП: ${meetup.issueIdReadable} — целевой итог '
          '${meetup.minutesPerDay} мин/день '
          '(включая уже списанное в YT; в estimates только дополнение) '
          'на КАЖДЫЙ рабочий день из workingDays. '
          'Нельзя пропускать дни и нельзя ограничивать 1–3 днями.';
      if (meetupExcluded.isNotEmpty) {
        meetupLine += ', кроме дат митапа: ${meetupExcluded.join(', ')}';
      }
      promptParts.add(meetupLine);
      AppLog.instance.info(
        LogCategory.cursor,
        'Митап в промпте: ${meetup.issueIdReadable} '
        '${meetup.minutesPerDay} мин/день',
      );
    }
    final prompt =
        '${promptParts.join('\n')}\n\nДанные:\n${jsonEncode(payload)}';

    final raw = await _agent.completePrompt(prompt);
    return parseRawResponse(
      raw: raw,
      periodStart: periodStart,
      periodEnd: periodEnd,
      minutesPerWorkDay: minutesPerWorkDay,
      contexts: contexts,
      existingContexts: forExisting,
      calculationOptions: options,
    );
  }

  /// Разбор JSON-ответа Cursor Agent (в т.ч. вставленного вручную).
  static AiEstimationResult parseRawResponse({
    required String raw,
    required DateTime periodStart,
    required DateTime periodEnd,
    int minutesPerWorkDay = 480,
    List<IssueContext> contexts = const [],
    List<IssueContext> existingContexts = const [],
    PlanCalculationOptions calculationOptions = const PlanCalculationOptions(),
  }) {
    final workingDays =
        calculationOptions.workingDays(periodStart, periodEnd);
    final forExisting =
        existingContexts.isNotEmpty ? existingContexts : contexts;
    final existingByDay = _existingMinutesByDayStatic(forExisting);
    return _parseResponseStatic(
      raw,
      workingDays,
      minutesPerWorkDay,
      existingByDay,
      contexts,
      calculationOptions,
    );
  }

  /// Сжимает распределение: обычная задача — не более 3 дней в периоде.
  /// Daily и митап ([protectedIssueIds]) не схлопываются.
  static List<TimeEstimate> _consolidateEstimates(
    List<TimeEstimate> estimates,
    List<IssueContext> contexts, {
    Set<String> protectedIssueIds = const {},
  }) {
    final protected = <String>{
      for (final c in contexts)
        if (c.issue.isDaily) c.issue.idReadable.toUpperCase(),
      for (final id in protectedIssueIds) id.trim().toUpperCase(),
    };

    final byIssue = <String, List<TimeEstimate>>{};
    for (final e in estimates) {
      byIssue.putIfAbsent(e.issueIdReadable, () => []).add(e);
    }

    const maxDaysPerIssue = 3;
    final result = <TimeEstimate>[];

    for (final entry in byIssue.entries) {
      if (protected.contains(entry.key.toUpperCase())) {
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

  Map<String, int> _existingMinutesByDay(List<IssueContext> contexts) =>
      _existingMinutesByDayStatic(contexts);

  static Map<String, int> _existingMinutesByDayStatic(
    List<IssueContext> contexts,
  ) {
    final map = <String, int>{};
    for (final ctx in contexts) {
      for (final w in ctx.existingWorkItems) {
        final key = DateUtils.formatForQuery(w.date);
        map[key] = (map[key] ?? 0) + w.minutes;
      }
    }
    return map;
  }

  static AiEstimationResult _parseResponseStatic(
    String raw,
    List<DateTime> workingDays,
    int minutesPerWorkDay,
    Map<String, int> existingMinutesByDay,
    List<IssueContext> planContexts,
    PlanCalculationOptions calculationOptions,
  ) {
    final options = calculationOptions.resolveMeetupFromHint();
    final jsonStr = _extractJson(raw);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final estimatesRaw = map['estimates'] as List<dynamic>? ?? [];
    final estimates = estimatesRaw
        .map((e) => TimeEstimate.fromJson(e as Map<String, dynamic>))
        .where((e) => e.minutes > 0 && e.issueIdReadable.isNotEmpty)
        .where((e) => !options.isDayExcluded(e.date))
        .toList();

    final protected = options.protectedDailyIssueIds;
    final consolidated = _consolidateEstimates(
      estimates,
      planContexts,
      protectedIssueIds: protected,
    );
    final normalized = _normalizePerDay(
      consolidated,
      workingDays,
      minutesPerWorkDay,
      existingMinutesByDay,
      protectedIssueIds: protected,
    );

    return AiEstimationResult(
      estimates: normalized,
      summary: map['summary'] as String? ?? '',
      usedAi: true,
    );
  }

  /// Приводит сумму по каждому дню к [minutesPerWorkDay].
  /// Митап/protected оставляем как есть, масштабируем остальное.
  static List<TimeEstimate> _normalizePerDay(
    List<TimeEstimate> estimates,
    List<DateTime> workingDays,
    int minutesPerWorkDay,
    Map<String, int> existingMinutesByDay, {
    Set<String> protectedIssueIds = const {},
  }) {
    final protected = {
      for (final id in protectedIssueIds) id.trim().toUpperCase(),
    };
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

      final fixed = <TimeEstimate>[];
      final flexible = <TimeEstimate>[];
      for (final e in dayEstimates) {
        if (protected.contains(e.issueIdReadable.toUpperCase())) {
          fixed.add(e);
        } else {
          flexible.add(e);
        }
      }

      final fixedTotal = fixed.fold<int>(0, (s, e) => s + e.minutes);
      if (fixedTotal >= targetNew) {
        // День переполнен защищёнными — пропорционально ужимаем только их.
        result.addAll(
          _scaleGroup(fixed, day, targetNew),
        );
        continue;
      }

      for (final e in fixed) {
        if (e.minutes > 0) {
          result.add(
            TimeEstimate(
              issueIdReadable: e.issueIdReadable,
              date: day,
              minutes: e.minutes,
              reasoning: e.reasoning,
              confidence: e.confidence,
            ),
          );
        }
      }

      final flexibleTarget = targetNew - fixedTotal;
      if (flexible.isEmpty || flexibleTarget <= 0) continue;
      result.addAll(_scaleGroup(flexible, day, flexibleTarget));
    }
    return result;
  }

  static List<TimeEstimate> _scaleGroup(
    List<TimeEstimate> group,
    DateTime day,
    int target,
  ) {
    if (group.isEmpty || target <= 0) return const [];
    final total = group.fold<int>(0, (s, e) => s + e.minutes);
    if (total == 0) return const [];

    final result = <TimeEstimate>[];
    var allocated = 0;
    for (var i = 0; i < group.length; i++) {
      final e = group[i];
      final minutes = i == group.length - 1
          ? target - allocated
          : (e.minutes * target / total).round();
      allocated += minutes;
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
    return result;
  }

  static String _extractJson(String raw) {
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
  LoadingProgressTracker? progress,
  String? progressLabel,
}) async {
  final startDay = DateUtils.dateOnly(start);
  final endDay = DateUtils.dateOnly(end);

  await client.currentUser();

  final contexts = <IssueContext>[];
  final total = issues.length;
  for (var i = 0; i < issues.length; i++) {
    final issue = issues[i];
    if (progress != null && total > 0) {
      progress.fraction(
        (i + 1) / total,
        detail: progressLabel != null
            ? '$progressLabel · ${issue.idReadable} (${i + 1}/$total)'
            : '${issue.idReadable} (${i + 1}/$total)',
      );
    }
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
