/// Merge request пользователя из GitLab.
class MergeRequestRecord {
  const MergeRequestRecord({
    required this.projectId,
    required this.projectPath,
    required this.iid,
    required this.title,
    this.sourceBranch = '',
    this.targetBranch = '',
    this.state = '',
    required this.createdAt,
    required this.updatedAt,
    this.mergedAt,
    this.additions = 0,
    this.deletions = 0,
    this.taskIds = const [],
    this.webUrl = '',
  });

  final int projectId;
  final String projectPath;
  final int iid;
  final String title;
  final String sourceBranch;
  final String targetBranch;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? mergedAt;
  final int additions;
  final int deletions;
  final List<String> taskIds;
  final String webUrl;

  int get totalChanges => additions + deletions;

  String get reference =>
      projectPath.isNotEmpty ? '$projectPath!$iid' : '!$iid';

  bool get isMerged => state == 'merged';

  MergeRequestRecord copyWith({
    int? projectId,
    String? projectPath,
    int? iid,
    String? title,
    String? sourceBranch,
    String? targetBranch,
    String? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? mergedAt,
    int? additions,
    int? deletions,
    List<String>? taskIds,
    String? webUrl,
  }) =>
      MergeRequestRecord(
        projectId: projectId ?? this.projectId,
        projectPath: projectPath ?? this.projectPath,
        iid: iid ?? this.iid,
        title: title ?? this.title,
        sourceBranch: sourceBranch ?? this.sourceBranch,
        targetBranch: targetBranch ?? this.targetBranch,
        state: state ?? this.state,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        mergedAt: mergedAt ?? this.mergedAt,
        additions: additions ?? this.additions,
        deletions: deletions ?? this.deletions,
        taskIds: taskIds ?? this.taskIds,
        webUrl: webUrl ?? this.webUrl,
      );
}
