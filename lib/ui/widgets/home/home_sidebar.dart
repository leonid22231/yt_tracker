import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/widgets/business/business_toolbar.dart';
import 'package:youtrack_timer/ui/widgets/excluded_dates_control.dart';
import 'package:youtrack_timer/ui/widgets/hours_per_day_control.dart';
import 'package:youtrack_timer/ui/widgets/meetup_settings_control.dart';
import 'package:youtrack_timer/ui/widgets/period_selector.dart';
import 'package:youtrack_timer/ui/widgets/recalc_hint_field.dart';
import 'package:youtrack_timer/ui/widgets/status_pill.dart';

/// Боковая панель главного экрана (current + large).
class HomeSidebar extends ConsumerWidget {
  const HomeSidebar({
    super.key,
    required this.home,
    required this.settings,
    required this.onBuild,
    this.onBuildFromJson,
    required this.onPreview,
    required this.onWrite,
    required this.onSettings,
    required this.onGitLab,
  });

  final HomeState home;
  final AppSettings settings;
  final VoidCallback onBuild;
  final VoidCallback? onBuildFromJson;
  final VoidCallback onPreview;
  final VoidCallback onWrite;
  final VoidCallback onSettings;
  final VoidCallback onGitLab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLarge = ref.watch(designVariantProvider).isLarge;
    final palette = ref.watch(designVariantProvider).palette;
    final layout = ref.watch(shellLayoutProvider);
    final compact = isLarge && !layout.leftNavExpanded;

    return Container(
      decoration: BoxDecoration(
        color: isLarge ? palette.panel : AppColors.surface,
        border: Border(
          right: BorderSide(
            color: isLarge ? palette.border : AppColors.border,
          ),
        ),
      ),
      child: SafeArea(
        child: compact
            ? _CompactRail(
                home: home,
                settings: settings,
                onBuild: onBuild,
                onBuildFromJson: onBuildFromJson,
                onPreview: onPreview,
                onWrite: onWrite,
                onSettings: onSettings,
                onGitLab: onGitLab,
                onExpand: () =>
                    ref.read(shellLayoutProvider.notifier).toggleLeftNavExpanded(),
              )
            : _ExpandedSidebar(
                home: home,
                settings: settings,
                isLarge: isLarge,
                palette: palette,
                onBuild: onBuild,
                onBuildFromJson: onBuildFromJson,
                onPreview: onPreview,
                onWrite: onWrite,
                onSettings: onSettings,
                onGitLab: onGitLab,
                onCollapse: isLarge
                    ? () => ref
                        .read(shellLayoutProvider.notifier)
                        .toggleLeftNavExpanded()
                    : null,
              ),
      ),
    );
  }
}

class _CompactRail extends StatelessWidget {
  const _CompactRail({
    required this.home,
    required this.settings,
    required this.onBuild,
    this.onBuildFromJson,
    required this.onPreview,
    required this.onWrite,
    required this.onSettings,
    required this.onGitLab,
    required this.onExpand,
  });

  final HomeState home;
  final AppSettings settings;
  final VoidCallback onBuild;
  final VoidCallback? onBuildFromJson;
  final VoidCallback onPreview;
  final VoidCallback onWrite;
  final VoidCallback onSettings;
  final VoidCallback onGitLab;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final canWrite = !settings.dryRun;

