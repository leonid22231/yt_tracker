import 'package:youtrack_timer/models/gitlab/branch_record.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/merge_request_record.dart';

/// Сводка GitLab-активности за один день.
class DailyActivitySummary {
  const DailyActivitySummary({
    required this.date,
    this.commitCount = 0,
    this.branchesTouched = 0,
    this.branchesCreated = 0,
    this.taskIds = const [],
    this.totalAdditions = 0,
    this.totalDeletions = 0,
    this.estimatedMinutes = 0,
    this.productivityScore = 0,
    this.commits = const [],
    this.branches = const [],
    this.commitRecords = const [],
    this.branchRecords = const [],
    this.mergeRequests = const [],
  });

  final DateTime date;
  final int commitCount;
  final int branchesTouched;
  final int branchesCreated;
  final List<String> taskIds;
  final int totalAdditions;
  final int totalDeletions;
  final int estimatedMinutes;
  final double productivityScore;
  final List<String> commits;
  final List<String> branches;
  final List<CommitRecord> commitRecords;
  final List<BranchRecord> branchRecords;
  final List<MergeRequestRecord> mergeRequests;

  int get activeTaskCount => taskIds.length;
  int get totalChanges => totalAdditions + totalDeletions;
  int get mergeRequestCount => mergeRequests.length;

  double get changesPerCommit =>
      commitCount > 0 ? totalChanges / commitCount : 0;

  DailyActivitySummary copyWith({
    DateTime? date,
    int? commitCount,
    int? branchesTouched,
    int? branchesCreated,
    List<String>? taskIds,
    int? totalAdditions,
    int? totalDeletions,
    int? estimatedMinutes,
    double? productivityScore,
    List<String>? commits,
    List<String>? branches,
    List<CommitRecord>? commitRecords,
    List<BranchRecord>? branchRecords,
    List<MergeRequestRecord>? mergeRequests,
  }) =>
      DailyActivitySummary(
        date: date ?? this.date,
        commitCount: commitCount ?? this.commitCount,
        branchesTouched: branchesTouched ?? this.branchesTouched,
        branchesCreated: branchesCreated ?? this.branchesCreated,
        taskIds: taskIds ?? this.taskIds,
        totalAdditions: totalAdditions ?? this.totalAdditions,
        totalDeletions: totalDeletions ?? this.totalDeletions,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
        productivityScore: productivityScore ?? this.productivityScore,
        commits: commits ?? this.commits,
        branches: branches ?? this.branches,
        commitRecords: commitRecords ?? this.commitRecords,
        branchRecords: branchRecords ?? this.branchRecords,
        mergeRequests: mergeRequests ?? this.mergeRequests,
      );
}
