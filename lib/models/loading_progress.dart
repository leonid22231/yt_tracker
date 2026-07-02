/// Прогресс длительной операции: шаг, доля, ETA.
class LoadingProgress {
  const LoadingProgress({
    required this.operation,
    required this.step,
    required this.totalSteps,
    required this.stepLabel,
    this.detail,
    this.stepFraction = 0,
    required this.startedAt,
  });

  /// Название операции («Построение плана», «GitLab»…).
  final String operation;

  /// Текущий шаг (1…totalSteps).
  final int step;

  final int totalSteps;
  final String stepLabel;
  final String? detail;

  /// Доля выполнения внутри текущего шага (0…1).
  final double stepFraction;
  final DateTime startedAt;

  /// Общая доля 0…1 (до завершения — максимум 0.99).
  double get fraction {
    if (totalSteps <= 0) return 0;
    final base = (step - 1) / totalSteps;
    final part = stepFraction.clamp(0.0, 1.0) / totalSteps;
    return (base + part).clamp(0.0, 0.99);
  }

  int get percent => (fraction * 100).round().clamp(0, 99);

  Duration get elapsed => DateTime.now().difference(startedAt);

  /// Оставшееся время; null если ещё рано оценивать.
  Duration? estimatedRemaining({DateTime? now}) {
    final f = fraction;
    if (f < 0.05) return null;
    final elapsedMs = (now ?? DateTime.now()).difference(startedAt).inMilliseconds;
    if (elapsedMs <= 0) return null;
    final totalMs = elapsedMs / f;
    final rem = (totalMs - elapsedMs).round();
    if (rem <= 0) return Duration.zero;
    return Duration(milliseconds: rem);
  }

  String formatElapsed({DateTime? now}) {
    return _formatDuration((now ?? DateTime.now()).difference(startedAt));
  }

  String formatEta({DateTime? now}) {
    final rem = estimatedRemaining(now: now);
    if (rem == null) return 'оценка времени…';
    if (rem == Duration.zero) return 'почти готово';
    return '~${_formatDuration(rem)}';
  }

  static String _formatDuration(Duration d) {
    final s = d.inSeconds;
    if (s < 5) return 'несколько сек';
    if (s < 60) return '$s сек';
    final m = s ~/ 60;
    final rs = s % 60;
    if (m < 60) {
      return rs > 0 ? '$m мин $rs сек' : '$m мин';
    }
    final h = m ~/ 60;
    final rm = m % 60;
    return rm > 0 ? '$h ч $rm мин' : '$h ч';
  }

  LoadingProgress copyWith({
    String? operation,
    int? step,
    int? totalSteps,
    String? stepLabel,
    String? detail,
    double? stepFraction,
    DateTime? startedAt,
    bool clearDetail = false,
  }) =>
      LoadingProgress(
        operation: operation ?? this.operation,
        step: step ?? this.step,
        totalSteps: totalSteps ?? this.totalSteps,
        stepLabel: stepLabel ?? this.stepLabel,
        detail: clearDetail ? null : (detail ?? this.detail),
        stepFraction: stepFraction ?? this.stepFraction,
        startedAt: startedAt ?? this.startedAt,
      );
}

typedef LoadingProgressCallback = void Function(LoadingProgress progress);

/// Удобный трекер шагов для сервисов.
class LoadingProgressTracker {
  LoadingProgressTracker({
    required this.operation,
    required this.totalSteps,
    required this.onProgress,
  });

  final String operation;
  final int totalSteps;
  final LoadingProgressCallback onProgress;
  final DateTime _startedAt = DateTime.now();
  var _step = 0;
  var _label = '';

  void start(String firstStep, {String? detail}) {
    _step = 1;
    _label = firstStep;
    _emit(detail: detail);
  }

  void advance(String label, {String? detail}) {
    _step = (_step + 1).clamp(1, totalSteps);
    _label = label;
    _emit(detail: detail);
  }

  void fraction(double value, {String? detail}) {
    _emit(stepFraction: value, detail: detail);
  }

  void _emit({double stepFraction = 0, String? detail}) {
    onProgress(
      LoadingProgress(
        operation: operation,
        step: _step.clamp(1, totalSteps),
        totalSteps: totalSteps,
        stepLabel: _label,
        detail: detail,
        stepFraction: stepFraction,
        startedAt: _startedAt,
      ),
    );
  }
}
