import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_variant.dart';
import 'package:youtrack_timer/ui/widgets/business/business_toolbar.dart';
import 'package:youtrack_timer/ui/widgets/business/one_c_title_bar.dart';

/// Верхняя панель главного экрана.
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({
    super.key,
    required this.tabController,
    this.onDetailsToggle,
    this.settings,
    this.onBuild,
    this.onBuildFromJson,
    this.onPreview,
    this.onWrite,
    this.onGitLab,
    this.onSettings,
  });

  final TabController tabController;
  final VoidCallback? onDetailsToggle;
  final AppSettings? settings;
  final VoidCallback? onBuild;
  final VoidCallback? onBuildFromJson;
  final VoidCallback? onPreview;
  final VoidCallback? onWrite;
  final VoidCallback? onGitLab;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final ctx = ref.watch(designVariantProvider);
    final layout = ref.watch(shellLayoutProvider);

    if (ctx.isLarge) {
      final p = ctx.palette;
      final canWrite = settings != null && !settings!.dryRun;
      final docTitle = home.plan == null
          ? 'Планирование рабочего времени'
          : 'План · ${home.plan!.entries.length} записей';

      return BusinessTopChrome(
        palette: p,
        title: 'YouTrack Timer',
        subtitle: docTitle,
        toolbar: BusinessToolbar(
          palette: p,
          actions: [
            OneCToolbarButton(
              palette: p,
              label: home.isLoading && home.loadingProgress != null
                  ? '${home.loadingProgress!.percent}%'
                  : home.plan == null
                      ? 'Сформировать'
                      : 'Обновить',
              icon: Icons.play_arrow_outlined,
              emphasis: true,
              onPressed: home.isLoading ? null : onBuild,
              onLongPress: home.isLoading ? null : onBuildFromJson,
            ),
            OneCToolbarButton(
              palette: p,
              label: 'Проверить',
              icon: Icons.fact_check_outlined,
              onPressed: home.isLoading ? null : onPreview,
            ),
            OneCToolbarButton(
              palette: p,
              label: canWrite ? 'Записать' : 'Запись выкл.',
              icon: canWrite ? Icons.save_outlined : Icons.lock_outline,
              danger: canWrite,
              onPressed: home.isLoading ? null : onWrite,
            ),
            OneCToolbarDivider(palette: p),
            OneCToolbarButton(
              palette: p,
              label: 'GitLab',
              icon: Icons.analytics_outlined,
              onPressed: home.isLoading ? null : onGitLab,
            ),
          ],
          trailing: [
            if (onDetailsToggle != null)
              OneCToolbarButton(
                palette: p,
                label: layout.detailsPanelOpen ? 'Скрыть' : 'Реквизиты',
                icon: Icons.view_sidebar_outlined,
                onPressed: onDetailsToggle,
              ),
            OneCToolbarButton(
              palette: p,
              label: 'Настройки',
              icon: Icons.settings_outlined,
              onPressed: onSettings,
            ),
            const SizedBox(width: 4),
            _OneCModeButton(),
          ],
        ),
        tabStrip: BusinessTabStrip(
          palette: p,
          tabController: tabController,
          tabs: const [
            (icon: Icons.table_rows_outlined, label: 'Список задач'),
            (icon: Icons.grid_on_outlined, label: 'Табель по дням'),
          ],
        ),
      );
    }
    return _CurrentTopBar(home: home, tabController: tabController);
  }
}

class _OneCModeButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OneCToolbarButton(
      palette: ref.watch(designVariantProvider).palette,
      label: 'Вид',
      icon: Icons.desktop_windows_outlined,
      onPressed: () async {
        final box = context.findRenderObject() as RenderBox?;
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final position = box?.localToGlobal(Offset.zero, ancestor: overlay) ??
            Offset.zero;
        await showMenu<DesignModePreference>(
          context: context,
          position: RelativeRect.fromLTRB(
            position.dx,
            position.dy + 24,
            position.dx + 120,
            position.dy,
          ),
          items: [
            for (final m in DesignModePreference.values)
              PopupMenuItem(
                value: m,
                child: Text(m.label, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ).then((v) {
          if (v != null) {
            ref.read(designModePreferenceProvider.notifier).setPreference(v);
          }
        });
      },
    );
  }
}

class _CurrentTopBar extends StatelessWidget {
  const _CurrentTopBar({required this.home, required this.tabController});

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
              Expanded(child: _TitleRow(home: home)),
              const DesignModeToggle(),
            ],
          ),
          const SizedBox(height: 12),
          _CurrentTabStrip(tabController: tabController),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.home});

  final HomeState home;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          home.plan == null ? 'План времени' : 'Редактирование плана',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (home.plan != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(4),
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
    );
  }
}

class _CurrentTabStrip extends StatelessWidget {
  const _CurrentTabStrip({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
