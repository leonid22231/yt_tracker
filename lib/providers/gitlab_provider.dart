import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/agent/cursor_agent_client.dart';
import 'package:youtrack_timer/gitlab/gitlab_client.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/models/loading_progress.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_ai_summary.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/tracked_time_record.dart';
import 'package:youtrack_timer/models/gitlab/youtrack_gitlab_comparison.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_user_info.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_activity_service.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_ai_summarizer.dart';
import 'package:youtrack_timer/services/gitlab/youtrack_gitlab_analyzer.dart';
import 'package:youtrack_timer/services/gitlab/youtrack_tracked_time_service.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

final gitLabActivityServiceProvider = Provider((_) => GitLabActivityService());
final youTrackTrackedTimeServiceProvider =
    Provider((_) => YouTrackTrackedTimeService());
final youTrackGitLabAnalyzerProvider =
    Provider((_) => const YouTrackGitLabAnalyzer());

enum GitLabConnectionStatus {
  disconnected,
  connected,
  demo,
  error,
}

class GitLabState {
  const GitLabState({
    this.isLoading = false,
    this.isValidating = false,
    this.status = GitLabConnectionStatus.disconnected,
    this.user,
    this.activity,
    this.errorMessage = '',
    this.statusMessage = '',
    this.loadingProgress,
    this.startDate,
    this.endDate,
    this.trackedTime,
    this.timeComparison,
    this.isAiSummaryLoading = false,
    this.aiSummaryLoadingDay,
    this.aiSummary,
    this.aiSummaryError = '',
    this.aiSummaryErrorDay,
  });

  final bool isLoading;
  final bool isValidating;
  final GitLabConnectionStatus status;
  final GitLabUserInfo? user;
  final GitLabActivityData? activity;
  final String errorMessage;
  final String statusMessage;
  final LoadingProgress? loadingProgress;
  final DateTime? startDate;
  final DateTime? endDate;
  final YouTrackTrackedTimeData? trackedTime;
  final YouTrackGitLabComparison? timeComparison;
  final bool isAiSummaryLoading;
  final DateTime? aiSummaryLoadingDay;
  final GitLabAiSummary? aiSummary;
  final String aiSummaryError;
  final DateTime? aiSummaryErrorDay;

  bool get hasComparison => timeComparison != null;

  bool get hasData => activity != null && !activity!.isEmpty;
  bool get isConnected =>
      status == GitLabConnectionStatus.connected ||
      status == GitLabConnectionStatus.demo;

  GitLabState copyWith({
    bool? isLoading,
    bool? isValidating,
    GitLabConnectionStatus? status,
    GitLabUserInfo? user,
    GitLabActivityData? activity,
    String? errorMessage,
    String? statusMessage,
    LoadingProgress? loadingProgress,
    bool clearLoadingProgress = false,
    DateTime? startDate,
    DateTime? endDate,
    YouTrackTrackedTimeData? trackedTime,
    YouTrackGitLabComparison? timeComparison,
    bool? isAiSummaryLoading,
    DateTime? aiSummaryLoadingDay,
    bool clearAiSummaryLoadingDay = false,
    GitLabAiSummary? aiSummary,
    bool clearAiSummary = false,
    String? aiSummaryError,
    DateTime? aiSummaryErrorDay,
    bool clearAiSummaryError = false,
    bool clearAiSummaryErrorDay = false,
    bool clearActivity = false,
    bool clearUser = false,
    bool clearError = false,
    bool clearTrackedTime = false,
    bool clearComparison = false,
  }) =>
      GitLabState(
        isLoading: isLoading ?? this.isLoading,
        isValidating: isValidating ?? this.isValidating,
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        activity: clearActivity ? null : (activity ?? this.activity),
        errorMessage: clearError ? '' : (errorMessage ?? this.errorMessage),
        statusMessage: statusMessage ?? this.statusMessage,
        loadingProgress: clearLoadingProgress
            ? null
            : (loadingProgress ?? this.loadingProgress),
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        trackedTime: clearTrackedTime ? null : (trackedTime ?? this.trackedTime),
        timeComparison:
            clearComparison ? null : (timeComparison ?? this.timeComparison),
        isAiSummaryLoading: isAiSummaryLoading ?? this.isAiSummaryLoading,
        aiSummaryLoadingDay: clearAiSummaryLoadingDay
            ? null
            : (aiSummaryLoadingDay ?? this.aiSummaryLoadingDay),
        aiSummary: clearAiSummary ? null : (aiSummary ?? this.aiSummary),
        aiSummaryError:
            clearAiSummaryError ? '' : (aiSummaryError ?? this.aiSummaryError),
        aiSummaryErrorDay: clearAiSummaryErrorDay
            ? null
            : (aiSummaryErrorDay ?? this.aiSummaryErrorDay),
      );
}

