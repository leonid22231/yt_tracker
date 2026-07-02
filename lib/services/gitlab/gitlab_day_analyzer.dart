import 'package:youtrack_timer/models/gitlab/branch_record.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/merge_request_record.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Детальная аналитика за один день.
class GitLabDayDetail {
  const GitLabDayDetail({
    required this.date,
    required this.summary,
    required this.commits,
    required this.branches,
    required this.mergeRequests,
    required this.projects,
  });

  final DateTime date;
  final DailyActivitySummary summary;
  final List<CommitRecord> commits;
  final List<BranchRecord> branches;
  final List<MergeRequestRecord> mergeRequests;
  final List<String> projects;

  bool get isActive =>
      commits.isNotEmpty ||
      branches.isNotEmpty ||
      mergeRequests.isNotEmpty;

  int get commitCount => commits.length;
  int get branchCount => branches.length;
  int get mergeRequestCount => mergeRequests.length;

  Map<String, int> get commitsByProject {
    final map = <String, int>{};
    for (final c in commits) {
      final key = c.projectName.isNotEmpty ? c.projectName : 'unknown';
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Map<String, List<CommitRecord>> get commitsByTask {
    final map = <String, List<CommitRecord>>{};
    for (final c in commits) {
      if (c.taskIds.isEmpty) {
        map.putIfAbsent('—', () => []).add(c);
      } else {
        for (final id in c.taskIds) {
          map.putIfAbsent(id, () => []).add(c);
        }
      }
    }
    return map;
  }
}

/// Сборка детализации дня из загруженных данных.
class GitLabDayAnalyzer {
  const GitLabDayAnalyzer();

  GitLabDayDetail build({
    required GitLabActivityData activity,
    required DateTime date,
  }) {
    final day = DateUtils.dateOnly(date);
    final summary = activity.metrics.dailySummaries
        .cast<DailyActivitySummary?>()
        .firstWhere(
          (d) => DateUtils.isSameDay(d!.date, day),
          orElse: () => DailyActivitySummary(date: day),
        )!;

    final commits = activity.commits
        .where((c) => DateUtils.isSameDay(c.committedAt, day))
        .toList()
      ..sort((a, b) => b.committedAt.compareTo(a.committedAt));

    final branches = activity.branches
        .where((b) => DateUtils.isSameDay(b.lastActivityAt, day))
        .toList()
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));

    final mergeRequests = activity.mergeRequests
        .where((mr) => _mrOnDay(mr, day, commits))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final projects = <String>{
      ...commits.map((c) => c.projectName).where((p) => p.isNotEmpty),
      ...branches.map((b) => b.projectName).where((p) => p.isNotEmpty),
      ...mergeRequests.map((m) => m.projectPath).where((p) => p.isNotEmpty),
    }.toList()
      ..sort();

    return GitLabDayDetail(
      date: day,
      summary: summary.commitRecords.isNotEmpty
          ? summary
          : summary.copyWith(
              commitRecords: commits,
              branchRecords: branches,
              mergeRequests: mergeRequests,
            ),
      commits: commits,
      branches: branches,
      mergeRequests: mergeRequests,
      projects: projects,
    );
  }

  bool _mrOnDay(
    MergeRequestRecord mr,
    DateTime day,
    List<CommitRecord> dayCommits,
  ) {
    if (DateUtils.isSameDay(mr.updatedAt, day)) return true;
    if (mr.mergedAt != null && DateUtils.isSameDay(mr.mergedAt!, day)) {
      return true;
    }
    if (DateUtils.isSameDay(mr.createdAt, day)) return true;
    return dayCommits.any((c) => c.mergeRequestIid == mr.iid);
  }
}
