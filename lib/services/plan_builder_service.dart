import 'package:youtrack_timer/agent/cursor_agent_client.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/models/day_timeline.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/services/ai_time_estimator.dart';
import 'package:youtrack_timer/services/day_gap_filler.dart';
import 'package:youtrack_timer/services/day_timeline_builder.dart';
import 'package:youtrack_timer/models/loading_progress.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/services/day_plan_capper.dart';
import 'package:youtrack_timer/services/meetup_allocator.dart';
import 'package:youtrack_timer/services/plan_recalculator.dart';
import 'package:youtrack_timer/services/time_distributor.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

/// Сборка плана: AI (Cursor) или равномерное распределение.
class PlanBuilderService {
  PlanBuilderService({
    YouTrackClient? youTrackClient,
    CursorAgentClient? cursorClient,
    int minutesPerWorkDay = TimeDistributor.defaultMinutesPerWorkDay,
  })  : _youTrack = youTrackClient,
        _cursor = cursorClient,
        _minutesPerWorkDay = minutesPerWorkDay,
        _distributor = TimeDistributor(minutesPerWorkDay: minutesPerWorkDay);

  final YouTrackClient? _youTrack;
  final CursorAgentClient? _cursor;
  final int _minutesPerWorkDay;
  final TimeDistributor _distributor;

  YouTrackClient get _yt {
    final client = _youTrack;
    if (client == null) {
      throw StateError('YouTrackClient не задан');
    }
    return client;
  }

  /// Загружает задачи за период.
  Future<List<YouTrackIssue>> loadIssues(
    DateTime start,
    DateTime end,
  ) =>
      _yt.fetchAssignedIssues(startDate: start, endDate: end);