final gitLabProvider =
    StateNotifierProvider<GitLabNotifier, GitLabState>((ref) {
  // Не watch(settingsProvider): при сохранении настроек notifier пересоздавался
  // и async-загрузка падала с "Tried to use GitLabNotifier after dispose".
  return GitLabNotifier(
    ref,
    ref.watch(gitLabActivityServiceProvider),
    ref.watch(youTrackTrackedTimeServiceProvider),
    ref.watch(youTrackGitLabAnalyzerProvider),
  );
});

class GitLabNotifier extends StateNotifier<GitLabState> {
  GitLabNotifier(
    this._ref,
    this._service,
    this._trackedTimeService,
    this._analyzer,
  )
      : super(GitLabState(
          startDate: _defaultStart(),
          endDate: _defaultEnd(),
        )) {
    _syncFromSettings();
  }

  final Ref _ref;
  final GitLabActivityService _service;
  final YouTrackTrackedTimeService _trackedTimeService;
  final YouTrackGitLabAnalyzer _analyzer;

  static DateTime _defaultEnd() => DateUtils.dateOnly(DateTime.now());
  static DateTime _defaultStart() =>
      _defaultEnd().subtract(const Duration(days: 20));

  AppSettings? get _settings => _ref.read(settingsProvider).valueOrNull;

  void _setState(GitLabState value) {
    if (!mounted) return;
    state = value;
  }

  void _onProgress(LoadingProgress progress) {
    _setState(state.copyWith(
      isLoading: true,
      loadingProgress: progress,
      statusMessage: progress.stepLabel,
    ));
  }

  LoadingProgressTracker _tracker(String operation, int totalSteps) {
    return LoadingProgressTracker(
      operation: operation,
      totalSteps: totalSteps,
      onProgress: _onProgress,
    );
  }

  void _finishLoading({String? statusMessage}) {
    _setState(state.copyWith(
      isLoading: false,
      clearLoadingProgress: true,
      statusMessage: statusMessage ?? state.statusMessage,
    ));
  }

  void _syncFromSettings() {
    final s = _settings;
    if (s == null) return;
    if (s.gitLabDemoMode) {
      _setState(state.copyWith(status: GitLabConnectionStatus.demo));
    } else if (s.hasGitLab && s.gitLabToken.isNotEmpty) {
      _setState(state.copyWith(status: GitLabConnectionStatus.connected));
    }
  }

  void setPeriod(DateTime start, DateTime end) {
    _setState(state.copyWith(
      startDate: DateUtils.dateOnly(start),
      endDate: DateUtils.dateOnly(end),
    ));
  }

