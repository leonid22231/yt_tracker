import 'package:flutter/material.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';

enum FlatButtonVariant { primary, secondary, ghost, danger }

/// Плоская кнопка для large-режима (без Material elevation).
class FlatButton extends StatefulWidget {
  const FlatButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = FlatButtonVariant.secondary,
    this.dense = false,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final FlatButtonVariant variant;
  final bool dense;
  final String? tooltip;

  @override
  State<FlatButton> createState() => _FlatButtonState();
}

class _FlatButtonState extends State<FlatButton> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final colors = _colors(enabled);

    final child = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        child: AnimatedContainer(
          duration: DesignTokens.durationFast,
          curve: DesignTokens.curveStandard,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
            border: Border.all(
              color: _focused ? DesignTokens.focusRing : colors.border,
              width: _focused ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              hoverColor: colors.hover,
              focusColor: colors.hover,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.dense ? 10 : 14,
                  vertical: widget.dense ? 6 : 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 16, color: colors.foreground),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: child);
    }
    return child;
  }

  ({Color background, Color border, Color foreground, Color hover}) _colors(
    bool enabled,
  ) {
    if (!enabled) {
      return (
        background: DesignTokens.surfaceHigh,
        border: DesignTokens.borderSubtle,
        foreground: DesignTokens.textMuted,
        hover: Colors.transparent,
      );
    }
    return switch (widget.variant) {
      FlatButtonVariant.primary => (
          background: _hovered ? DesignTokens.accentHover : DesignTokens.accent,
          border: DesignTokens.accent,
          foreground: Colors.white,
          hover: DesignTokens.accentHover,
        ),
      FlatButtonVariant.danger => (
          background: _hovered
              ? AppColorsDanger.backgroundHover
              : AppColorsDanger.background,
          border: AppColorsDanger.border,
          foreground: Colors.white,
          hover: AppColorsDanger.backgroundHover,
        ),
      FlatButtonVariant.ghost => (
          background: _hovered ? DesignTokens.accentMuted : Colors.transparent,
          border: Colors.transparent,
          foreground: DesignTokens.textPrimary,
          hover: DesignTokens.accentMuted,
        ),
      FlatButtonVariant.secondary => (
          background: _hovered ? DesignTokens.surfaceHigh : DesignTokens.surface,
          border: DesignTokens.border,
          foreground: DesignTokens.textPrimary,
          hover: DesignTokens.surfaceHigh,
        ),
    };
  }
}

abstract final class AppColorsDanger {
  static const background = Color(0xFFDC4C4C);
  static const backgroundHover = Color(0xFFE85D5D);
  static const border = Color(0xFFDC4C4C);
}
