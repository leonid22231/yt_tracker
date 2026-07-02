import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/models/loading_progress.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/dialogs/confirm_write_dialog.dart';
import 'package:youtrack_timer/ui/layout/app_shell.dart';
import 'package:youtrack_timer/ui/screens/gitlab_analysis_screen.dart';
import 'package:youtrack_timer/ui/screens/plan_preview_screen.dart';
import 'package:youtrack_timer/ui/screens/settings_screen.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/widgets/day_timeline_view.dart';
import 'package:youtrack_timer/ui/widgets/home/home_sidebar.dart';
import 'package:youtrack_timer/ui/widgets/home/home_status_bar.dart';
import 'package:youtrack_timer/ui/widgets/home/home_top_bar.dart';
import 'package:youtrack_timer/ui/widgets/loading_progress_view.dart';
import 'package:youtrack_timer/ui/widgets/log_panel.dart';
import 'package:youtrack_timer/ui/widgets/plan/plan_details_panel.dart';
import 'package:youtrack_timer/ui/widgets/plan_list_view.dart';

/// Главный экран.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = ref.read(shellLayoutProvider).activeTabIndex;
      if (_tabs.index != index) _tabs.index = index;
    });
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    ref.read(shellLayoutProvider.notifier).setActiveTab(_tabs.index);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final settings = ref.watch(settingsProvider);
    final isLarge = ref.watch(designVariantProvider).isLarge;
    final shell = ref.watch(shellLayoutProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: settings.when(
        loading: () => const LoadingProgressScreen(
          operation: 'Загрузка',
          stepLabel: 'Чтение настроек…',
        ),
        error: (e, _) => Center(child: Text('Ошибка настроек: $e')),
        data: (s) => AppShell(
          sidebar: HomeSidebar(
            home: home,
            settings: s,
            onBuild: () => ref.read(homeProvider.notifier).buildPlan(),
            onPreview: () => _preview(context),
            onWrite: () => _write(context, s),
            onSettings: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            onGitLab: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GitLabAnalysisScreen(),
              ),
            ),
          ),
          topBar: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeTopBar(
                tabController: _tabs,
                onDetailsToggle: isLarge
                    ? () => ref
                        .read(shellLayoutProvider.notifier)
                        .toggleDetailsPanel()
                    : null,
              ),
              if (home.statusMessage.isNotEmpty || home.isLoading)
                _StatusStrip(home: home, isLarge: isLarge),
              if (home.plan?.aiSummary.isNotEmpty == true)
                _AiInsightBanner(
                  text: home.plan!.aiSummary,
                  isLarge: isLarge,
                ),
            ],
          ),
          content: home.plan == null
              ? (home.isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: LoadingProgressView(
                        progress: home.loadingProgress ??
                            LoadingProgress(
                              operation: 'Построение плана',
                              step: 1,
                              totalSteps: 7,
                              stepLabel: home.statusMessage.isNotEmpty
                                  ? home.statusMessage
                                  : 'Загрузка…',
                              startedAt: DateTime.now(),
                            ),
                        layout: LoadingProgressLayout.overlay,
                      ),
                    )
                  : _EmptyState(isLarge: isLarge))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    PlanListView(plan: home.plan!),
                    Padding(
                      padding: EdgeInsets.all(isLarge ? 12 : 16),
                      child: DayTimelineView(
                        timelines: home.plan!.dayTimelines,
                      ),
                    ),
                  ],
                ),
          detailsPanel: isLarge && home.plan != null
              ? PlanDetailsPanel(plan: home.plan!)
              : null,
          statusBar: isLarge ? HomeStatusBar(settings: s) : null,
          bottomPanel: _LogSection(
            expanded: shell.logExpanded,
            isLarge: isLarge,
            onToggle: () =>
                ref.read(shellLayoutProvider.notifier).toggleLogExpanded(),
          ),
        ),
      ),
    );
  }

  Future<void> _preview(BuildContext context) async {
    final home = ref.read(homeProvider);
    final settings = ref.read(settingsProvider).valueOrNull;

    if (home.plan == null) {
      _snack(context, 'Сначала постройте план');
      return;
    }
    if (settings == null || !settings.hasYouTrack) {
      _snack(context, 'Заполните настройки YouTrack');
      return;
    }
    if (home.activeEntries.isEmpty) {
      _snack(context, 'Все задачи исключены из плана');
      return;
    }
    if (home.startDate == null || home.endDate == null) return;

    final normalized = settings.normalized();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PlanPreviewScreen(
          plan: home.plan!,
          entries: home.activeEntries,
          startDate: home.startDate!,
          endDate: home.endDate!,
          baseUrl: normalized.youTrackUrl,
        ),
      ),
    );
  }

  Future<void> _write(BuildContext context, AppSettings settings) async {
    final home = ref.read(homeProvider);
    if (settings.dryRun) {
      _snack(context, 'Выключите Dry-run в настройках');
      return;
    }
    if (home.plan == null || home.startDate == null) {
      _snack(context, 'Сначала постройте план');
      return;
    }
    final ok = await ConfirmWriteDialog.show(
      context,
      plan: home.plan!,
      startDate: home.startDate!,
      endDate: home.endDate!,
    );
    if (ok && context.mounted) {
      await ref
          .read(homeProvider.notifier)
          .writeToYouTrack(userConfirmed: true);
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.home, required this.isLarge});

  final HomeState home;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 16 : 20,
        vertical: isLarge ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: isLarge ? AppColors.surfaceHigh : AppColors.primarySoft,
        border: isLarge
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: home.isLoading && home.loadingProgress != null
          ? LoadingProgressView(
              progress: home.loadingProgress,
              layout: LoadingProgressLayout.strip,
            )
          : Text(
              home.statusMessage,
              style: TextStyle(fontSize: isLarge ? 12 : 13),
            ),
    );
  }
}

class _AiInsightBanner extends StatelessWidget {
  const _AiInsightBanner({required this.text, required this.isLarge});

  final String text;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(isLarge ? 12 : 16, 8, isLarge ? 12 : 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLarge
            ? AppColors.surfaceHigh
            : null,
        gradient: isLarge
            ? null
            : LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.accent.withValues(alpha: 0.08),
                ],
              ),
        borderRadius: BorderRadius.circular(isLarge ? 4 : 14),
        border: Border.all(
          color: isLarge
              ? AppColors.border
              : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome,
            color: AppColors.accent,
            size: isLarge ? 16 : 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isLarge ? 12 : 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isLarge});

  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isLarge ? 20 : 24),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
                border: isLarge
                    ? Border.all(color: AppColors.border)
                    : null,
              ),
              child: Icon(
                Icons.insights_rounded,
                size: isLarge ? 40 : 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'План ещё не построен',
              style: TextStyle(
                fontSize: isLarge ? 18 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Укажите период слева и нажмите «Построить план». '
              'Cursor Agent оценит задачи, затем вы сможете подкрутить '
              'время слайдерами по каждому дню.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isLarge ? 13 : 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogSection extends StatelessWidget {
  const _LogSection({
    required this.expanded,
    required this.isLarge,
    required this.onToggle,
  });

  final bool expanded;
  final bool isLarge;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppColors.surfaceHigh,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLarge ? 12 : 16,
                vertical: isLarge ? 6 : 8,
              ),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.expand_less,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Журнал',
                    style: TextStyle(
                      fontSize: isLarge ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: isLarge ? 0.4 : 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) const LogPanel(),
      ],
    );
  }
}