  Future<bool> validateAndConnect({
    required String baseUrl,
    required String token,
  }) async {
    _onProgress(LoadingProgress(
      operation: 'Подключение GitLab',
      step: 1,
      totalSteps: 1,
      stepLabel: 'Проверка GitLab token…',
      startedAt: DateTime.now(),
    ));
    _setState(state.copyWith(isValidating: true, clearError: true));

    final client = GitLabClient(baseUrl: baseUrl, token: token);
    try {
      final user = await _service.validateConnection(client);
      client.close();
      if (!mounted) return false;
      _setState(state.copyWith(
        isValidating: false,
        clearLoadingProgress: true,
        status: GitLabConnectionStatus.connected,
        user: user,
        statusMessage: 'Подключено: ${user.displayName}',
        clearError: true,
      ));
      AppLog.instance.info(
        LogCategory.app,
        'GitLab подключён: ${user.username}',
      );
      return true;
    } on GitLabApiException catch (e) {
      client.close();
      if (!mounted) return false;
      _setState(state.copyWith(
        isValidating: false,
        clearLoadingProgress: true,
        status: GitLabConnectionStatus.error,
        errorMessage: e.message,
        statusMessage: '',
        clearUser: true,
      ));
      return false;
    } catch (e) {
      client.close();
      if (!mounted) return false;
      _setState(state.copyWith(
        isValidating: false,
        clearLoadingProgress: true,
        status: GitLabConnectionStatus.error,
        errorMessage: '$e',
        statusMessage: '',
        clearUser: true,
      ));
      return false;
    }
  }

  Future<void> loadDemo() async {
    final start = state.startDate ?? _defaultStart();
    final end = state.endDate ?? _defaultEnd();
    final tracker = _tracker('GitLab (демо)', 3);
    tracker.start('Подготовка демо-данных');
    _setState(state.copyWith(
      isLoading: true,
      clearError: true,
      status: GitLabConnectionStatus.demo,
    ));
    AppLog.instance.info(LogCategory.app, 'GitLab: загрузка демо-данных…');

    try {
      final data = await _service.loadDemo(
        endDate: end,
        days: end.difference(start).inDays + 1,
        progress: tracker,
      );
      if (!mounted) return;
      _setState(state.copyWith(
        isLoading: false,
        clearLoadingProgress: true,
        activity: data,
        user: data.user,
        statusMessage: 'Демо-режим: ${data.commits.length} коммитов',
        status: GitLabConnectionStatus.demo,
      ));
      await _runComparison(data, tracker: _tracker('Сверка YouTrack', 2));
    } catch (e) {
      if (!mounted) return;
      _finishLoading();
      _setState(state.copyWith(errorMessage: '$e', statusMessage: ''));
      AppLog.instance.error(LogCategory.app, 'GitLab демо: $e');
    }
  }

  Future<void> refreshData() async {
    final settings = _settings?.normalized();
    if (settings == null) return;

    if (settings.gitLabDemoMode) {
      await loadDemo();
      return;
    }

    if (settings.gitLabToken.isEmpty) {
      _setState(state.copyWith(
        errorMessage: 'Укажите GitLab token в настройках',
        status: GitLabConnectionStatus.disconnected,
      ));
      return;
    }

    final start = state.startDate ?? _defaultStart();
    final end = state.endDate ?? _defaultEnd();

    final tracker = _tracker('GitLab', 6);
    tracker.start('Подготовка загрузки');
    _setState(state.copyWith(isLoading: true, clearError: true));
    AppLog.instance.info(
      LogCategory.app,
      'GitLab: загрузка за ${DateUtils.formatForQuery(start)}'
      ' — ${DateUtils.formatForQuery(end)}…',
    );

    final client = GitLabClient(
      baseUrl: settings.gitLabUrl,
      token: settings.gitLabToken,
    );

    try {
      final data = await _service.loadFromApi(
        client: client,
        startDate: start,
        endDate: end,
        progress: tracker,
      );
      client.close();
      if (!mounted) return;
      _setState(state.copyWith(
        isLoading: false,
        clearLoadingProgress: true,
        activity: data,
        user: data.user,
        status: GitLabConnectionStatus.connected,
        statusMessage:
            'Загружено: ${data.commits.length} коммитов, ${data.branches.length} веток',
      ));
      await _runComparison(data, tracker: _tracker('Сверка YouTrack', 2));
      AppLog.instance.info(
        LogCategory.app,
        'GitLab: ${data.commits.length} коммитов за период',
      );
    } on GitLabApiException catch (e) {
      client.close();
      if (!mounted) return;
      _finishLoading();
      _setState(state.copyWith(
        errorMessage: e.message,
        statusMessage: '',
        status: GitLabConnectionStatus.error,
      ));
      AppLog.instance.error(LogCategory.app, 'GitLab API: ${e.message}');
    } catch (e) {
      client.close();
      if (!mounted) return;
      _finishLoading();
      _setState(state.copyWith(errorMessage: '$e', statusMessage: ''));
      AppLog.instance.error(LogCategory.app, 'GitLab: $e');
    }
  }

