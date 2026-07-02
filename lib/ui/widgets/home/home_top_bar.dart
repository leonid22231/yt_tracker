import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';

/// Верхняя панель главного экрана с табами и переключателем режима.
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({
    super.key,
    required this.tabController,
    this.onDetailsToggle,
  });

  final TabController tabController;
  final VoidCallback? onDetailsToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final isLarge = ref.watch(designVariantProvider).isLarge;
    final layout = ref.watch(shellLayoutProvider);
    final tokens = ref.watch(designVariantProvider).tokens;

    if (isLarge) {
      return _LargeTopBar(
        home: home,
        tabController: tabController,
        detailsOpen: layout.detailsPanelOpen,
        onDetailsToggle: onDetailsToggle,
        tokens: tokens,
      );
    }
    return _CurrentTopBar(home: home, tabController: tabController);
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
              Expanded(child: _TitleRow(home: home, isLarge: false)),
              const DesignModeToggle(),
            ],
          ),
          const SizedBox(height: 12),
          _TabStrip(tabController: tabController, isLarge: false),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LargeTopBar extends StatelessWidget {
  const _LargeTopBar({
    required this.home,
    required this.tabController,
    required this.detailsOpen,
    required this.tokens,
    this.onDetailsToggle,
  });

  final HomeState home;
  final TabController tabController;
  final bool detailsOpen;
  final VoidCallback? onDetailsToggle;
  final VariantTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tokens.topBarHeight + 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _TitleRow(home: home, isLarge: true)),
                _TabStrip(tabController: tabController, isLarge: true),
                const SizedBox(width: 8),
                if (onDetailsToggle != null)
                  IconButton(
                    tooltip: detailsOpen
                        ? 'Скрыть панель деталей'
                        : 'Показать панель деталей',
                    icon: Icon(
                      detailsOpen
                          ? Icons.view_sidebar
                          : Icons.view_sidebar_outlined,
                      size: 18,
                    ),
                    onPressed: onDetailsToggle,
                    visualDensity: VisualDensity.compact,
                  ),
                const DesignModeToggle(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.home, required this.isLarge});

  final HomeState home;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          home.plan == null ? 'План времени' : 'Редактирование плана',
          style: TextStyle(
            fontSize: isLarge ? 18 : 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (home.plan != null) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isLarge
                  ? AppColors.primarySoft
                  : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(4),
              border: isLarge
                  ? Border.all(color: AppColors.border)
                  : null,
            ),
            child: Text(
              '${home.plan!.entries.length} записей',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isLarge ? AppColors.primary : AppColors.accent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.tabController, required this.isLarge});

  final TabController tabController;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    if (isLarge) {
      return SizedBox(
        width: 240,
        height: 32,
        child: TabBar(
          controller: tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          indicator: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          labelPadding: EdgeInsets.zero,
          tabs: const [
            Tab(height: 28, text: 'Задачи'),
            Tab(height: 28, text: 'По дням'),
          ],
        ),
      );
    }

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