  /// Строит план с AI-оценкой или fallback на равномерное распределение.
  Future<PlanBuildResult> buildPlan({
    required DateTime start,
    required DateTime end,
    required bool useAi,
    int? minutesPerWorkDay,
    PlanCalculationOptions calculationOptions = const PlanCalculationOptions(),
    LoadingProgressTracker? progress,
  }) async {
    final dayMinutes = minutesPerWorkDay ?? _minutesPerWorkDay;
    final log = AppLog.instance;
    progress?.advance('Загрузка задач из YouTrack');
    log.info(LogCategory.plan, 'Загрузка задач из YouTrack…');
    var planIssues = await loadIssues(start, end);
    if (planIssues.isEmpty) {
      progress?.advance('Поиск задач по вашим списаниям');
      log.warn(
        LogCategory.plan,
        'Нет задач assignee: me — пробуем только ваше списанное время…',
      );
      final workOnly = await _yt.fetchMyWorkTimelineIssues(
        startDate: start,
        endDate: end,
        excludeIssueIds: {},
      );
      if (workOnly.isEmpty) {
        log.warn(LogCategory.plan, 'Задачи не найдены за период');
        return PlanBuildResult(
          entries: [],
          issues: [],
          aiSummary: '',
          usedAi: false,
        );
      }
      planIssues = workOnly;
      log.info(
        LogCategory.plan,
        'Найдено ${planIssues.length} задач по work author (без assignee)',
      );
    }

    progress?.advance(
      'Загрузка истории и списаний',
      detail: '${planIssues.length} задач',
    );
    final data = await _loadContexts(
      planIssues: planIssues,
      start: start,
      end: end,
      progress: progress,
    );
    final planContexts = data.planContexts;
    final allContexts = data.allContexts;

    List<PlannedEntry> entries;
    String aiSummary = '';
    var usedAi = false;

    log.info(
      LogCategory.plan,
      'В плане ${planIssues.length} задач (assignee), '
      'для учёта списанного — ${allContexts.length}',
    );

    if (useAi && _cursor != null) {
      try {
        progress?.advance('Оценка времени через Cursor AI');
        final activityCount =
            planContexts.fold<int>(0, (s, c) => s + c.activities.length);
        final existingMin = allContexts.fold<int>(
          0,
          (s, c) => s + c.existingTotalMinutes,
        );
        final withEstimate = planContexts
            .where((c) => c.issue.estimateMinutes != null)
            .length;
        log.info(
          LogCategory.cursor,
          'Контекст AI: ${planContexts.length} задач, $activityCount событий, '
          'моё списанное (все задачи): $existingMin мин, '
          'с оценкой: $withEstimate',
        );
        _logExistingWork(log, allContexts);

        log.info(LogCategory.cursor, 'Запрос к Cursor Agent…');
        final estimator = AiTimeEstimator(_cursor);
        final aiResult = await estimator.estimate(
          contexts: planContexts,
          existingContexts: allContexts,
          periodStart: start,
          periodEnd: end,
          minutesPerWorkDay: dayMinutes,
          calculationOptions: calculationOptions,
        );
        aiSummary = aiResult.summary;
        usedAi = aiResult.usedAi;
        entries = _entriesFromAi(planIssues, aiResult.estimates);
        log.success(
          LogCategory.cursor,
          'AI-оценка: ${entries.length} записей в плане',
        );
      } catch (e) {
        log.warn(LogCategory.cursor, 'AI недоступен, равномерное распределение');
        log.debug(LogCategory.cursor, '$e');
        progress?.advance('Равномерное распределение времени');
        entries = _entriesFromEven(planIssues, start, end, calculationOptions);
      }
    } else {
      progress?.advance('Равномерное распределение времени');
      log.info(LogCategory.plan, 'Равномерное распределение…');
      entries = _entriesFromEven(planIssues, start, end, calculationOptions);
    }

    final snapshot = List<PlannedEntry>.from(entries);
    progress?.advance('Финализация плана (митап, лимиты)');
    planIssues = await _ensureMeetupIssue(
      planIssues,
      calculationOptions,
    );
    entries = _finalizeEntries(
      entries,
      planIssues,
      start,
      end,
      allContexts,
      dayMinutes,
      calculationOptions,
    );

    progress?.advance('Построение таймлайнов по дням');
    final timelines = await _buildDayTimelines(
      timelineContexts: allContexts,
      entries: entries,
      start: start,
      end: end,
      dayMinutes: dayMinutes,
      calculationOptions: calculationOptions,
    );

    return PlanBuildResult(
      entries: entries,
      issues: planIssues,
      aiSummary: aiSummary,
      usedAi: usedAi,
      baselineEntries: snapshot,
      dayTimelines: timelines,
      issueContexts: allContexts,
    );
  }