  Future<void> recalculateAnalytics() async {
    if (state.activity == null) {
      await refreshData();
      return;
    }
    _setState(state.copyWith(statusMessage: 'Пересчёт аналитики…'));
    await _runComparison(state.activity!);
    if (!mounted) return;
    _setState(state.copyWith(
      statusMessage: state.timeComparison != null
          ? 'Сверка обновлена'
          : state.statusMessage,
    ));
  }

  Future<void> loadYouTrackComparison() async {
    final activity = state.activity;
    if (activity == null) {
      _setState(state.copyWith(
        errorMessage: 'Сначала загрузите GitLab-данные',
      ));
      return;
    }
    final tracker = _tracker('Сверка YouTrack', 2);
    tracker.start('Загрузка списаний YouTrack');
    _setState(state.copyWith(isLoading: true, clearError: true));
    await _runComparison(activity, tracker: tracker);
    if (!mounted) return;
    _finishLoading();
  }

  Future<void> _runComparison(
    GitLabActivityData gitLabData, {
    LoadingProgressTracker? tracker,
  }) async {
    final settings = _settings?.normalized();
    if (settings == null) return;

    final start = state.startDate ?? _defaultStart();
    final end = state.endDate ?? _defaultEnd();

    try {
      tracker?.start('Сверка с YouTrack');
      final YouTrackTrackedTimeData tracked;
      if (settings.gitLabDemoMode || !settings.hasYouTrack) {
        if (!settings.hasYouTrack && !settings.gitLabDemoMode) {
          _setState(state.copyWith(clearTrackedTime: true, clearComparison: true));
          return;
        }
        tracked = await _trackedTimeService.loadDemo(gitLabData: gitLabData);
      } else {
        tracker?.advance('Загрузка work items из YouTrack');
        final client = _trackedTimeService.createClient(
          baseUrl: settings.youTrackUrl,
          token: settings.youTrackToken,
          startDate: start,
          endDate: end,
        );
        try {
          tracked = await _trackedTimeService.loadFromApi(
            client: client,
            startDate: start,
            endDate: end,
          );
        } finally {
          client.close();
        }
      }

      if (!mounted) return;

      tracker?.advance('Сравнение с GitLab');
      final comparison = _analyzer.analyze(
        gitLab: gitLabData,
        youTrack: tracked,
        rangeStart: start,
        rangeEnd: end,
      );

      final ytLabel = tracked.isDemo ? ' (демо YT)' : '';
      _setState(state.copyWith(
        trackedTime: tracked,
        timeComparison: comparison,
        clearLoadingProgress: true,
        isLoading: false,
        statusMessage:
            '${state.statusMessage.isNotEmpty ? '${state.statusMessage} · ' : ''}'
            'YouTrack: ${tracked.totalMinutes}м$ytLabel · '
            'согласованность ${comparison.overallAlignmentScore.toStringAsFixed(0)}%',
      ));
      AppLog.instance.info(
        LogCategory.app,
        'Сверка YT/GitLab: ${comparison.overallAlignmentScore.toStringAsFixed(0)}%',
      );
    } catch (e) {
      if (!mounted) return;
      _setState(state.copyWith(
        errorMessage: 'Ошибка загрузки YouTrack: $e',
      ));
      AppLog.instance.error(LogCategory.app, 'Сверка YT/GitLab: $e');
    }
  }

  void clearAiSummary() {
    _setState(state.copyWith(
      clearAiSummary: true,
      clearAiSummaryError: true,
      clearAiSummaryErrorDay: true,
    ));
  }

