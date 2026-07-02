import 'package:youtrack_timer/agent/cursor_agent_client.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/models/day_timeline.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_context.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/services/ai_time_estimator.dart';
import 'package:youtrack_timer/services/day_gap_filler.dart';
import 'package:youtrack_timer/services/day_timeline_builder.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/services/day_plan_capper.dart';
import 'package:youtrack_timer/services/meetup_allocator.dart';
import 'package:youtrack_timer/services/plan_recalculator.dart';
import 'package:youtrack_timer/services/time_distributor.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

/// Сборка плана: AI (Cursor) или равномерное распределение.
class PlanBuilderService {
  PlanBuilderService({
    required YouTrackClient youTrackClient,
    CursorAgentClient? cursorClient,
    int minutesPerWorkDay = TimeDistributor.defaultMinutesPerWorkDay,
  })  : _youTrack = youTrackClient,
        _cursor = cursorClient,
        _minutesPerWorkDay = minutesPerWorkDay,
        _distributor = TimeDistributor(minutesPerWorkDay: minutesPerWorkDay);

  final YouTrackClient _youTrack;
  final CursorAgentClient? _cursor;
  final int _minutesPerWorkDay;
  final TimeDistributor _distributor;

  /// Загружает задачи за период.
  Future<List<YouTrackIssue>> loadIssues(
    DateTime start,
    DateTime end,
  ) =>
      _youTrack.fetchAssignedIssues(startDate: start, endDate: end);

  /// Строит план с AI-оценкой или fallback на равномерное распределение.
  Future<PlanBuildResult> buildPlan({
    required DateTime start,
    required DateTime end,
    required bool useAi,
    int? minutesPerWorkDay,
    PlanCalculationOptions calculationOptions = const PlanCalculationOptions(),
  }) async {
    final dayMinutes = minutesPerWorkDay ?? _minutesPerWorkDay;
    final log = AppLog.instance;
    log.info(LogCategory.plan, 'Загрузка задач из YouTrack…');
    var planIssues = await loadIssues(start, end);
    if (planIssues.isEmpty) {
      log.warn(
        LogCategory.plan,
        'Нет задач assignee: me — пробуем только ваше списанное время…',
      );
      final workOnly = await _youTrack.fetchMyWorkTimelineIssues(
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

    final data = await _loadContexts(
      planIssues: planIssues,
      start: start,
      end: end,
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
        entries = _entriesFromEven(planIssues, start, end, calculationOptions);
      }
    } else {
      log.info(LogCategory.plan, 'Равномерное распределение…');
      entries = _entriesFromEven(planIssues, start, end, calculationOptions);
    }

    final snapshot = List<PlannedEntry>.from(entries);
    entries = _finalizeEntries(
      entries,
      planIssues,
      start,
      end,
      allContexts,
      dayMinutes,
      calculationOptions,
    );

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
  }) async {
    final log = AppLog.instance;

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
    );
    final excluded = excludedIssueIds;
    final activeIssues =
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

  Future<({List<IssueContext> planContexts, List<IssueContext> allContexts})>
      _loadContexts({
    required List<YouTrackIssue> planIssues,
    required DateTime start,
    required DateTime end,
  }) async {
    final extraIssues = await _youTrack.fetchMyWorkTimelineIssues(
      startDate: start,
      endDate: end,
      excludeIssueIds: planIssues.map((i) => i.id).toSet(),
    );

    final allIssues = _mergeIssues(planIssues, extraIssues);
    final planContexts = await buildIssueContexts(
      client: _youTrack,
      issues: planIssues,
      start: start,
      end: end,
    );
    final allContexts = await buildIssueContexts(
      client: _youTrack,
      issues: allIssues,
      start: start,
      end: end,
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
    final byReadable = {for (final i in issues) i.idReadable: i};
    return estimates
        .map((e) {
          final issue = byReadable[e.issueIdReadable];
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
    var result = calculationOptions.filterExcludedDays(entries);
    result = MeetupAllocator.apply(
      entries: result,
      meetup: calculationOptions.meetup,
      options: calculationOptions,
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
      calculationOptions,
    );
    result = DayPlanCapper.cap(
      entries: result,
      existingContexts: contexts,
      minutesPerDay: minutesPerDay,
      options: calculationOptions,
      periodStart: start,
      periodEnd: end,
    );
    return calculationOptions.filterExcludedDays(result);
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