  /// Пересчёт плана через Cursor Agent (свежие данные YouTrack + ручные лимиты).
  Future<PlanBuildResult> rebuildPlanWithAi({
    required PlanBuildResult current,
    required DateTime start,
    required DateTime end,
    required Map<String, int> issueBudgetMinutes,
    required int minutesPerWorkDay,
    Set<String> excludedIssueIds = const {},
    PlanCalculationOptions calculationOptions = const PlanCalculationOptions(),
    LoadingProgressTracker? progress,
  }) async {
    final log = AppLog.instance;

    progress?.advance('Загрузка задач и списаний');
    log.info(LogCategory.plan, 'Пересчёт: загрузка задач и списанного времени…');
    final issues = await loadIssues(start, end);
    if (issues.isEmpty) {
      log.warn(LogCategory.plan, 'Пересчёт: задачи не найдены');
      return current;
    }

    final data = await _loadContexts(
      planIssues: issues,
      start: start,
      end: end,
      progress: progress,
    );
    final excluded = excludedIssueIds;
    var activeIssues =
        issues.where((i) => !excluded.contains(i.id)).toList();
    if (excluded.isNotEmpty) {
      log.info(
        LogCategory.plan,
        'Исключено из пересчёта: ${excluded.length} задач',
      );
    }

    final planContexts = data.planContexts
        .where((c) => !excluded.contains(c.issue.id))
        .toList();
    final allContexts = data.allContexts;
    _logExistingWork(log, allContexts);

    List<PlannedEntry> entries;
    String aiSummary = current.aiSummary;
    var usedAi = current.usedAi;

    final cursor = _cursor;
    if (cursor != null) {
      try {
        progress?.advance('Пересчёт через Cursor AI');
        log.info(LogCategory.cursor, 'Пересчёт через Cursor Agent…');
        final estimator = AiTimeEstimator(cursor);
        final weights = (current.baselineEntries.isNotEmpty
                ? current.baselineEntries
                : current.entries)
            .where((e) => !excluded.contains(e.issue.id))
            .toList();
        final excludedReadables = issues
            .where((i) => excluded.contains(i.id))
            .map((i) => i.idReadable)
            .toList();
        final aiResult = await estimator.estimate(
          contexts: planContexts,
          existingContexts: allContexts,
          periodStart: start,
          periodEnd: end,
          minutesPerWorkDay: minutesPerWorkDay,
          isRecalculation: true,
          issueBudgetMinutesByIssueId: issueBudgetMinutes,
          previousPlan: weights,
          excludedIssueIdsReadable: excludedReadables,
          calculationOptions: calculationOptions,
        );
        aiSummary = aiResult.summary;
        usedAi = true;
        entries = _entriesFromAi(activeIssues, aiResult.estimates);
        log.success(
          LogCategory.cursor,
          'AI-пересчёт: ${entries.length} записей',
        );
      } catch (e) {
        log.warn(LogCategory.cursor, 'AI-пересчёт недоступен, локальный пересчёт');
        log.debug(LogCategory.cursor, '$e');
        progress?.advance('Локальный пересчёт плана');
        entries = _fallbackRecalculate(
          current: current,
          start: start,
          end: end,
          issueBudgetMinutes: issueBudgetMinutes,
          minutesPerWorkDay: minutesPerWorkDay,
          excludedIssueIds: excluded,
          calculationOptions: calculationOptions,
        );
      }
    } else {
      progress?.advance('Локальный пересчёт плана');
      entries = _fallbackRecalculate(
        current: current,
        start: start,
        end: end,
        issueBudgetMinutes: issueBudgetMinutes,
        minutesPerWorkDay: minutesPerWorkDay,
        excludedIssueIds: excluded,
        calculationOptions: calculationOptions,
      );
    }

    progress?.advance('Финализация плана');
    activeIssues = await _ensureMeetupIssue(
      activeIssues,
      calculationOptions,
    );
    entries = _finalizeEntries(
      entries,
      activeIssues,
      start,
      end,
      allContexts,
      minutesPerWorkDay,
      calculationOptions,
    );
    if (activeIssues.isNotEmpty) {
      log.info(
        LogCategory.plan,
        'После добивки дней: ${entries.length} записей в плане',
      );
    }
    progress?.advance('Построение таймлайнов');
    final timelines = await _buildDayTimelines(
      timelineContexts: allContexts,
      entries: entries,
      start: start,
      end: end,
      dayMinutes: minutesPerWorkDay,
      calculationOptions: calculationOptions,
    );

    return PlanBuildResult(
      entries: entries,
      issues: issues,
      aiSummary: aiSummary,
      usedAi: usedAi,
      baselineEntries: current.baselineEntries,
      dayTimelines: timelines,
      issueContexts: allContexts,
    );
  }

