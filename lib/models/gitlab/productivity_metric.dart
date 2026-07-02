import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';

/// Производные метрики продуктивности за период.
class ProductivityMetric {
  const ProductivityMetric({
    required this.dailySummaries,
    this.averageCommitsPerDay = 0,
    this.averageTasksPerDay = 0,
    this.averageEstimatedMinutes = 0,
    this.peakDay,
    this.lowDay,
    this.totalCommits = 0,
    this.totalTasks = 0,
    this.totalEstimatedMinutes = 0,
    this.totalAdditions = 0,
    this.totalDeletions = 0,
    this.activeDaysCount = 0,
    this.averageProductivityScore = 0,
    this.longestActiveStreak = 0,
    this.topProject = '',
    this.averageChangesPerCommit = 0,
    this.mergeRequestCount = 0,
  });

  final List<DailyActivitySummary> dailySummaries;
  final double averageCommitsPerDay;
  final double averageTasksPerDay;
  final double averageEstimatedMinutes;
  final DateTime? peakDay;
  final DateTime? lowDay;
  final int totalCommits;
  final int totalTasks;
  final int totalEstimatedMinutes;
  final int totalAdditions;
  final int totalDeletions;
  final int activeDaysCount;
  final double averageProductivityScore;
  final int longestActiveStreak;
  final String topProject;
  final double averageChangesPerCommit;
  final int mergeRequestCount;

  int get totalChanges => totalAdditions + totalDeletions;

  double productivityFor(DateTime date) {
    final match = dailySummaries.where(
      (d) =>
          d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day,
    );
    return match.isEmpty ? 0 : match.first.productivityScore;
  }

  DailyActivitySummary? summaryFor(DateTime date) {
    for (final d in dailySummaries) {
      if (d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day) {
        return d;
      }
    }
    return null;
  }
}
