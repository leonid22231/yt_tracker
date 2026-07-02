import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/dialogs/confirm_write_dialog.dart';
import 'package:youtrack_timer/ui/screens/plan_preview_screen.dart';
import 'package:youtrack_timer/ui/screens/settings_screen.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/widgets/day_timeline_view.dart';
import 'package:youtrack_timer/ui/widgets/hours_per_day_control.dart';
import 'package:youtrack_timer/ui/widgets/log_panel.dart';
import 'package:youtrack_timer/ui/widgets/period_selector.dart';
import 'package:youtrack_timer/ui/widgets/plan_list_view.dart';
import 'package:youtrack_timer/ui/widgets/excluded_dates_control.dart';
import 'package:youtrack_timer/ui/widgets/meetup_settings_control.dart';
import 'package:youtrack_timer/ui/widgets/recalc_hint_field.dart';
import 'package:youtrack_timer/ui/widgets/status_pill.dart';

/// Главный экран.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _logExpanded = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка настроек: $e')),
        data: (s) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(
              home: home,
              settings: s,
              ref: ref,
              onBuild: () => ref.read(homeProvider.notifier).buildPlan(),
              onPreview: () => _preview(context),
              onWrite: () => _write(context, s),
              onSettings: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MainHeader(
                    home: home,
                    tabController: _tabs,
                  ),
                  if (home.statusMessage.isNotEmpty || home.isLoading)
                    _StatusStrip(home: home),
                  if (home.plan?.aiSummary.isNotEmpty == true)
                    _AiInsightBanner(text: home.plan!.aiSummary),
                  Expanded(
                    child: home.plan == null
                        ? const _EmptyState()
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              PlanListView(plan: home.plan!),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: DayTimelineView(
                                  timelines: home.plan!.dayTimelines,
                                ),
                              ),
                            ],
                          ),
                  ),
                  _LogSection(
                    expanded: _logExpanded,
                    onToggle: () =>
                        setState(() => _logExpanded = !_logExpanded),
                  ),
                ],
              ),
            ),
          ],
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.home,
    required this.settings,
    required this.ref,
    required this.onBuild,
    required this.onPreview,
    required this.onWrite,
    required this.onSettings,
  });

  final HomeState home;
  final AppSettings settings;
  final WidgetRef ref;
  final VoidCallback onBuild;
  final VoidCallback onPreview;
  final VoidCallback onWrite;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final canWrite = !settings.dryRun;

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF5B4FD6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.timer_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YouTrack Timer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'План времени с AI',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Настройки',
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Период',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              PeriodSelector(
                start: home.startDate,
                end: home.endDate,
                enabled: !home.isLoading,
                onChanged: (s, e) =>
                    ref.read(homeProvider.notifier).setPeriod(s, e),
              ),
              const SizedBox(height: 12),
              const ExcludedDatesControl(),
              const SizedBox(height: 16),
              const HoursPerDayControl(),
              const SizedBox(height: 16),
              const MeetupSettingsControl(),
              const SizedBox(height: 16),
              const RecalcHintField(),
              const SizedBox(height: 16),
              StatusPill(
                icon: Icons.cloud_outlined,
                label: 'YouTrack',
                ok: settings.hasYouTrack,
              ),
              const SizedBox(height: 8),
              StatusPill(
                icon: Icons.auto_awesome,
                label: 'Cursor AI',
                ok: settings.hasCursor && settings.useAi,
              ),
              if (settings.dryRun) ...[
                const SizedBox(height: 8),
                const StatusPill(
                  icon: Icons.shield_outlined,
                  label: 'Защита: без записи',
                  ok: true,
                ),
              ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              FilledButton.icon(
                onPressed: home.isLoading ? null : onBuild,
                icon: home.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_graph_rounded),
                label: Text(home.plan == null ? 'Построить план' : 'Обновить план'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: home.isLoading ? null : onPreview,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Проверить'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      canWrite ? AppColors.danger : AppColors.surfaceHigh,
                  foregroundColor: canWrite ? Colors.white : AppColors.textMuted,
                ),
                onPressed: home.isLoading
                    ? null
                    : canWrite
                        ? onWrite
                        : onWrite,
                icon: Icon(canWrite ? Icons.cloud_upload : Icons.lock_outline),
                label: Text(canWrite ? 'Записать в YouTrack' : 'Запись выкл.'),
              ),
              if (home.plan == null && !home.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Выберите период и постройте план',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                  ),
                ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainHeader extends StatelessWidget {
  const _MainHeader({
    required this.home,
    required this.tabController,
  });

  final HomeState home;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                home.plan == null ? 'План времени' : 'Редактирование плана',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (home.plan != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${home.plan!.entries.length} записей',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: tabController,
              indicatorPadding: const EdgeInsets.all(4),
              dividerHeight: 0,
              tabs: const [
                Tab(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.view_list_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Задачи'),
                    ],
                  ),
                ),
                Tab(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_view_week_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('По дням'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.home});

  final HomeState home;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppColors.primarySoft,
      child: Row(
        children: [
          if (home.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: Text(
              home.statusMessage,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightBanner extends StatelessWidget {
  const _AiInsightBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
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
                Icons.insights_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'План ещё не построен',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Укажите период слева и нажмите «Построить план». '
              'Cursor Agent оценит задачи, затем вы сможете подкрутить '
              'время слайдерами по каждому дню.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
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
    required this.onToggle,
  });

  final bool expanded;
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Журнал',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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