import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/utils/safe_set_state.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';

/// Ручка изменения размера панели (как в 1С / Windows Classic).
class PanelResizeHandle extends StatefulWidget {
  const PanelResizeHandle({
    super.key,
    required this.palette,
    required this.axis,
    required this.onDrag,
    this.thickness = 4,
  });

  final VariantPalette palette;
  final Axis axis;
  final ValueChanged<double> onDrag;
  final double thickness;

  @override
  State<PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<PanelResizeHandle> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;

    return MouseRegion(
      onEnter: (_) => deferSetState(this, () => _hovered = true),
      onExit: (_) => deferSetState(this, () => _hovered = false),
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: isHorizontal
            ? (d) => widget.onDrag(d.delta.dx)
            : null,
        onVerticalDragUpdate: !isHorizontal
            ? (d) => widget.onDrag(d.delta.dy)
            : null,
        child: AnimatedContainer(
          duration: DesignTokens.durationFast,
          width: isHorizontal ? widget.thickness : double.infinity,
          height: isHorizontal ? double.infinity : widget.thickness,
          color: _hovered
              ? widget.palette.resizeHandleHover
              : widget.palette.resizeHandle,
        ),
      ),
    );
  }
}
