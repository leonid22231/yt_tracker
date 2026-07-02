import 'package:youtrack_timer/models/gitlab/branch_record.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/models/gitlab/merge_request_record.dart';
import 'package:youtrack_timer/models/gitlab/productivity_metric.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_time_estimator.dart';
import 'package:youtrack_timer/services/gitlab/task_id_extractor.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Агрегация GitLab-активности по дням и расчёт продуктивности.
class GitLabAnalyticsService {
  GitLabAnalyticsService({
    GitLabTimeEstimator? timeEstimator,
  }) : _timeEstimator = timeEstimator ?? GitLabTimeEstimator();

  final GitLabTimeEstimator _timeEstimator;

  ProductivityMetric buildMetrics({
    required List<CommitRecord> commits,
    required List<BranchRecord> branches,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    List<MergeRequestRecord> mergeRequests = const [],
  }) {
    final summaries = aggregateByDay(
      commits: commits,
      branches: branches,
      mergeRequests: mergeRequests,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    if (summaries.isEmpty) {
      return ProductivityMetric(dailySummaries: summaries);
    }

    final activeDays = summaries
        .where((d) => d.commitCount > 0 || d.branchesTouched > 0)
        .toList();
    final totalCommits = summaries.fold<int>(0, (s, d) => s + d.commitCount);
    final allTasks = <String>{};
    for (final d in summaries) {
      allTasks.addAll(d.taskIds);
    }

    final totalAdditions =
        commits.fold<int>(0, (s, c) => s + c.additions);
    final totalDeletions =
        commits.fold<int>(0, (s, c) => s + c.deletions);
    final totalChanges = totalAdditions + totalDeletions;

    final avgCommits = activeDays.isEmpty
        ? 0.0
        : totalCommits / activeDays.length;
    final avgTasks = activeDays.isEmpty
        ? 0.0
        : activeDays.fold<double>(0, (s, d) => s + d.activeTaskCount) /
            activeDays.length;
    final avgMinutes = activeDays.isEmpty
        ? 0.0
        : activeDays.fold<double>(0, (s, d) => s + d.estimatedMinutes) /
            activeDays.length;
    final avgScore = activeDays.isEmpty
        ? 0.0
        : activeDays.fold<double>(0, (s, d) => s + d.productivityScore) /
            activeDays.length;

    DailyActivitySummary? peak;
    DailyActivitySummary? low;
    for (final d in activeDays) {
      if (peak == null || d.productivityScore > peak.productivityScore) {
        peak = d;
      }
      if (low == null || d.productivityScore < low.productivityScore) {
        low = d;
      }
    }

    final projectCounts = <String, int>{};
    for (final c in commits) {
      if (c.projectName.isEmpty) continue;
      projectCounts[c.projectName] = (projectCounts[c.projectName] ?? 0) + 1;
    }
    final topProject = projectCounts.entries.isEmpty
        ? ''
        : (projectCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    return ProductivityMetric(
      dailySummaries: summaries,
      averageCommitsPerDay: avgCommits,
      averageTasksPerDay: avgTasks,
      averageEstimatedMinutes: avgMinutes,
      peakDay: peak?.date,
      lowDay: low?.date,
      totalCommits: totalCommits,
      totalTasks: allTasks.length,
      totalEstimatedMinutes: summaries.fold<int>(
        0,
        (s, d) => s + d.estimatedMinutes,
      ),
      totalAdditions: totalAdditions,
      totalDeletions: totalDeletions,
      activeDaysCount: activeDays.length,
      averageProductivityScore: avgScore,
      longestActiveStreak: _longestStreak(summaries),
      topProject: topProject,
      averageChangesPerCommit:
          totalCommits > 0 ? totalChanges / totalCommits : 0,
      mergeRequestCount: mergeRequests.length,
    );
  }

  int _longestStreak(List<DailyActivitySummary> summaries) {
    var best = 0;
    var current = 0;
    for (final d in summaries) {
      final active = d.commitCount > 0 || d.branchesTouched > 0;
      if (active) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }

  List<DailyActivitySummary> aggregateByDay({
    required List<CommitRecord> commits,
    required List<BranchRecord> branches,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    List<MergeRequestRecord> mergeRequests = const [],
  }) {
    final start = DateUtils.dateOnly(rangeStart);
    final end = DateUtils.dateOnly(rangeEnd);
    final buckets = <DateTime, _DayBucket>{};

    var current = start;
    while (!current.isAfter(end)) {
      buckets[current] = _DayBucket(date: current);
      current = current.add(const Duration(days: 1));
    }

    for (final commit in commits) {
      final day = DateUtils.dateOnly(commit.committedAt);
      if (!buckets.containsKey(day)) continue;
      buckets[day]!.addCommit(commit);
    }

    for (final branch in branches) {
      final day = DateUtils.dateOnly(branch.lastActivityAt);
      if (!buckets.containsKey(day)) continue;
      buckets[day]!.addBranch(branch);
    }

    for (final mr in mergeRequests) {
      final day = DateUtils.dateOnly(mr.updatedAt);
      if (buckets.containsKey(day)) {
        buckets[day]!.addMergeRequest(mr);
      }
      if (mr.mergedAt != null) {
        final mergedDay = DateUtils.dateOnly(mr.mergedAt!);
        if (buckets.containsKey(mergedDay)) {
          buckets[mergedDay]!.addMergeRequest(mr);
        }
      }
    }

    _propagateBranchTasks(buckets);

    return buckets.values.map((b) => b.toSummary(_timeEstimator)).toList();
  }

  void _propagateBranchTasks(Map<DateTime, _DayBucket> buckets) {
    for (final bucket in buckets.values) {
      for (final branch in bucket.branches) {
        for (final taskId in branch.taskIds) {
          bucket.taskIds.add(taskId);
        }
      }
      for (final mr in bucket.mergeRequests) {
        bucket.taskIds.addAll(mr.taskIds);
      }
    }
  }
}

class _DayBucket {
  _DayBucket({required this.date});

  final DateTime date;
  final commits = <CommitRecord>[];
  final branches = <BranchRecord>[];
  final mergeRequests = <MergeRequestRecord>[];
  final taskIds = <String>{};
  var additions = 0;
  var deletions = 0;
  var branchesCreated = 0;

  void addCommit(CommitRecord commit) {
    commits.add(commit);
    additions += commit.additions;
    deletions += commit.deletions;
    taskIds.addAll(commit.taskIds);
    if (commit.branchName.isNotEmpty) {
      taskIds.addAll(TaskIdExtractor.extractFromText(commit.branchName));
    }
  }

  void addBranch(BranchRecord branch) {
    branches.add(branch);
    taskIds.addAll(branch.taskIds);
    if (branch.isNew) branchesCreated++;
  }

  void addMergeRequest(MergeRequestRecord mr) {
    final key = '${mr.projectId}!${mr.iid}';
    if (mergeRequests.any((m) => '${m.projectId}!${m.iid}' == key)) return;
    mergeRequests.add(mr);
    taskIds.addAll(mr.taskIds);
  }

  DailyActivitySummary toSummary(GitLabTimeEstimator estimator) {
    final estimated = estimator.estimateMinutes(
      commitCount: commits.length,
      taskCount: taskIds.length,
      totalChanges: additions + deletions,
      branchesTouched: branches.length,
    );
    final productivity = estimator.productivityScore(
      commitCount: commits.length,
      taskCount: taskIds.length,
      estimatedMinutes: estimated,
      totalChanges: additions + deletions,
    );

    return DailyActivitySummary(
      date: date,
      commitCount: commits.length,
      branchesTouched: branches.length,
      branchesCreated: branchesCreated,
      taskIds: taskIds.toList()..sort(),
      totalAdditions: additions,
      totalDeletions: deletions,
      estimatedMinutes: estimated,
      productivityScore: productivity,
      commits: commits.map((c) => c.shortId).toList(),
      branches: branches.map((b) => b.name).toList(),
      commitRecords: List<CommitRecord>.from(commits),
      branchRecords: List<BranchRecord>.from(branches),
      mergeRequests: List<MergeRequestRecord>.from(mergeRequests),
    );
  }
}
