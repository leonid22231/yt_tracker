/// Статус согласованности GitLab-активности и списанного времени.
enum TimeAlignmentStatus {
  aligned,
  gitlabOnly,
  youtrackOnly,
  mismatch,
}

/// Сравнение по одной задаче.
class TaskTimeComparison {
  const TaskTimeComparison({
    required this.taskId,
    required this.status,
    this.youtrackMinutes = 0,
    this.gitlabCommitCount = 0,
    this.gitlabEstimatedMinutes = 0,
    this.issueSummary = '',
    this.note = '',
  });

  final String taskId;
  final TimeAlignmentStatus status;
  final int youtrackMinutes;
  final int gitlabCommitCount;
  final int gitlabEstimatedMinutes;
  final String issueSummary;
  final String note;
}

/// Сравнение затреканного времени и GitLab-активности за день.
class DailyTimeComparison {
  const DailyTimeComparison({
    required this.date,
    required this.status,
    this.youtrackMinutes = 0,
    this.gitlabEstimatedMinutes = 0,
    this.gitlabCommitCount = 0,
    this.alignmentScore = 0,
    this.youtrackTaskIds = const [],
    this.gitlabTaskIds = const [],
    this.insight = '',
  });

  final DateTime date;
  final TimeAlignmentStatus status;
  final int youtrackMinutes;
  final int gitlabEstimatedMinutes;
  final int gitlabCommitCount;
  final double alignmentScore;
  final List<String> youtrackTaskIds;
  final List<String> gitlabTaskIds;
  final String insight;

  int get deltaMinutes => youtrackMinutes - gitlabEstimatedMinutes;

  bool get isActive =>
      youtrackMinutes > 0 || gitlabCommitCount > 0 || gitlabEstimatedMinutes > 0;
}

/// Полный результат сверки YouTrack и GitLab.
class YouTrackGitLabComparison {
  const YouTrackGitLabComparison({
    required this.dailyComparisons,
    required this.taskComparisons,
    required this.totalYoutrackMinutes,
    required this.totalGitlabEstimatedMinutes,
    required this.overallAlignmentScore,
    required this.alignedDays,
    required this.mismatchDays,
    required this.gitlabOnlyDays,
    required this.youtrackOnlyDays,
    this.insights = const [],
  });

  final List<DailyTimeComparison> dailyComparisons;
  final List<TaskTimeComparison> taskComparisons;
  final int totalYoutrackMinutes;
  final int totalGitlabEstimatedMinutes;
  final double overallAlignmentScore;
  final int alignedDays;
  final int mismatchDays;
  final int gitlabOnlyDays;
  final int youtrackOnlyDays;
  final List<String> insights;

  List<DailyTimeComparison> get activeDays =>
      dailyComparisons.where((d) => d.isActive).toList();

  List<TaskTimeComparison> get mismatchedTasks => taskComparisons
      .where((t) => t.status != TimeAlignmentStatus.aligned)
      .toList();
}