  Future<void> generatePeriodAiSummary({
    bool withYouTrack = false,
    String? userHint,
  }) =>
      _generateAiSummary(day: null, withYouTrack: withYouTrack, userHint: userHint);

  Future<void> generateDayAiSummary(
    DateTime day, {
    bool withYouTrack = false,
    String? userHint,
  }) =>
      _generateAiSummary(
        day: DateUtils.dateOnly(day),
        withYouTrack: withYouTrack,
        userHint: userHint,
      );

  Future<void> _generateAiSummary({
    required DateTime? day,
    required bool withYouTrack,
    String? userHint,
  }) async {
    final settings = _settings?.normalized();
    if (settings == null) return;

    if (!settings.hasCursor || !settings.useAi) {
      _setState(state.copyWith(
        aiSummaryError: 'Укажите CURSOR_API_KEY и включите AI в настройках',
        aiSummaryErrorDay: day,
        clearAiSummaryErrorDay: day == null,
      ));
      return;
    }

    final activity = state.activity;
    if (activity == null) {
      _setState(state.copyWith(
        aiSummaryError: 'Сначала загрузите GitLab-данные',
        aiSummaryErrorDay: day,
      ));
      return;
    }

    if (withYouTrack && state.timeComparison == null) {
      _setState(state.copyWith(
        aiSummaryError: 'Сначала выполните сверку с YouTrack',
        aiSummaryErrorDay: day,
      ));
      return;
    }

    final start = state.startDate ?? _defaultStart();
    final end = state.endDate ?? _defaultEnd();

    _setState(state.copyWith(
      isAiSummaryLoading: true,
      aiSummaryLoadingDay: day,
      clearAiSummaryError: true,
      clearAiSummaryErrorDay: true,
      statusMessage: day == null
          ? 'AI-сводка за период…'
          : 'AI-сводка за ${DateUtils.formatForQuery(day)}…',
    ));

    final client = CursorAgentClient(apiKey: settings.cursorApiKey);
    try {
      final summarizer = GitLabAiSummarizer(client);
      final text = day == null
          ? await summarizer.summarizePeriod(
              activity: activity,
              start: start,
              end: end,
              comparison: withYouTrack ? state.timeComparison : null,
              userHint: userHint,
            )
          : await summarizer.summarizeDay(
              activity: activity,
              day: day,
              dayComparison: withYouTrack
                  ? _dayComparison(day, state.timeComparison)
                  : null,
              periodComparison:
                  withYouTrack ? state.timeComparison : null,
              userHint: userHint,
            );

      if (!mounted) return;
      _setState(state.copyWith(
        isAiSummaryLoading: false,
        clearAiSummaryLoadingDay: true,
        aiSummary: GitLabAiSummary(
          text: text,
          withYouTrack: withYouTrack,
          generatedAt: DateTime.now(),
          day: day,
        ),
        statusMessage: 'AI-сводка готова',
      ));
      AppLog.instance.success(LogCategory.cursor, 'GitLab AI-сводка получена');
    } on CursorAgentException catch (e) {
      if (!mounted) return;
      _setState(state.copyWith(
        isAiSummaryLoading: false,
        clearAiSummaryLoadingDay: true,
        aiSummaryError: e.message,
        aiSummaryErrorDay: day,
      ));
      AppLog.instance.error(LogCategory.cursor, 'GitLab AI: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _setState(state.copyWith(
        isAiSummaryLoading: false,
        clearAiSummaryLoadingDay: true,
        aiSummaryError: '$e',
        aiSummaryErrorDay: day,
      ));
      AppLog.instance.error(LogCategory.cursor, 'GitLab AI: $e');
    } finally {
      client.close();
    }
  }

  DailyTimeComparison? _dayComparison(
    DateTime day,
    YouTrackGitLabComparison? comparison,
  ) {
    if (comparison == null) return null;
    for (final d in comparison.dailyComparisons) {
      if (DateUtils.isSameDay(d.date, day)) return d;
    }
    return null;
  }
}
