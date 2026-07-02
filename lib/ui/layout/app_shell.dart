import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/theme/design_variant.dart';

/// Оболочка приложения: выбирает current/large layout и сохраняет состояние панелей.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.sidebar,
    required this.topBar,
    required this.content,
    this.detailsPanel,
    this.statusBar,
    this.bottomPanel,
  });

  final Widget sidebar;
  final Widget topBar;
  final Widget content;
  final Widget? detailsPanel;
  final Widget? statusBar;
  final Widget? bottomPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final width = constraints.maxWidth;
          if (ref.read(windowWidthProvider) != width) {
            ref.read(windowWidthProvider.notifier).state = width;
          }
        });

        final ctx = DesignVariantContext.fromWidth(
          preference: ref.watch(designModePreferenceProvider),
          width: constraints.maxWidth,
        );

        return ctx.isLarge
            ? _LargeShell(
                ctx: ctx,
                sidebar: sidebar,
                topBar: topBar,
                content: content,
                detailsPanel: detailsPanel,
                statusBar: statusBar,
                bottomPanel: bottomPanel,
              )
            : _CurrentShell(
                sidebar: sidebar,
                topBar: topBar,
                content: content,
                bottomPanel: bottomPanel,
              );
      },
    );
  }
}

class _CurrentShell extends StatelessWidget {
  const _CurrentShell({
    required this.sidebar,
    required this.topBar,
    required this.content,
    this.bottomPanel,
  });

  final Widget sidebar;
  final Widget topBar;
  final Widget content;
  final Widget? bottomPanel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: VariantTokens.current.sidebarWidth, child: sidebar),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              topBar,
              Expanded(child: content),
              if (bottomPanel != null) bottomPanel!,
            ],
          ),
        ),
      ],
    );
  }
}

class _LargeShell extends ConsumerWidget {
  const _LargeShell({
    required this.ctx,
    required this.sidebar,
    required this.topBar,
    required this.content,
    this.detailsPanel,
    this.statusBar,
    this.bottomPanel,
  });

  final DesignVariantContext ctx;
  final Widget sidebar;
  final Widget topBar;
  final Widget content;
  final Widget? detailsPanel;
  final Widget? statusBar;
  final Widget? bottomPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(shellLayoutProvider);
    final tokens = ctx.tokens;

    final navWidth = layout.leftNavExpanded
        ? layout.leftNavWidth.clamp(
            tokens.sidebarCompactWidth,
            tokens.sidebarWidth + 80,
          )
        : tokens.sidebarCompactWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: DesignTokens.durationNormal,
                curve: DesignTokens.curveStandard,
                width: navWidth,
                child: sidebar,
              ),
              _ResizeHandle(
                axis: Axis.horizontal,
                onDrag: (delta) {
                  ref.read(shellLayoutProvider.notifier).setLeftNavWidth(
                        (layout.leftNavWidth + delta).clamp(
                          tokens.sidebarCompactWidth,
                          tokens.sidebarWidth + 80,
                        ),
                      );
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    topBar,
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: DesignTokens.contentMaxWidth,
                          ),
                          child: content,
                        ),
                      ),
                    ),
                    if (bottomPanel != null) bottomPanel!,
                  ],
                ),
              ),
              if (detailsPanel != null && layout.detailsPanelOpen) ...[
                _ResizeHandle(
                  axis: Axis.horizontal,
                  onDrag: (delta) {
                    ref.read(shellLayoutProvider.notifier).setDetailsPanelWidth(
                          (layout.detailsPanelWidth - delta).clamp(
                            tokens.detailsPanelMinWidth,
                            520,
                          ),
                        );
                  },
                ),
                AnimatedContainer(
                  duration: DesignTokens.durationNormal,
                  curve: DesignTokens.curveStandard,
                  width: layout.detailsPanelWidth,
                  child: detailsPanel,
                ),
              ],
            ],
          ),
        ),
        if (statusBar != null)
          SizedBox(height: tokens.statusBarHeight, child: statusBar),
      ],
    );
  }
}

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.axis,
    required this.onDrag,
  });

  final Axis axis;
  final ValueChanged<double> onDrag;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.axis == Axis.horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: widget.axis == Axis.horizontal
            ? (d) => widget.onDrag(d.delta.dx)
            : null,
        onVerticalDragUpdate: widget.axis == Axis.vertical
            ? (d) => widget.onDrag(d.delta.dy)
            : null,
        child: AnimatedContainer(
          duration: DesignTokens.durationFast,
          width: widget.axis == Axis.horizontal ? 4 : null,
          height: widget.axis == Axis.vertical ? 4 : null,
          color: _hovered ? DesignTokens.accentMuted : DesignTokens.borderSubtle,
        ),
      ),
    );
  }
}