    return Column(
      children: [
        const SizedBox(height: 8),
        _RailIcon(
          icon: Icons.timer_outlined,
          tooltip: 'YouTrack Timer',
          onTap: onExpand,
        ),
        const Divider(height: 16, indent: 12, endIndent: 12),
        _RailIcon(
          icon: Icons.auto_graph_rounded,
          tooltip: home.plan == null ? 'Построить план' : 'Обновить план',
          onTap: home.isLoading ? null : onBuild,
          onLongPress: home.isLoading ? null : onBuildFromJson,
          accent: true,
        ),
        _RailIcon(
          icon: Icons.analytics_outlined,
          tooltip: 'GitLab аналитика',
          onTap: home.isLoading ? null : onGitLab,
        ),
        _RailIcon(
          icon: Icons.fact_check_outlined,
          tooltip: 'Проверить',
          onTap: home.isLoading ? null : onPreview,
        ),
        _RailIcon(
          icon: canWrite ? Icons.cloud_upload : Icons.lock_outline,
          tooltip: canWrite ? 'Записать в YouTrack' : 'Запись выкл.',
          onTap: home.isLoading ? null : onWrite,
          danger: canWrite,
        ),
        const Spacer(),
        _RailIcon(
          icon: Icons.settings_outlined,
          tooltip: 'Настройки',
          onTap: onSettings,
        ),
        _RailIcon(
          icon: Icons.last_page,
          tooltip: 'Развернуть панель',
          onTap: onExpand,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RailIcon extends StatefulWidget {
  const _RailIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.onLongPress,
    this.accent = false,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool accent;
  final bool danger;

  @override
  State<_RailIcon> createState() => _RailIconState();
}

class _RailIconState extends State<_RailIcon> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.onTap == null
        ? AppColors.textMuted
        : widget.danger
            ? AppColors.danger
            : widget.accent
                ? AppColors.primary
                : AppColors.textSecondary;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
          button: true,
          label: widget.tooltip,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: AnimatedContainer(
              duration: DesignTokens.durationFast,
              width: 56,
              height: 40,
              alignment: Alignment.center,
              color: _hovered ? AppColors.primarySoft : Colors.transparent,
              child: Icon(widget.icon, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedSidebar extends ConsumerWidget {
  const _ExpandedSidebar({
    required this.home,
    required this.settings,
    required this.isLarge,
    required this.palette,
    required this.onBuild,
    this.onBuildFromJson,
    required this.onPreview,
    required this.onWrite,
    required this.onSettings,
    required this.onGitLab,
    this.onCollapse,
  });

  final HomeState home;
  final AppSettings settings;
  final bool isLarge;
  final VariantPalette palette;
  final VoidCallback onBuild;
  final VoidCallback? onBuildFromJson;
  final VoidCallback onPreview;
  final VoidCallback onWrite;
  final VoidCallback onSettings;
  final VoidCallback onGitLab;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canWrite = !settings.dryRun;
    final padding = isLarge ? DesignTokens.space4 : DesignTokens.space5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(padding, padding, padding, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: isLarge
                  ? _largeSections(ref, home, settings, palette)
                  : _currentSections(ref, home, settings),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, padding),
          child: isLarge
              ? const SizedBox.shrink()
              : _CurrentActions(
                  home: home,
                  canWrite: canWrite,
                  onBuild: onBuild,
                  onBuildFromJson: onBuildFromJson,
                  onGitLab: onGitLab,
                  onPreview: onPreview,
                  onWrite: onWrite,
                ),
        ),
      ],
    );
  }

  List<Widget> _currentSections(
    WidgetRef ref,
    HomeState home,
    AppSettings settings,
  ) {
    return [
      _Header(
        isLarge: false,
        onSettings: onSettings,
        onCollapse: onCollapse,
      ),
      const SizedBox(height: 24),
      const _SectionLabel('Период', isLarge: false),
      const SizedBox(height: 8),
      PeriodSelector(
        start: home.startDate,
        end: home.endDate,
        enabled: !home.isLoading,
        onChanged: (s, e) => ref.read(homeProvider.notifier).setPeriod(s, e),
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
      const SizedBox(height: 8),
      StatusPill(
        icon: Icons.hub_outlined,
        label: 'GitLab',
        ok: settings.hasGitLab,
      ),
      if (settings.dryRun) ...[
        const SizedBox(height: 8),
        const StatusPill(
          icon: Icons.shield_outlined,
          label: 'Защита: без записи',
          ok: true,
        ),
      ],
    ];
  }

  List<Widget> _largeSections(
    WidgetRef ref,
    HomeState home,
    AppSettings settings,
    VariantPalette palette,
  ) {
    return [
      _Header(
        isLarge: true,
        palette: palette,
        onSettings: onSettings,
        onCollapse: onCollapse,
      ),
      const SizedBox(height: 10),
      BusinessFormSection(
        palette: palette,
        title: 'Период',
        dense: true,
        child: PeriodSelector(
          start: home.startDate,
          end: home.endDate,
          enabled: !home.isLoading,
          onChanged: (s, e) => ref.read(homeProvider.notifier).setPeriod(s, e),
        ),
      ),
      const SizedBox(height: 8),
      BusinessFormSection(
        palette: palette,
        title: 'Параметры плана',
        dense: true,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludedDatesControl(),
            SizedBox(height: 10),
            HoursPerDayControl(),
            SizedBox(height: 10),
            MeetupSettingsControl(),
            SizedBox(height: 10),
            RecalcHintField(),
          ],
        ),
      ),
      const SizedBox(height: 8),
      BusinessFormSection(
        palette: palette,
        title: 'Подключения',
        dense: true,
        child: Column(
          children: [
            StatusPill(
              icon: Icons.cloud_outlined,
              label: 'YouTrack',
              ok: settings.hasYouTrack,
            ),
            const SizedBox(height: 6),
            StatusPill(
              icon: Icons.auto_awesome,
              label: 'Cursor AI',
              ok: settings.hasCursor && settings.useAi,
            ),
            const SizedBox(height: 6),
            StatusPill(
              icon: Icons.hub_outlined,
              label: 'GitLab',
              ok: settings.hasGitLab,
            ),
            if (settings.dryRun) ...[
              const SizedBox(height: 6),
              const StatusPill(
                icon: Icons.shield_outlined,
                label: 'Защита: без записи',
                ok: true,
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isLarge,
    required this.onSettings,
    this.palette,
    this.onCollapse,
  });

  final bool isLarge;
  final VariantPalette? palette;
  final VoidCallback onSettings;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isLarge ? 4 : 10),
          decoration: BoxDecoration(
            color: isLarge ? palette?.buttonFace : null,
            gradient: isLarge
                ? null
                : const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF5B4FD6)],
                  ),
            border: isLarge
                ? Border(
                    top: BorderSide(color: palette!.borderHighlight),
                    left: BorderSide(color: palette!.borderHighlight),
                    bottom: BorderSide(color: palette!.borderShadow),
                    right: BorderSide(color: palette!.borderShadow),
                  )
                : null,
            borderRadius: BorderRadius.circular(isLarge ? 0 : 12),
          ),
          child: Icon(
            Icons.timer_outlined,
            color: isLarge ? palette!.textPrimary : Colors.white,
            size: isLarge ? 16 : 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YouTrack Timer',
                style: TextStyle(
                  fontSize: isLarge ? 12 : 16,
                  fontWeight: FontWeight.w700,
                  color: isLarge ? palette?.textPrimary : null,
                ),
              ),
              Text(
                isLarge ? 'Параметры' : 'План времени с AI',
                style: TextStyle(
                  fontSize: 11,
                  color: isLarge ? palette?.textMuted : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (onCollapse != null)
          IconButton(
            tooltip: 'Свернуть панель',
            icon: const Icon(Icons.first_page, size: 18),
            onPressed: onCollapse,
            visualDensity: VisualDensity.compact,
          ),
        IconButton(
          tooltip: 'Настройки',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, size: 20),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.isLarge});

  final String text;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: isLarge ? 10 : 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _CurrentActions extends StatelessWidget {
  const _CurrentActions({
    required this.home,
    required this.canWrite,
    required this.onBuild,
    this.onBuildFromJson,
    required this.onGitLab,
    required this.onPreview,
    required this.onWrite,
  });

  final HomeState home;
  final bool canWrite;
  final VoidCallback onBuild;
  final VoidCallback? onBuildFromJson;
  final VoidCallback onGitLab;
  final VoidCallback onPreview;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: home.isLoading ? null : onBuild,
          onLongPress: home.isLoading ? null : onBuildFromJson,
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
          label: Text(
            home.isLoading && home.loadingProgress != null
                ? '${home.loadingProgress!.percent}% · '
                    '${home.plan == null ? 'Построение' : 'Обновление'}'
                : home.plan == null
                    ? 'Построить план'
                    : 'Обновить план',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: home.isLoading ? null : onGitLab,
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('GitLab аналитика'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: home.isLoading ? null : onPreview,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Проверить'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: canWrite ? AppColors.danger : AppColors.surfaceHigh,
            foregroundColor: canWrite ? Colors.white : AppColors.textMuted,
          ),
          onPressed: home.isLoading ? null : onWrite,
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
    );
  }
}
