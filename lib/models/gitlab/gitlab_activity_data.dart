import 'package:youtrack_timer/models/gitlab/branch_record.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_user_info.dart';
import 'package:youtrack_timer/models/gitlab/merge_request_record.dart';
import 'package:youtrack_timer/models/gitlab/productivity_metric.dart';

/// Сырые и агрегированные данные GitLab за период.
class GitLabActivityData {
  const GitLabActivityData({
    required this.user,
    required this.commits,
    required this.branches,
    required this.metrics,
    required this.fetchedAt,
    this.projectCount = 0,
    this.isDemo = false,
    this.gitLabBaseUrl = '',
    this.mergeRequests = const [],
  });

  final GitLabUserInfo user;
  final List<CommitRecord> commits;
  final List<BranchRecord> branches;
  final List<MergeRequestRecord> mergeRequests;
  final ProductivityMetric metrics;
  final DateTime fetchedAt;
  final int projectCount;
  final bool isDemo;
  final String gitLabBaseUrl;

  bool get isEmpty => commits.isEmpty && branches.isEmpty;
}
