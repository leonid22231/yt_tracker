import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/tracked_time_record.dart';
import 'package:youtrack_timer/models/gitlab/youtrack_gitlab_comparison.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_time_estimator.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Сверка затреканного времени YouTrack с GitLab-активностью.
class YouTrackGitLabAnalyzer {
  const YouTrackGitLabAnalyzer({
    GitLabTimeEstimator? timeEstimator,
  }) : _timeEstimator = timeEstimator ?? const GitLabTimeEstimator();

  final GitLabTimeEstimator _timeEstimator;

  YouTrackGitLabComparison analyze({
    required GitLabActivityData gitLab,
    required YouTrackTrackedTimeData youTrack,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final start = DateUtils.dateOnly(rangeStart);
    final end = DateUtils.dateOnly(rangeEnd);

    final gitLabByDay = {
      for (final d in gitLab.metrics.dailySummaries)
        DateUtils.dateOnly(d.date): d,
    };
    final ytByDay = {
      for (final d in youTrack.dailySummaries) DateUtils.dateOnly(d.date): d,
    };

    final dailyComparisons = <DailyTimeComparison>[];
    var alignedDays = 0;
    var mismatchDays = 0;
    var gitlabOnlyDays = 0;
    var youtrackOnlyDays = 0;

    var current = start;
    while (!current.isAfter(end)) {
      final gitDay = gitLabByDay[current];
      final ytDay = ytByDay[current];
      final comparison = _compareDay(
        date: current,
        gitLab: gitDay,
        youTrack: ytDay,
      );
      if (comparison.isActive) {
        dailyComparisons.add(comparison);
        switch (comparison.status) {
          case TimeAlignmentStatus.aligned:
            alignedDays++;
          case TimeAlignmentStatus.mismatch:
            mismatchDays++;
          case TimeAlignmentStatus.gitlabOnly:
            gitlabOnlyDays++;
          case TimeAlignmentStatus.youtrackOnly:
            youtrackOnlyDays++;
        }
      }
      current = current.add(const Duration(days: 1));
    }

    final taskComparisons = _compareTasks(
      commits: gitLab.commits,
      entries: youTrack.entries,
      gitLabByDay: gitLabByDay,
    );

    final totalYt = youTrack.totalMinutes;
    final totalGl = gitLab.metrics.totalEstimatedMinutes;
    final overallScore = _overallAlignment(
      totalYoutrack: totalYt,
      totalGitlab: totalGl,
      alignedDays: alignedDays,
      activeDays: dailyComparisons.length,
    );

    return YouTrackGitLabComparison(
      dailyComparisons: dailyComparisons,
      taskComparisons: taskComparisons,
      totalYoutrackMinutes: totalYt,
      totalGitlabEstimatedMinutes: totalGl,
      overallAlignmentScore: overallScore,
      alignedDays: alignedDays,
      mismatchDays: mismatchDays,
      gitlabOnlyDays: gitlabOnlyDays,
      youtrackOnlyDays: youtrackOnlyDays,
      insights: _buildInsights(
        totalYoutrack: totalYt,
        totalGitlab: totalGl,
        alignedDays: alignedDays,
        mismatchDays: mismatchDays,
        gitlabOnlyDays: gitlabOnlyDays,
        youtrackOnlyDays: youtrackOnlyDays,
        taskComparisons: taskComparisons,
      ),
    );
  }

  DailyTimeComparison _compareDay({
    required DateTime date,
    DailyActivitySummary? gitLab,
    DailyTrackedSummary? youTrack,
  }) {
    final ytMinutes = youTrack?.totalMinutes ?? 0;
    final glEstimated = gitLab?.estimatedMinutes ?? 0;
    final glCommits = gitLab?.commitCount ?? 0;
    final ytTasks = youTrack?.taskIds ?? const [];
    final glTasks = gitLab?.taskIds ?? const [];

    final status = _dayStatus(
      youtrackMinutes: ytMinutes,
      gitlabEstimated: glEstimated,
      gitlabCommits: glCommits,
    );
    final score = _dayAlignmentScore(
      youtrackMinutes: ytMinutes,
      gitlabEstimated: glEstimated,
    );

    return DailyTimeComparison(
      date: date,
      status: status,
      youtrackMinutes: ytMinutes,
      gitlabEstimatedMinutes: glEstimated,
      gitlabCommitCount: glCommits,
      alignmentScore: score,
      youtrackTaskIds: ytTasks,
      gitlabTaskIds: glTasks,
      insight: _dayInsight(
        status: status,
        youtrackMinutes: ytMinutes,
        gitlabEstimated: glEstimated,
        gitlabCommits: glCommits,
        ytTasks: ytTasks,
        glTasks: glTasks,
      ),
    );
  }

  TimeAlignmentStatus _dayStatus({
    required int youtrackMinutes,
    required int gitlabEstimated,
    required int gitlabCommits,
  }) {
    final hasYt = youtrackMinutes > 0;
    final hasGl = gitlabCommits > 0 || gitlabEstimated > 0;

    if (hasYt && hasGl) {
      final ratio = youtrackMinutes / gitlabEstimated.clamp(1, 99999);
      if (ratio >= 0.4 && ratio <= 2.5) return TimeAlignmentStatus.aligned;
      return TimeAlignmentStatus.mismatch;
    }
    if (hasGl) return TimeAlignmentStatus.gitlabOnly;
    if (hasYt) return TimeAlignmentStatus.youtrackOnly;
    return TimeAlignmentStatus.aligned;
  }

  double _dayAlignmentScore({
    required int youtrackMinutes,
    required int gitlabEstimated,
  }) {
    if (youtrackMinutes == 0 && gitlabEstimated == 0) return 100;
    if (youtrackMinutes == 0 || gitlabEstimated == 0) return 20;

    final ratio = youtrackMinutes / gitlabEstimated;
    final deviation = (ratio - 1).abs();
    return (100 - deviation * 50).clamp(0, 100);
  }

  String _dayInsight({
    required TimeAlignmentStatus status,
    required int youtrackMinutes,
    required int gitlabEstimated,
    required int gitlabCommits,
    required List<String> ytTasks,
    required List<String> glTasks,
  }) {
    switch (status) {
      case TimeAlignmentStatus.aligned:
        return 'Списанное время и GitLab-активность согласованы';
      case TimeAlignmentStatus.gitlabOnly:
        return 'Был кодинг ($gitlabCommits комм.), но мало/нет списаний в YouTrack';
      case TimeAlignmentStatus.youtrackOnly:
        return 'Время списано, но нет коммитов — возможно митинги, ревью или работа без push';
      case TimeAlignmentStatus.mismatch:
        final delta = youtrackMinutes - gitlabEstimated;
        if (delta > 0) {
          return 'В YouTrack списано больше, чем оценка по GitLab (+$deltaм)';
        }
        return 'GitLab показывает больше активности, чем списано в YouTrack';
    }
  }

  List<TaskTimeComparison> _compareTasks({
    required List<CommitRecord> commits,
    required List<TrackedWorkEntry> entries,
    required Map<DateTime, DailyActivitySummary> gitLabByDay,
  }) {
    final ytByTask = <String, int>{};
    final summaries = <String, String>{};
    for (final e in entries) {
      ytByTask[e.taskId] = (ytByTask[e.taskId] ?? 0) + e.minutes;
      summaries[e.taskId] = e.issueSummary;
    }

    final commitsByTask = <String, List<CommitRecord>>{};
    for (final c in commits) {
      for (final id in c.taskIds) {
        commitsByTask.putIfAbsent(id, () => []).add(c);
      }
    }

    final allTasks = {...ytByTask.keys, ...commitsByTask.keys}.toList()..sort();

    return [
      for (final taskId in allTasks)
        _compareTask(
          taskId: taskId,
          youtrackMinutes: ytByTask[taskId] ?? 0,
          commits: commitsByTask[taskId] ?? const [],
          issueSummary: summaries[taskId] ?? '',
          gitLabByDay: gitLabByDay,
        ),
    ];
  }

  TaskTimeComparison _compareTask({
    required String taskId,
    required int youtrackMinutes,
    required List<CommitRecord> commits,
    required String issueSummary,
    required Map<DateTime, DailyActivitySummary> gitLabByDay,
  }) {
    final commitCount = commits.length;
    var additions = 0;
    var deletions = 0;
    for (final c in commits) {
      additions += c.additions;
      deletions += c.deletions;
    }

    final estimated = _timeEstimator.estimateMinutes(
      commitCount: commitCount,
      taskCount: 1,
      totalChanges: additions + deletions,
      branchesTouched: 0,
    );

    final status = _taskStatus(
      youtrackMinutes: youtrackMinutes,
      commitCount: commitCount,
      estimated: estimated,
    );

    return TaskTimeComparison(
      taskId: taskId,
      status: status,
      youtrackMinutes: youtrackMinutes,
      gitlabCommitCount: commitCount,
      gitlabEstimatedMinutes: estimated,
      issueSummary: issueSummary,
      note: _taskNote(status, youtrackMinutes, commitCount),
    );
  }

  TimeAlignmentStatus _taskStatus({
    required int youtrackMinutes,
    required int commitCount,
    required int estimated,
  }) {
    final hasYt = youtrackMinutes > 0;
    final hasGl = commitCount > 0;

    if (hasYt && hasGl) {
      final ratio = youtrackMinutes / estimated.clamp(1, 99999);
      if (ratio >= 0.35 && ratio <= 3.0) return TimeAlignmentStatus.aligned;
      return TimeAlignmentStatus.mismatch;
    }
    if (hasGl) return TimeAlignmentStatus.gitlabOnly;
    if (hasYt) return TimeAlignmentStatus.youtrackOnly;
    return TimeAlignmentStatus.aligned;
  }

  String _taskNote(
    TimeAlignmentStatus status,
    int youtrackMinutes,
    int commitCount,
  ) {
    switch (status) {
      case TimeAlignmentStatus.aligned:
        return 'Задача отражена и в GitLab, и в YouTrack';
      case TimeAlignmentStatus.gitlabOnly:
        return 'Есть коммиты ($commitCount), но нет списаний по задаче';
      case TimeAlignmentStatus.youtrackOnly:
        return 'Время списано ($youtrackMinutesм), коммитов с ID не найдено';
      case TimeAlignmentStatus.mismatch:
        return 'Расхождение между списанным временем и объёмом коммитов';
    }
  }

  double _overallAlignment({
    required int totalYoutrack,
    required int totalGitlab,
    required int alignedDays,
    required int activeDays,
  }) {
    if (activeDays == 0) return 0;
    final dayPart = alignedDays / activeDays * 60;
    if (totalYoutrack == 0 || totalGitlab == 0) {
      return dayPart.clamp(0, 100);
    }
    final ratio = totalYoutrack / totalGitlab;
    final timePart = (100 - (ratio - 1).abs() * 40).clamp(0, 40);
    return (dayPart + timePart).clamp(0, 100);
  }

  List<String> _buildInsights({
    required int totalYoutrack,
    required int totalGitlab,
    required int alignedDays,
    required int mismatchDays,
    required int gitlabOnlyDays,
    required int youtrackOnlyDays,
    required List<TaskTimeComparison> taskComparisons,
  }) {
    final insights = <String>[];

    if (gitlabOnlyDays > 0) {
      insights.add(
        '$gitlabOnlyDays ${_pluralDays(gitlabOnlyDays)} с коммитами, но без достаточного списания в YouTrack',
      );
    }
    if (youtrackOnlyDays > 0) {
      insights.add(
        '$youtrackOnlyDays ${_pluralDays(youtrackOnlyDays)} со списаниями, но без GitLab-коммитов',
      );
    }
    if (alignedDays > 0) {
      insights.add('$alignedDays ${_pluralDays(alignedDays)} хорошо согласованы');
    }

    final gitlabOnlyTasks =
        taskComparisons.where((t) => t.status == TimeAlignmentStatus.gitlabOnly);
    if (gitlabOnlyTasks.isNotEmpty) {
      insights.add(
        '${gitlabOnlyTasks.length} ${_pluralTasks(gitlabOnlyTasks.length)} с кодом, но без трекинга: '
        '${gitlabOnlyTasks.take(3).map((t) => t.taskId).join(', ')}',
      );
    }

    if (totalYoutrack > 0 && totalGitlab > 0) {
      final ratio = (totalYoutrack / totalGitlab * 100).round();
      insights.add(
        'Соотношение YT/GitLab по времени: $ratio% '
        '($totalYoutrack м списано vs ~$totalGitlab м по активности)',
      );
    }

    return insights;
  }

  String _pluralDays(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'дня';
    }
    return 'дней';
  }

  String _pluralTasks(int n) => n == 1 ? 'задача' : 'задач';
}
