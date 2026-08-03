import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/ui/theme/app_theme.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/widgets/business/one_c_title_bar.dart';

/// Диалог с поддержкой 1С-оформления в desktop large.
class OneCAwareDialog extends ConsumerWidget {
  const OneCAwareDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(designVariantProvider).palette;

    if (!p.isOneC) {
      return AlertDialog(
        icon: icon != null ? Icon(icon) : null,
        title: Text(title),
        content: content,
        actions: actions,
      );
    }

    return Theme(
      data: AppTheme.oneC(),
      child: Dialog(
        backgroundColor: p.window,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.border),
          borderRadius: BorderRadius.zero,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OneCTitleBar(palette: p, title: title),
              Flexible(
                child: SingleChildScrollView(
                  child: DecoratedBox(
                    decoration: OneCDecorations.flatPanel(p),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: content,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.toolbar,
                  border: Border(top: BorderSide(color: p.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка диалога (1С или Material).
class VariantDialogButton extends ConsumerWidget {
  const VariantDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(designVariantProvider).palette;
    if (p.isOneC) {
      return OneCToolbarButton(
        palette: p,
        label: label,
        emphasis: primary,
        danger: danger,
        onPressed: onPressed,
      );
    }
    if (danger || primary) {
      return FilledButton(
        style: danger ? FilledButton.styleFrom(backgroundColor: p.danger) : null,
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}
