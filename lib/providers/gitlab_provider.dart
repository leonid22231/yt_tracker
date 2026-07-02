import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/gitlab/gitlab_client.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/models/loading_progress.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/youtrack_gitlab_comparison.dart';
import 'package:youtrack_timer/models/gitlab/tracked_time_record.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_user_info.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_activity_service.dart';
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
}
