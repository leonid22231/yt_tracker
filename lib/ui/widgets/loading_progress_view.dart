import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtrack_timer/models/loading_progress.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';

enum LoadingProgressLayout { strip, panel, overlay }

/// Прогресс-бар с шагами, прошедшим и оставшимся временем.
class LoadingProgressView extends StatefulWidget {
  const LoadingProgressView({
    super.key,
    required this.progress,
    this.layout = LoadingProgressLayout.panel,
  });

  final LoadingProgress? progress;
  final LoadingProgressLayout layout;

  @override
  State<LoadingProgressView> createState() => _LoadingProgressViewState();
}

class _LoadingProgressViewState extends State<LoadingProgressView> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(LoadingProgressView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final active = widget.progress != null;
    if (active && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!active) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    if (p == null) return const SizedBox.shrink();

    return switch (widget.layout) {
      LoadingProgressLayout.strip => _Strip(progress: p),
      LoadingProgressLayout.panel => _Panel(progress: p),
      LoadingProgressLayout.overlay => _Overlay(progress: p),
    };
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.progress});

  final LoadingProgress progress;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                progress.stepLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pal.textPrimary,
                ),
              ),
            ),
            Text(
              '${progress.percent}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pal.link,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ProgressBar(fraction: progress.fraction),
        const SizedBox(height: 6),
        _MetaRow(progress: progress, compact: true),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.progress});

  final LoadingProgress progress;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          progress.operation,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: pal.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          progress.stepLabel,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        if (progress.detail != null && progress.detail!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            progress.detail!,
            style: TextStyle(fontSize: 12, color: pal.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ProgressBar(fraction: progress.fraction)),
            const SizedBox(width: 12),
            Text(
              '${progress.percent}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: pal.link,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MetaRow(progress: progress, compact: false),
      ],
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.progress});

  final LoadingProgress progress;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final panel = Padding(
      padding: EdgeInsets.all(pal.isOneC ? 12 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: pal.link,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  progress.operation,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: pal.isOneC ? 12 : 20),
          _Panel(progress: progress),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: pal.isOneC
            ? Container(
                margin: const EdgeInsets.all(24),
                decoration: OneCDecorations.raised(pal),
                child: panel,
              )
            : Card(
                margin: const EdgeInsets.all(24),
                child: panel,
              ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(pal.isOneC ? 0 : 4),
      child: LinearProgressIndicator(
        value: fraction > 0 ? fraction : null,
        minHeight: 6,
        backgroundColor: pal.border,
        color: pal.link,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.progress, required this.compact});

  final LoadingProgress progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final stepText =
        'Шаг ${progress.step} из ${progress.totalSteps} · ${progress.formatElapsed()}';
    final etaText = 'Осталось ${progress.formatEta()}';

    if (compact) {
      return Text(
        '$stepText · $etaText',
        style: TextStyle(fontSize: 11, color: pal.textMuted),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            stepText,
            style: TextStyle(fontSize: 11, color: pal.textMuted),
          ),
        ),
        Text(
          etaText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: pal.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Полноэкранная загрузка настроек и т.п.
class LoadingProgressScreen extends StatelessWidget {
  const LoadingProgressScreen({
    super.key,
    this.operation = 'Загрузка',
    this.stepLabel = 'Подготовка…',
  });

  final String operation;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final progress = LoadingProgress(
      operation: operation,
      step: 1,
      totalSteps: 2,
      stepLabel: stepLabel,
      startedAt: DateTime.now(),
    );
    return LoadingProgressView(
      progress: progress,
      layout: LoadingProgressLayout.overlay,
    );
  }
}
