import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/models/day_timeline.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/services/day_timeline_builder.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/models/meetup_settings.dart';
import 'package:youtrack_timer/models/plan_calculation_options.dart';
import 'package:youtrack_timer/utils/date_utils.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/services/submit_guard.dart';
import 'package:youtrack_timer/services/submit_service.dart';
import 'package:youtrack_timer/agent/cursor_agent_client.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

final settingsStoreProvider = Provider((_) => SettingsStore());

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>(
  (ref) => SettingsNotifier(ref.watch(settingsStoreProvider)),
);

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  SettingsNotifier(this._store) : super(const AsyncValue.loading()) {
    _load();
  }

  final SettingsStore _store;

  Future<void> _load() async {
    state = AsyncValue.data(await _store.load());
  }

  Future<void> update(AppSettings settings) async {
    await _store.save(settings);
    state = AsyncValue.data(settings);
    AppLog.instance.info(LogCategory.app, 'Настройки сохранены');
  }
}

/// Состояние главного экрана: план, загрузка.
class HomeState {
  HomeState({
    this.isLoading = false,
    this.statusMessage = '',
    this.plan,
    this.startDate,
    this.endDate,
    this.hoursPerWorkDay = 8,
    this.issueBudgetMinutes = const {},
    this.excludedIssueIds = const {},
    this.recalcHint = '',
    this.excludedDates = const {},
    this.meetupSettings = const MeetupSettings(),
  });

  final bool isLoading;
  final String statusMessage;
  final PlanBuildResult? plan;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Рабочих часов в день (остальные задачи делят остаток).
  final double hoursPerWorkDay;

  /// Всего минут на задачу за период (ключ: issue.id).
  final Map<String, int> issueBudgetMinutes;

  /// Задачи, которые не попадут в запись (исключены из плана).
  final Set<String> excludedIssueIds;

  /// Подсказка для AI при пересчёте (как чат с агентом).
  final String recalcHint;

  /// Рабочие даты, исключённые из расчёта (больничный, отпуск и т.п.).
  final Set<DateTime> excludedDates;

  /// Ежедневный митап: фиксированная задача и минуты в день.
  final MeetupSettings meetupSettings;

  PlanCalculationOptions get calculationOptions => PlanCalculationOptions(
        userHint: recalcHint,
        excludedDates: excludedDates,
        meetup: meetupSettings,
      );

  int get minutesPerWorkDay => (hoursPerWorkDay * 60).round();

  /// Записи плана без исключённых задач (для проверки и записи в YT).
  List<PlannedEntry> get activeEntries =>
      plan?.entries
          .where((e) => !excludedIssueIds.contains(e.issue.id))
          .toList() ??
      const [];

  HomeState copyWith({
    bool? isLoading,
    String? statusMessage,
    PlanBuildResult? plan,
    DateTime? startDate,
    DateTime? endDate,
    double? hoursPerWorkDay,
    Map<String, int>? issueBudgetMinutes,
    Set<String>? excludedIssueIds,
    String? recalcHint,
    Set<DateTime>? excludedDates,
    MeetupSettings? meetupSettings,
  }) =>
      HomeState(
        isLoading: isLoading ?? this.isLoading,
        statusMessage: statusMessage ?? this.statusMessage,
        plan: plan ?? this.plan,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        hoursPerWorkDay: hoursPerWorkDay ?? this.hoursPerWorkDay,
        issueBudgetMinutes: issueBudgetMinutes ?? this.issueBudgetMinutes,
        excludedIssueIds: excludedIssueIds ?? this.excludedIssueIds,
        recalcHint: recalcHint ?? this.recalcHint,
        excludedDates: excludedDates ?? this.excludedDates,
        meetupSettings: meetupSettings ?? this.meetupSettings,
      );
}

