import 'package:flutter/material.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/safe_set_state.dart';

/// Синяя заголовочная полоса окна в стиле 1С / Windows Classic.
class OneCTitleBar extends StatelessWidget {
  const OneCTitleBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.palette,
  });

  final String title;
  final String? subtitle;
  final VariantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.titleBar, palette.titleBarEnd],
        ),
        border: Border(
          bottom: BorderSide(color: palette.borderShadow),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 14, color: palette.textOnTitle),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.textOnTitle,
            ),
          ),
          if (subtitle != null) ...[
            Text(
              ' — ',
              style: TextStyle(fontSize: 12, color: palette.textOnTitle),
            ),
            Expanded(
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textOnTitle.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Разделитель панели инструментов 1С.
class OneCToolbarDivider extends StatelessWidget {
  const OneCToolbarDivider({super.key, required this.palette});

  final VariantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: palette.borderShadow, width: 1),
          right: BorderSide(color: palette.borderHighlight, width: 1),
        ),
      ),
    );
  }
}

/// Кнопка панели инструментов с выпуклой рамкой (1С).
class OneCToolbarButton extends StatefulWidget {
  const OneCToolbarButton({
    super.key,
    required this.label,
    required this.palette,
    this.icon,
    this.onPressed,
    this.onLongPress,
    this.emphasis = false,
    this.danger = false,
    this.tooltip,
  });

  final String label;
  final VariantPalette palette;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool emphasis;
  final bool danger;
  final String? tooltip;

  @override
  State<OneCToolbarButton> createState() => _OneCToolbarButtonState();
}

class _OneCToolbarButtonState extends State<OneCToolbarButton> {
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final enabled = widget.onPressed != null;

    final fg = !enabled
        ? p.textMuted
        : widget.danger
            ? p.danger
            : p.textPrimary;

    final bg = !enabled
        ? p.buttonFace
        : _pressed
            ? p.buttonHover
            : _hovered
                ? p.buttonHover
                : p.buttonFace;

    Widget child = GestureDetector(
      onTapDown: enabled ? (_) => deferSetState(this, () => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              deferSetState(this, () => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => deferSetState(this, () => _pressed = false) : null,
      onLongPress: enabled ? widget.onLongPress : null,
      child: MouseRegion(
        onEnter: (_) => deferSetState(this, () => _hovered = true),
        onExit: (_) => deferSetState(this, () {
          _hovered = false;
          _pressed = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: _pressed
              ? OneCDecorations.sunken(p)
              : OneCDecorations.raised(p, color: bg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.emphasis ? FontWeight.w700 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }
}
