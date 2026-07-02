/// Оценка условного времени и продуктивности по GitLab-активности.
class GitLabTimeEstimator {
  const GitLabTimeEstimator({
    this.minutesPerCommit = 25,
    this.minutesPerTask = 15,
    this.minutesPer100Changes = 10,
    this.minutesPerBranch = 5,
    this.maxMinutesPerDay = 600,
  });

  final int minutesPerCommit;
  final int minutesPerTask;
  final int minutesPer100Changes;
  final int minutesPerBranch;
  final int maxMinutesPerDay;

  int estimateMinutes({
    required int commitCount,
    required int taskCount,
    required int totalChanges,
    required int branchesTouched,
  }) {
    if (commitCount == 0 && branchesTouched == 0) return 0;

    final fromCommits = commitCount * minutesPerCommit;
    final fromTasks = taskCount * minutesPerTask;
    final fromChanges = (totalChanges / 100).ceil() * minutesPer100Changes;
    final fromBranches = branchesTouched * minutesPerBranch;

    final raw = fromCommits + fromTasks + fromChanges + fromBranches;
    return raw.clamp(0, maxMinutesPerDay);
  }

  /// Нормализованный показатель 0..100.
  double productivityScore({
    required int commitCount,
    required int taskCount,
    required int estimatedMinutes,
    required int totalChanges,
  }) {
    if (commitCount == 0 && taskCount == 0 && totalChanges == 0) return 0;

    final commitScore = (commitCount * 12).clamp(0, 40).toDouble();
    final taskScore = (taskCount * 8).clamp(0, 25).toDouble();
    final changeScore = (totalChanges / 50).clamp(0, 20).toDouble();
    final timeScore = (estimatedMinutes / 10).clamp(0, 15).toDouble();

    return (commitScore + taskScore + changeScore + timeScore).clamp(0, 100);
  }
}