final homeProvider =
    StateNotifierProvider<HomeNotifier, HomeState>((ref) => HomeNotifier(ref));

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier(this._ref) : super(HomeState(
        startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
        endDate: DateTime.now(),
      ));

  final Ref _ref;
  final _log = AppLog.instance;
  Timer? _recalcDebounce;
  int _recalcGeneration = 0;

  Future<void> buildPlan() async {
    final settings = _ref.read(settingsProvider).valueOrNull;
    if (settings == null || !settings.hasYouTrack) {
      _log.warn(LogCategory.app, 'Заполните настройки YouTrack');
      return;
    }

    _log.clear();
    _log.info(LogCategory.plan, 'Построение плана…');
    state = state.copyWith(isLoading: true, statusMessage: 'Старт…');

    try {
      final normalized = settings.normalized();
      final config = AppConfig(
        baseUrl: normalized.youTrackUrl,
        token: normalized.youTrackToken,
        startDate: state.startDate!,
        endDate: state.endDate!,
        dryRun: settings.dryRun,
      );

      _log.info(
        LogCategory.plan,
        'Период: ${state.startDate!.toIso8601String().substring(0, 10)}'
        ' — ${state.endDate!.toIso8601String().substring(0, 10)}',
      );
      if (settings.dryRun) {
        _log.warn(LogCategory.plan, 'Режим dry-run: запись в YouTrack отключена');
      }

      final ytClient = YouTrackClient(config);
      await ytClient.ping();
      _log.success(LogCategory.youtrack, 'Подключение к YouTrack OK');

      CursorAgentClient? cursorClient;
      if (settings.useAi && settings.hasCursor) {
        cursorClient = CursorAgentClient(apiKey: settings.cursorApiKey);
        _log.info(LogCategory.cursor, 'Cursor Agent включён');
      } else if (settings.useAi) {
        _log.warn(LogCategory.cursor, 'CURSOR_API_KEY не задан — равномерное распределение');
      }

      final builder = PlanBuilderService(
        youTrackClient: ytClient,
        cursorClient: cursorClient,
        minutesPerWorkDay: state.minutesPerWorkDay,
      );

      final result = await builder.buildPlan(
        start: state.startDate!,
        end: state.endDate!,
        useAi: settings.useAi,
        calculationOptions: state.calculationOptions,
      );

      cursorClient?.close();
      ytClient.close();

      final summary = result.usedAi
          ? 'AI-план: ${result.entries.length} записей'
          : 'Равномерный план: ${result.entries.length} записей';
      if (result.aiSummary.isNotEmpty) {
        _log.info(LogCategory.cursor, 'Вывод AI: ${result.aiSummary}');
      }
      _log.success(LogCategory.plan, summary);
      _log.info(LogCategory.plan, 'Задач: ${result.issues.length}');

      state = state.copyWith(
        isLoading: false,
        plan: result,
        statusMessage: summary,
        excludedIssueIds: {},
      );
    } on YouTrackApiException catch (e, st) {
      _log.error(LogCategory.youtrack, e.message, e, st);
      state = state.copyWith(isLoading: false, statusMessage: 'Ошибка YouTrack');
    } catch (e, st) {
      _log.error(LogCategory.plan, 'Сбой построения плана', e, st);
      state = state.copyWith(isLoading: false, statusMessage: 'Ошибка');
    }
  }

  /// Проверка плана — **без записи** в YouTrack (только чтение дубликатов).
  Future<void> previewSubmit() async {
    final ctx = _validateSubmitPreconditions();
    if (ctx == null) return;

    final entries = state.activeEntries;
    if (entries.isEmpty) {
      _log.warn(LogCategory.submit, 'Нет записей для отправки');
      state = state.copyWith(statusMessage: 'Все задачи исключены из плана');
      return;
    }
    _log.info(LogCategory.submit, 'Проверка ${entries.length} записей…');
    state = state.copyWith(isLoading: true, statusMessage: 'Проверка (без записи)…');

    try {
      final client = YouTrackClient(ctx.config);
      final result = await SubmitService(client).preview(
        entries: entries,
      );
      client.close();

      state = state.copyWith(
        isLoading: false,
        statusMessage:
            'Проверка: записалось бы ${result.created}, '
            'пропуск ${result.skipped}',
      );
    } catch (e, st) {
      _log.error(LogCategory.submit, 'Ошибка проверки', e, st);
      state = state.copyWith(isLoading: false, statusMessage: 'Ошибка проверки');
    }
  }

  /// Запись в YouTrack — только с [userConfirmed] и выключенным Dry-run.
  Future<void> writeToYouTrack({required bool userConfirmed}) async {
    final ctx = _validateSubmitPreconditions();
    if (ctx == null) return;

    if (ctx.settings.dryRun) {
      _log.warn(
        LogCategory.submit,
        'Запись отменена: включён Dry-run в настройках',
      );
      state = state.copyWith(
        statusMessage: 'Запись заблокирована (Dry-run)',
      );
      return;
    }

    if (!userConfirmed) {
      _log.warn(LogCategory.submit, 'Запись отменена: нет подтверждения');
      return;
    }

    final entries = state.activeEntries;
    _log.warn(LogCategory.submit, 'Старт записи в YouTrack…');
    state = state.copyWith(isLoading: true, statusMessage: 'Запись в YouTrack…');

    try {
      SubmitGuard.ensureWriteAllowed(
        dryRunEnabled: ctx.settings.dryRun,
        userConfirmed: userConfirmed,
      );

      final client = YouTrackClient(ctx.config);
      final result = await SubmitService(client).write(
        entries: entries,
        dryRunEnabled: ctx.settings.dryRun,
        userConfirmed: userConfirmed,
      );
      client.close();

      _log.success(
        LogCategory.submit,
        'Запись завершена: ${result.created} создано, '
        '${result.skipped} пропущено, ${result.failed} ошибок',
      );
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Записано в YouTrack: ${result.created}',
      );
    } on SubmitGuardException catch (e) {
      _log.warn(LogCategory.submit, e.message);
      state = state.copyWith(isLoading: false, statusMessage: 'Запись заблокирована');
    } catch (e, st) {
      _log.error(LogCategory.submit, 'Ошибка записи', e, st);
      state = state.copyWith(isLoading: false, statusMessage: 'Ошибка записи');
    }
  }

  _SubmitContext? _validateSubmitPreconditions() {
    final settings = _ref.read(settingsProvider).valueOrNull;
    final plan = state.plan;

    if (settings == null) {
      _log.warn(LogCategory.submit, 'Настройки не загружены');
      state = state.copyWith(statusMessage: 'Откройте настройки YouTrack');
      return null;
    }
    if (!settings.hasYouTrack) {
      _log.warn(LogCategory.submit, 'Не заданы URL или токен YouTrack');
      state = state.copyWith(statusMessage: 'Заполните настройки YouTrack');
      return null;
    }
    if (plan == null) {
      _log.warn(LogCategory.submit, 'Нет плана');
      state = state.copyWith(statusMessage: 'Сначала постройте план');
      return null;
    }
    if (plan.entries.isEmpty) {
      _log.warn(LogCategory.submit, 'План пустой');
      state = state.copyWith(statusMessage: 'План пустой');
      return null;
    }
    if (state.activeEntries.isEmpty) {
      _log.warn(LogCategory.submit, 'Все задачи исключены');
      state = state.copyWith(statusMessage: 'Нет задач для записи');
      return null;
    }

    final normalized = settings.normalized();
    return _SubmitContext(
      settings: normalized,
      plan: plan,
      config: AppConfig(
        baseUrl: normalized.youTrackUrl,
        token: normalized.youTrackToken,
        startDate: state.startDate!,
        endDate: state.endDate!,
        dryRun: false,
      ),
    );
  }

  void setPeriod(DateTime start, DateTime end) {
    state = state.copyWith(startDate: start, endDate: end);
    _log.debug(
      LogCategory.app,
      'Период: ${start.toIso8601String().substring(0, 10)}'
      ' — ${end.toIso8601String().substring(0, 10)}',
    );
    if (state.plan != null) _scheduleRecalculate();
  }

  /// Часов в рабочий день. [scheduleRecalc] — только после отпускания ползунка.
  void setRecalcHint(String hint) {
    state = state.copyWith(recalcHint: hint);
    if (state.plan != null) _scheduleRecalculate();
  }

  void addExcludedDate(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    if (state.excludedDates.contains(normalized)) return;
    final updated = Set<DateTime>.from(state.excludedDates)..add(normalized);
    state = state.copyWith(excludedDates: updated);
    _log.info(
      LogCategory.plan,
      'Исключена дата: ${DateUtils.formatForQuery(normalized)}',
    );
    if (state.plan != null) _scheduleRecalculate();
  }

  void removeExcludedDate(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    if (!state.excludedDates.contains(normalized)) return;
    final updated = Set<DateTime>.from(state.excludedDates)..remove(normalized);
    state = state.copyWith(excludedDates: updated);
    if (state.plan != null) _scheduleRecalculate();
  }

  void setMeetupSettings(MeetupSettings settings, {bool scheduleRecalc = true}) {
    state = state.copyWith(meetupSettings: settings);
    if (scheduleRecalc && state.plan != null) _scheduleRecalculate();
  }

  void setHoursPerWorkDay(double hours, {bool scheduleRecalc = false}) {
    final clamped = hours.clamp(1.0, 12.0);
    state = state.copyWith(hoursPerWorkDay: clamped);
    if (scheduleRecalc && state.plan != null) {
      _log.info(LogCategory.plan, 'Рабочий день: $clamped ч → пересчёт');
      _scheduleRecalculate();
    }
  }

  /// Лимит часов на задачу за период. Пересчёт только с [scheduleRecalc].
  void setIssueBudgetHours(
    String issueId,
    double hours, {
    bool scheduleRecalc = false,
  }) {
    final budgets = Map<String, int>.from(state.issueBudgetMinutes);
    if (hours <= 0) {
      budgets.remove(issueId);
    } else {
      budgets[issueId] = (hours * 60).round();
    }
    state = state.copyWith(issueBudgetMinutes: budgets);
    if (scheduleRecalc && state.plan != null) {
      _log.info(LogCategory.plan, 'Лимит $issueId: $hours ч → пересчёт');
      _scheduleRecalculate();
    }
  }

  void clearIssueBudget(String issueId, {bool scheduleRecalc = false}) {
    final budgets = Map<String, int>.from(state.issueBudgetMinutes);
    budgets.remove(issueId);
    state = state.copyWith(issueBudgetMinutes: budgets);
    if (scheduleRecalc && state.plan != null) _scheduleRecalculate();
  }

  /// Убрать задачу из плана и перераспределить часы на остальные задачи.
  void excludeIssueFromPlan(String issueId) {
    if (state.plan == null) return;

    final excluded = Set<String>.from(state.excludedIssueIds)..add(issueId);
    final budgets = Map<String, int>.from(state.issueBudgetMinutes)
      ..remove(issueId);

    state = state.copyWith(
      excludedIssueIds: excluded,
      issueBudgetMinutes: budgets,
      statusMessage: 'Задача исключена — пересчёт плана…',
    );
    _log.info(LogCategory.plan, 'Исключена из плана: $issueId → пересчёт');
    _scheduleRecalculate();
  }

  /// Вернуть задачу в план — перераспределение через AI.
  void includeIssueInPlan(String issueId) {
    if (!state.excludedIssueIds.contains(issueId)) return;
    final excluded = Set<String>.from(state.excludedIssueIds)..remove(issueId);
    state = state.copyWith(excludedIssueIds: excluded);
    _log.info(LogCategory.plan, 'Задача возвращена в план: $issueId');
    _scheduleRecalculate();
  }

  List<DayTimeline> _buildTimelines(
    PlanBuildResult plan,
    List<PlannedEntry> entries,
  ) {
    if (state.startDate == null || state.endDate == null) {
      return plan.dayTimelines;
    }
    return DayTimelineBuilder.build(
      contexts: plan.issueContexts,
      plannedEntries: entries,
      periodStart: state.startDate!,
      periodEnd: state.endDate!,
      targetMinutesPerDay: state.minutesPerWorkDay,
      excludedDates: state.calculationOptions.normalizedExcludedDates,
    );
  }

  PlanBuildResult _applyExclusions(PlanBuildResult plan) {
    if (state.excludedIssueIds.isEmpty) return plan;
    final entries = plan.entries
        .where((e) => !state.excludedIssueIds.contains(e.issue.id))
        .toList();
    return plan.copyWith(
      entries: entries,
      dayTimelines: _buildTimelines(plan, entries),
    );
  }

  /// Ручная правка минут на конкретный день (без AI-пересчёта).
  void updateEntryMinutes({
    required String issueId,
    required DateTime date,
    required int minutes,
  }) {
    final plan = state.plan;
    if (plan == null || state.startDate == null || state.endDate == null) {
      return;
    }

    final clamped = minutes.clamp(0, 12 * 60);
    final newEntries = <PlannedEntry>[];
    var changed = false;

    for (final e in plan.entries) {
      if (e.issue.id == issueId && DateUtils.isSameDay(e.date, date)) {
        changed = true;
        if (clamped > 0) {
          newEntries.add(
            PlannedEntry(
              issue: e.issue,
              date: e.date,
              minutes: clamped,
              reasoning: e.reasoning,
              source: PlanSource.manual,
            ),
          );
        }
      } else {
        newEntries.add(e);
      }
    }

    if (!changed) return;

    state = state.copyWith(
      plan: plan.copyWith(
        entries: newEntries,
        dayTimelines: _buildTimelines(plan, newEntries),
      ),
      statusMessage: 'Время обновлено (без пересчёта AI)',
    );
    _log.debug(LogCategory.plan, 'Правка $issueId ${date.toIso8601String().substring(0, 10)}: $clamped м');
  }

  void _scheduleRecalculate() {
    _recalcDebounce?.cancel();
    _recalcDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(recalculatePlan());
    });
  }

  /// Пересчёт: свежие данные YouTrack + Cursor Agent (или локальный fallback).
  Future<void> recalculatePlan() async {
    final plan = state.plan;
    if (plan == null || state.startDate == null || state.endDate == null) {
      return;
    }

    final settings = _ref.read(settingsProvider).valueOrNull;
    if (settings == null || !settings.hasYouTrack) {
      _log.warn(LogCategory.plan, 'Пересчёт: нет настроек YouTrack');
      return;
    }

    final generation = ++_recalcGeneration;
    state = state.copyWith(
      isLoading: true,
      statusMessage: 'Пересчёт через Cursor Agent…',
    );

    try {
      final normalized = settings.normalized();
      final config = AppConfig(
        baseUrl: normalized.youTrackUrl,
        token: normalized.youTrackToken,
        startDate: state.startDate!,
        endDate: state.endDate!,
        dryRun: settings.dryRun,
      );

      CursorAgentClient? cursorClient;
      if (settings.useAi && settings.hasCursor) {
        cursorClient = CursorAgentClient(apiKey: settings.cursorApiKey);
      } else {
        _log.warn(
          LogCategory.cursor,
          'Cursor API недоступен — локальный пересчёт',
        );
      }

      final ytClient = YouTrackClient(config);
      final builder = PlanBuilderService(
        youTrackClient: ytClient,
        cursorClient: cursorClient,
        minutesPerWorkDay: state.minutesPerWorkDay,
      );

      final updated = await builder.rebuildPlanWithAi(
        current: plan,
        start: state.startDate!,
        end: state.endDate!,
        issueBudgetMinutes: state.issueBudgetMinutes,
        minutesPerWorkDay: state.minutesPerWorkDay,
        excludedIssueIds: state.excludedIssueIds,
        calculationOptions: state.calculationOptions,
      );

      cursorClient?.close();
      ytClient.close();

      if (generation != _recalcGeneration) return;

      final viaAi =
          updated.usedAi && settings.useAi && settings.hasCursor;
      _log.success(
        LogCategory.plan,
        'План пересчитан: ${updated.entries.length} записей '
        '(${viaAi ? 'AI' : 'локально'})',
      );

      final filtered = _applyExclusions(updated);
      state = state.copyWith(
        isLoading: false,
        plan: filtered,
        statusMessage: viaAi
            ? 'Пересчёт AI: ${filtered.entries.length} записей'
            : 'План обновлён (${filtered.entries.length} записей)',
      );
    } on YouTrackApiException catch (e, st) {
      if (generation != _recalcGeneration) return;
      _log.error(LogCategory.youtrack, e.message, e, st);
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Ошибка пересчёта (YouTrack)',
      );
    } catch (e, st) {
      if (generation != _recalcGeneration) return;
      _log.error(LogCategory.plan, 'Ошибка пересчёта', e, st);
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Ошибка пересчёта',
      );
    }
  }

  @override
  void dispose() {
    _recalcDebounce?.cancel();
    super.dispose();
  }
}

class _SubmitContext {
  _SubmitContext({
    required this.settings,
    required this.plan,
    required this.config,
  });

  final AppSettings settings;
  final PlanBuildResult plan;
  final AppConfig config;
}