  /// Строит план из готового JSON Cursor Agent (без запроса к API агента).
  ///
  /// Загружает задачи/списания из YouTrack за период и накладывает estimates из JSON.
  Future<PlanBuildResult> buildPlanFromAiJson({
    required DateTime start,
    required DateTime end,
    required String rawJson,
    int? minutesPerWorkDay,
    PlanCalculationOptions calculationOptions = const PlanCalculationOptions(),
    LoadingProgressTracker? progress,
  }) async {
    final dayMinutes = minutesPerWorkDay ?? _minutesPerWorkDay;
    final log = AppLog.instance;

    progress?.advance('Загрузка задач из YouTrack');
    log.info(LogCategory.plan, 'Построение плана из JSON Cursor…');
    log.info(LogCategory.plan, 'Загрузка задач из YouTrack…');
    var planIssues = await loadIssues(start, end);
    if (planIssues.isEmpty) {
      progress?.advance('Поиск задач по вашим списаниям');
      log.warn(
        LogCategory.plan,
        'Нет задач assignee: me — пробуем только ваше списанное время…',
      );
      final workOnly = await _yt.fetchMyWorkTimelineIssues(
        startDate: start,
        endDate: end,
        excludeIssueIds: {},
      );
      if (workOnly.isEmpty) {
        log.warn(LogCategory.plan, 'Задачи не найдены за период');
        return PlanBuildResult(
          entries: [],
          issues: [],
          aiSummary: '',
          usedAi: false,
        );
      }
      planIssues = workOnly;
    }

    progress?.advance(
      'Загрузка истории и списаний',
      detail: '${planIssues.length} задач',
    );
    final data = await _loadContexts(
      planIssues: planIssues,
      start: start,
      end: end,
      progress: progress,
    );
    final planContexts = data.planContexts;
    final allContexts = data.allContexts;

    log.info(
      LogCategory.plan,
      'В плане ${planIssues.length} задач, '
      'для учёта списанного — ${allContexts.length}',
    );
    _logExistingWork(log, allContexts);

    progress?.advance('Разбор JSON Cursor Agent');
    log.info(LogCategory.cursor, 'Разбор вставленного JSON Cursor Agent…');
    final aiResult = AiTimeEstimator.parseRawResponse(
      raw: rawJson,
      periodStart: start,
      periodEnd: end,
      minutesPerWorkDay: dayMinutes,
      contexts: planContexts,
      existingContexts: allContexts,
      calculationOptions: calculationOptions,
    );

    var entries = _entriesFromAi(planIssues, aiResult.estimates);
    log.success(
      LogCategory.cursor,
      'JSON: ${entries.length} AI-записей'
      '${aiResult.summary.isNotEmpty ? ' · ${aiResult.summary}' : ''}',
    );

    progress?.advance('Финализация плана (митап, лимиты)');
    final snapshot = List<PlannedEntry>.from(entries);
    planIssues = await _ensureMeetupIssue(
      planIssues,
      calculationOptions,
    );
    entries = _finalizeEntries(
      entries,
      planIssues,
      start,
      end,
      allContexts,
      dayMinutes,
      calculationOptions,
    );

    progress?.advance('Построение таймлайнов по дням');
    final timelines = await _buildDayTimelines(
      timelineContexts: allContexts,
      entries: entries,
      start: start,
      end: end,
      dayMinutes: dayMinutes,
      calculationOptions: calculationOptions,
    );

    return PlanBuildResult(
      entries: entries,
      issues: planIssues,
      aiSummary: aiResult.summary,
      usedAi: true,
      baselineEntries: snapshot,
      dayTimelines: timelines,
      issueContexts: allContexts,
    );
  }

  Future<({List<IssueContext> planContexts, List<IssueContext> allContexts})>
      _loadContexts({
    required List<YouTrackIssue> planIssues,
    required DateTime start,
    required DateTime end,
    LoadingProgressTracker? progress,
  }) async {
    final extraIssues = await _yt.fetchMyWorkTimelineIssues(
      startDate: start,
      endDate: end,
      excludeIssueIds: planIssues.map((i) => i.id).toSet(),
    );

    final allIssues = _mergeIssues(planIssues, extraIssues);
    final planContexts = await buildIssueContexts(
      client: _yt,
      issues: planIssues,
      start: start,
      end: end,
      progress: progress,
    );
    final allContexts = await buildIssueContexts(
      client: _yt,
      issues: allIssues,
      start: start,
      end: end,
      progress: progress,
      progressLabel: 'Доп. задачи для таймлайна',
    );

    return (planContexts: planContexts, allContexts: allContexts);
  }

  List<YouTrackIssue> _mergeIssues(
    List<YouTrackIssue> a,
    List<YouTrackIssue> b,
  ) {
    final map = {for (final i in a) i.id: i};
    for (final i in b) {
      map[i.id] = i;
    }
    return map.values.toList();
  }

