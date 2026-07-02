import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/models/loading_progress.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/gitlab_provider.dart';
import 'package:youtrack_timer/ui/screens/gitlab_day_detail_screen.dart';
import 'package:youtrack_timer/ui/screens/gitlab_settings_screen.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/widgets/gitlab/gitlab_activity_calendar.dart';
import 'package:youtrack_timer/ui/widgets/gitlab/gitlab_activity_charts.dart';
import 'package:youtrack_timer/ui/widgets/gitlab/gitlab_day_tile.dart';
import 'package:youtrack_timer/ui/widgets/gitlab/gitlab_metrics_dashboard.dart';
import 'package:youtrack_timer/ui/widgets/gitlab/youtrack_gitlab_comparison_view.dart';
import 'package:youtrack_timer/ui/widgets/loading_progress_view.dart';
import 'package:youtrack_timer/ui/widgets/period_selector.dart';

/// GitLab + YouTrack Analysis — аналитика по коммитам, веткам и задачам.
class GitLabAnalysisScreen extends ConsumerStatefulWidget {
  const GitLabAnalysisScreen({super.key});

  @override
  ConsumerState<GitLabAnalysisScreen> createState() =>
      _GitLabAnalysisScreenState();
}

class _GitLabAnalysisScreenState extends ConsumerState<GitLabAnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoLoad());
  }

  void _maybeAutoLoad() {
    if (!mounted) return;
    final gitLab = ref.read(gitLabProvider);
    final settings = ref.read(settingsProvider).valueOrNull;
    if (gitLab.activity != null) return;
    if (settings?.gitLabDemoMode == true) {
      ref.read(gitLabProvider.notifier).loadDemo();
    } else if (settings?.gitLabToken.isNotEmpty == true) {
      ref.read(gitLabProvider.notifier).refreshData();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gitLab = ref.watch(gitLabProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('GitLab + YouTrack Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Настройки GitLab',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GitLabSettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            gitLab: gitLab,
            settingsOk: settings?.hasGitLab == true,
            onRefresh: () => ref.read(gitLabProvider.notifier).refreshData(),
            onRecalculate: () =>
                ref.read(gitLabProvider.notifier).recalculateAnalytics(),
            onLoadYouTrack: () =>
                ref.read(gitLabProvider.notifier).loadYouTrackComparison(),
            onDemo: () => ref.read(gitLabProvider.notifier).loadDemo(),
            onPeriodChanged: (s, e) =>
                ref.read(gitLabProvider.notifier).setPeriod(s, e),
          ),
          if (gitLab.statusMessage.isNotEmpty || gitLab.isLoading)
            _StatusStrip(gitLab: gitLab),
          if (gitLab.errorMessage.isNotEmpty)
            _ErrorBanner(message: gitLab.errorMessage),
          Expanded(
            child: gitLab.isLoading && gitLab.activity == null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: LoadingProgressView(
                      progress: gitLab.loadingProgress ??
                          LoadingProgress(
                            operation: 'GitLab',
                            step: 1,
                            totalSteps: 6,
                            stepLabel: gitLab.statusMessage.isNotEmpty
                                ? gitLab.statusMessage
                                : 'Загрузка данных…',
                            startedAt: DateTime.now(),
                          ),
                      layout: LoadingProgressLayout.overlay,
                    ),
                  )
                : gitLab.activity == null
                    ? _EmptyState(
                        hasGitLab: settings?.hasGitLab == true,
                        onConnect: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const GitLabSettingsScreen(),
                          ),
                        ),
                        onDemo: () =>
                            ref.read(gitLabProvider.notifier).loadDemo(),
                      )
                    : gitLab.activity!.isEmpty
                        ? _NoDataState(
                            onRefresh: () =>
                                ref.read(gitLabProvider.notifier).refreshData(),
                          )
                        : _AnalysisContent(
                            gitLab: gitLab,
                            tabController: _tabs,
                            hasYouTrack: settings?.hasYouTrack == true,
                          ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.gitLab,
    required this.settingsOk,
    required this.onRefresh,
    required this.onRecalculate,
    required this.onLoadYouTrack,
    required this.onDemo,
    required this.onPeriodChanged,
  });

  final GitLabState gitLab;
  final bool settingsOk;
  final VoidCallback onRefresh;
  final VoidCallback onRecalculate;
  final VoidCallback onLoadYouTrack;
  final VoidCallback onDemo;
  final void Function(DateTime, DateTime) onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (gitLab.user != null) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    gitLab.user!.displayName.isNotEmpty
                        ? gitLab.user!.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gitLab.user!.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        gitLab.activity?.isDemo == true
                            ? 'Демо-режим'
                            : '@${gitLab.user!.username}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                const Expanded(
                  child: Text(
                    'GitLab не подключён',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PeriodSelector(
            start: gitLab.startDate,
            end: gitLab.endDate,
            enabled: !gitLab.isLoading,
            onChanged: onPeriodChanged,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: gitLab.isLoading ? null : onRefresh,
                icon: const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('Обновить данные'),
              ),
              OutlinedButton.icon(
                onPressed: gitLab.isLoading ? null : onRecalculate,
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('Пересчитать'),
              ),
              if (gitLab.activity != null)
                OutlinedButton.icon(
                  onPressed: gitLab.isLoading ? null : onLoadYouTrack,
                  icon: const Icon(Icons.cloud_outlined, size: 18),
                  label: const Text('Сверка с YouTrack'),
                ),
              if (!settingsOk)
                OutlinedButton.icon(
                  onPressed: gitLab.isLoading ? null : onDemo,
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('Демо'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.gitLab});

  final GitLabState gitLab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.primarySoft,
      child: gitLab.isLoading && gitLab.loadingProgress != null
          ? LoadingProgressView(
              progress: gitLab.loadingProgress,
              layout: LoadingProgressLayout.strip,
            )
          : Text(
              gitLab.statusMessage,
              style: const TextStyle(fontSize: 13),
            ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _AnalysisContent extends StatefulWidget {
  const _AnalysisContent({
    required this.gitLab,
    required this.tabController,
    required this.hasYouTrack,
  });

  final GitLabState gitLab;
  final TabController tabController;
  final bool hasYouTrack;

  @override
  State<_AnalysisContent> createState() => _AnalysisContentState();
}

class _AnalysisContentState extends State<_AnalysisContent> {
  DateTime? _selectedDay;

  void _openDay(DateTime day) {
    setState(() => _selectedDay = day);
    final activity = widget.gitLab.activity;
    if (activity == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GitLabDayDetailScreen(
          activity: activity,
          date: day,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.gitLab.activity!;
    final metrics = activity.metrics;
    final activeDays = metrics.dailySummaries
        .where((d) => d.commitCount > 0 || d.branchesTouched > 0)
        .toList()
        .reversed
        .toList();

    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: widget.tabController,
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  GitLabMetricsDashboard(
                    metrics: metrics,
                    onPeakDayTap: _openDay,
                  ),
                  const SizedBox(height: 16),
                  GitLabActivityCalendar(
                    metrics: metrics,
                    selectedDay: _selectedDay,
                    onDayTap: _openDay,
                  ),
                  if (activeDays.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Активные дни',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Нажмите на карточку для деталей',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: activeDays.length,
                        itemBuilder: (_, i) {
                          final day = activeDays[i];
                          return GitLabDayTile(
                            summary: day,
                            selected: _selectedDay != null &&
                                day.date.year == _selectedDay!.year &&
                                day.date.month == _selectedDay!.month &&
                                day.date.day == _selectedDay!.day,
                            onTap: () => _openDay(day.date),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  GitLabActivityCharts(
                    metrics: metrics,
                    selectedDay: _selectedDay,
                    onDayTap: _openDay,
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (widget.gitLab.timeComparison != null)
                    YouTrackGitLabComparisonView(
                      comparison: widget.gitLab.timeComparison!,
                      trackedIsDemo: widget.gitLab.trackedTime?.isDemo == true,
                    )
                  else
                    _YouTrackComparisonEmpty(hasYouTrack: widget.hasYouTrack),
                ],
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TabBar(
            controller: widget.tabController,
            indicatorPadding: const EdgeInsets.all(4),
            dividerHeight: 0,
            tabs: const [
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dashboard_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Обзор'),
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insights_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Графики'),
                  ],
                ),
              ),
              Tab(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.compare_arrows, size: 16),
                    SizedBox(width: 6),
                    Text('YouTrack'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasGitLab,
    required this.onConnect,
    required this.onDemo,
  });

  final bool hasGitLab;
  final VoidCallback onConnect;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hub_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Подключите GitLab',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Вставьте Personal Access Token или включите демо-режим, '
                'чтобы увидеть аналитику по коммитам, веткам и задачам.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onConnect,
                icon: const Icon(Icons.link),
                label: const Text('Подключить GitLab'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onDemo,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Демо без token'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YouTrackComparisonEmpty extends StatelessWidget {
  const _YouTrackComparisonEmpty({required this.hasYouTrack});

  final bool hasYouTrack;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.compare_arrows, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Сверка ещё не выполнена',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              hasYouTrack
                  ? 'Нажмите «Сверка с YouTrack» или «Обновить данные» '
                    'для сравнения списаний с GitLab-активностью.'
                  : 'Подключите YouTrack в настройках или используйте демо-режим GitLab.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDataState extends StatelessWidget {
  const _NoDataState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Нет данных за период',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Попробуйте расширить период или обновить данные',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'),
          ),
        ],
      ),
    );
  }
}
