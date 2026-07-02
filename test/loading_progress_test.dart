import 'package:test/test.dart';
import 'package:youtrack_timer/models/loading_progress.dart';

void main() {
  test('fraction учитывает шаг и долю внутри шага', () {
    final p = LoadingProgress(
      operation: 'test',
      step: 2,
      totalSteps: 4,
      stepLabel: 'шаг',
      stepFraction: 0.5,
      startedAt: DateTime(2026, 1, 1),
    );
    expect(p.fraction, closeTo(0.375, 0.001));
    expect(p.percent, 38);
  });

  test('ETA появляется после 5% прогресса', () {
    final started = DateTime(2026, 1, 1, 12, 0, 0);
    final p = LoadingProgress(
      operation: 'test',
      step: 2,
      totalSteps: 2,
      stepLabel: 'шаг',
      stepFraction: 0.5,
      startedAt: started,
    );
    final now = started.add(const Duration(seconds: 10));
    expect(p.estimatedRemaining(now: now), isNotNull);
    expect(p.formatEta(now: now), isNot(contains('оценка')));
  });
}