  Future<List<DayTimeline>> _buildDayTimelines({
    required List<IssueContext> timelineContexts,
    required List<PlannedEntry> entries,
    required DateTime start,
    required DateTime end,
    required int dayMinutes,
    PlanCalculationOptions calculationOptions = const PlanCalculationOptions(),
  }) async {
    if (timelineContexts.isEmpty && entries.isEmpty) return [];

    return DayTimelineBuilder.build(
      contexts: timelineContexts,
      plannedEntries: entries,
      periodStart: start,
      periodEnd: end,
      targetMinutesPerDay: dayMinutes,
      excludedDates: calculationOptions.normalizedExcludedDates,
    );
  }

  void _logExistingWork(AppLog log, List<IssueContext> contexts) {
    final withWork = contexts.where((c) => c.existingTotalMinutes > 0).toList()
      ..sort(
        (a, b) =>
            b.existingTotalMinutes.compareTo(a.existingTotalMinutes),
      );
    for (final c in withWork.take(15)) {
      log.info(
        LogCategory.youtrack,
        'Моё в YT: ${c.issue.idReadable} — ${c.existingTotalMinutes} мин',
      );
    }
    if (withWork.length > 15) {
      log.info(
        LogCategory.youtrack,
        '… и ещё ${withWork.length - 15} задач со списанным временем',
      );
    }
  }

  List<PlannedEntry> _fallbackRecalculate({
    required PlanBuildResult current,
    required DateTime start,
    required DateTime end,
    required Map<String, int> issueBudgetMinutes,
    required int minutesPerWorkDay,
    Set<String> excludedIssueIds = const {},
    PlanCalculationOptions calculationOptions = const PlanCalculationOptions(),
  }) {
    final weights = (current.baselineEntries.isNotEmpty
            ? current.baselineEntries
            : current.entries)
        .where((e) => !excludedIssueIds.contains(e.issue.id))
        .toList();
    final activeIssues = current.issues
        .where((i) => !excludedIssueIds.contains(i.id))
        .toList();
    return PlanRecalculator(minutesPerWorkDay: minutesPerWorkDay).recalculate(
      issues: activeIssues,
      periodStart: start,
      periodEnd: end,
      weightEntries: weights,
      issueTotalMinutes: issueBudgetMinutes,
      options: calculationOptions,
      meetup: calculationOptions.meetup,
      existingContexts: current.issueContexts,
    );
  }

  List<PlannedEntry> _entriesFromAi(
    List<YouTrackIssue> issues,
    List<TimeEstimate> estimates,
  ) {
    final byReadable = {
      for (final i in issues) i.idReadable.toUpperCase(): i,
    };
    return estimates
        .map((e) {
          final issue = byReadable[e.issueIdReadable.toUpperCase()];
          if (issue == null) return null;
          return PlannedEntry(
            issue: issue,
            date: e.date,
            minutes: e.minutes,
            reasoning: e.reasoning,
            source: PlanSource.ai,
          );
        })
        .whereType<PlannedEntry>()
        .toList();
  }

  /// Подтягивает задачу митапа из YouTrack, если её нет в списке плана.
  Future<List<YouTrackIssue>> _ensureMeetupIssue(
    List<YouTrackIssue> issues,
    PlanCalculationOptions calculationOptions,
  ) async {
    final meetup = calculationOptions.resolveMeetupFromHint().meetup;
    if (!meetup.isConfigured) return issues;

    final target = meetup.issueIdReadable.trim().toUpperCase();
    final already = issues.any(
      (i) => i.idReadable.toUpperCase() == target,
    );
    if (already) return issues;

    try {
      final fetched = await _yt.tryFetchIssueByReadable(target);
      if (fetched == null) {
        AppLog.instance.warn(
          LogCategory.plan,
          'Митап $target: задача не найдена в YouTrack',
        );
        return issues;
      }
      AppLog.instance.info(
        LogCategory.plan,
        'Митап: добавлена задача ${fetched.idReadable} в план',
      );
      return [...issues, fetched];
    } catch (e) {
      AppLog.instance.warn(
        LogCategory.plan,
        'Митап $target: не удалось загрузить задачу ($e)',
      );
      return issues;
    }
  }

