import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/app_theme.dart';
import 'package:youtrack_timer/ui/widgets/business/business_toolbar.dart';
import 'package:youtrack_timer/ui/widgets/business/one_c_title_bar.dart';

/// Оболочка экрана: 1С (desktop large) или стандартный Scaffold.
class VariantScaffold extends ConsumerWidget {
  const VariantScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions,
    this.toolbarActions,
    this.bottom,
    this.tabStrip,
    this.useWorkArea = true,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final List<Widget>? toolbarActions;
  final Widget? bottom;
  final Widget? tabStrip;
  final bool useWorkArea;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLarge = ref.watch(designVariantProvider).isLarge;
    final p = ref.watch(designVariantProvider).palette;

    if (isLarge) {
      return Theme(
        data: AppTheme.oneC(),
        child: Scaffold(
          backgroundColor: p.window,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OneCTitleBar(
                palette: p,
                title: title,
                subtitle: subtitle,
              ),
              BusinessToolbar(
                palette: p,
                actions: [
                  OneCToolbarButton(
                    palette: p,
                    label: 'Назад',
                    icon: Icons.arrow_back,
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                  ),
                  if (toolbarActions != null) ...[
                    OneCToolbarDivider(palette: p),
                    ...toolbarActions!,
                  ],
                ],
                trailing: actions,
              ),
              if (tabStrip != null) tabStrip!,
              Expanded(
                child: ColoredBox(
                  color: useWorkArea ? p.workArea : p.window,
                  child: body,
                ),
              ),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: subtitle != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16)),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              )
            : Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack ?? () => Navigator.maybePop(context),
        ),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: bottom,
    );
  }
}

/// Секция формы: BusinessFormSection (1С) или Card (планшет).
class VariantSectionCard extends ConsumerWidget {
  const VariantSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.dense = true,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(designVariantProvider).palette;

    if (p.isOneC) {
      return BusinessFormSection(
        palette: p,
        title: title,
        dense: dense,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Кнопки действий формы: 1С toolbar-кнопки или Material.
class VariantFormActions extends ConsumerWidget {
  const VariantFormActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryDanger = false,
    this.primaryEnabled = true,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryDanger;
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(designVariantProvider).palette;

    if (p.isOneC) {
      return Row(
        children: [
          OneCToolbarButton(
            palette: p,
            label: primaryLabel,
            icon: primaryDanger ? Icons.save_outlined : Icons.check,
            danger: primaryDanger,
            onPressed: primaryEnabled ? onPrimary : null,
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(width: 6),
            OneCToolbarButton(
              palette: p,
              label: secondaryLabel!,
              onPressed: onSecondary,
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        if (secondaryLabel != null && onSecondary != null) ...[
          OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          const SizedBox(width: 10),
        ],
        FilledButton(
          style: primaryDanger
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: primaryEnabled ? onPrimary : null,
          child: Text(primaryLabel),
        ),
      ],
    );
  }
}

/// Подсказка muted-текста с учётом палитры.
class VariantHintText extends ConsumerWidget {
  const VariantHintText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(designVariantProvider).palette;
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: p.textMuted),
    );
  }
}