  List<PlannedEntry> _entriesFromEven(
    List<YouTrackIssue> issues,
    DateTime start,
    DateTime end,
    PlanCalculationOptions calculationOptions,
  ) {
    final planned = _distributor.buildPlan(
      issues: issues,
      periodStart: start,
      periodEnd: end,
      options: calculationOptions,
    );
    return planned
        .map(
          (p) => PlannedEntry(
            issue: p.issue,
            date: p.date,
            minutes: p.minutes,
            comment: p.comment,
            source: PlanSource.even,
          ),
        )
        .toList();
  }

  List<PlannedEntry> _finalizeEntries(
    List<PlannedEntry> entries,
    List<YouTrackIssue> issues,
    DateTime start,
    DateTime end,
    List<IssueContext> contexts,
    int minutesPerDay,
    PlanCalculationOptions calculationOptions,
  ) {
    final options = calculationOptions.resolveMeetupFromHint();
    if (options.meetup.isConfigured &&
        !calculationOptions.meetup.isConfigured) {
      AppLog.instance.info(
        LogCategory.plan,
        'Митап из подсказки AI: ${options.meetup.issueIdReadable} '
        '${options.meetup.minutesPerDay} мин/день',
      );
    }

    var result = options.filterExcludedDays(entries);
    result = MeetupAllocator.apply(
      entries: result,
      meetup: options.meetup,
      options: options,
      periodStart: start,
      periodEnd: end,
      issues: issues,
      existingContexts: contexts,
    );
    result = _fillGaps(
      result,
      issues,
      start,
      end,
      contexts,
      minutesPerDay,
      options,
    );
    result = DayPlanCapper.cap(
      entries: result,
      existingContexts: contexts,
      minutesPerDay: minutesPerDay,
      options: options,
      periodStart: start,
      periodEnd: end,
    );
    return options.filterExcludedDays(result);
  }

  /// Дни ниже нормы: добиваем из любых задач плана (созданы не позже этого дня).
  List<PlannedEntry> _fillGaps(
    List<PlannedEntry> entries,
    List<YouTrackIssue> issues,
    DateTime start,
    DateTime end,
    List<IssueContext> contexts,
    int minutesPerWorkDay,
    PlanCalculationOptions calculationOptions,
  ) {
    return DayGapFiller.fill(
      entries: entries,
      pool: issues,
      periodStart: start,
      periodEnd: end,
      existingContexts: contexts,
      minutesPerDay: minutesPerWorkDay,
      options: calculationOptions,
    );
  }

  /// Сводка минут по дням.
  Map<DateTime, int> summarizeByDay(List<PlannedEntry> entries) {
    final summary = <DateTime, int>{};
    for (final e in entries) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      summary[key] = (summary[key] ?? 0) + e.minutes;
    }
    return summary;
  }
}

class PlanBuildResult {
  PlanBuildResult({
    required this.entries,
    required this.issues,
    required this.aiSummary,
    required this.usedAi,
    this.baselineEntries = const [],
    this.dayTimelines = const [],
    this.issueContexts = const [],
  });

  final List<PlannedEntry> entries;
  final List<YouTrackIssue> issues;
  final String aiSummary;
  final bool usedAi;

  /// Исходный план после первого построения (ориентир для пересчёта).
  final List<PlannedEntry> baselineEntries;

  /// Посуточная разбивка: уже в YT + новый план.
  final List<DayTimeline> dayTimelines;

  final List<IssueContext> issueContexts;

  PlanBuildResult copyWith({
    List<PlannedEntry>? entries,
    List<PlannedEntry>? baselineEntries,
    List<DayTimeline>? dayTimelines,
    String? aiSummary,
    bool? usedAi,
  }) =>
      PlanBuildResult(
        entries: entries ?? this.entries,
        issues: issues,
        aiSummary: aiSummary ?? this.aiSummary,
        usedAi: usedAi ?? this.usedAi,
        baselineEntries: baselineEntries ?? this.baselineEntries,
        dayTimelines: dayTimelines ?? this.dayTimelines,
        issueContexts: issueContexts,
      );
}
