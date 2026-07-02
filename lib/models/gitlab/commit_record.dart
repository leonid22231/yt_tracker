/// Коммит пользователя из GitLab.
class CommitRecord {
  const CommitRecord({
    required this.id,
    required this.shortId,
    required this.message,
    required this.committedAt,
    required this.projectId,
    required this.projectName,
    this.branchName = '',
    this.additions = 0,
    this.deletions = 0,
    this.taskIds = const [],
    this.mergeRequestIid,
    this.mergeRequestTitle = '',
    this.webUrl = '',
  });

  final String id;
  final String shortId;
  final String message;
  final DateTime committedAt;
  final int projectId;
  final String projectName;
  final String branchName;
  final int additions;
  final int deletions;
  final List<String> taskIds;
  final int? mergeRequestIid;
  final String mergeRequestTitle;
  final String webUrl;

  int get totalChanges => additions + deletions;

  CommitRecord copyWith({
    String? id,
    String? shortId,
    String? message,
    DateTime? committedAt,
    int? projectId,
    String? projectName,
    String? branchName,
    int? additions,
    int? deletions,
    List<String>? taskIds,
    int? mergeRequestIid,
    String? mergeRequestTitle,
    String? webUrl,
    bool clearMergeRequest = false,
  }) =>
      CommitRecord(
        id: id ?? this.id,
        shortId: shortId ?? this.shortId,
        message: message ?? this.message,
        committedAt: committedAt ?? this.committedAt,
        projectId: projectId ?? this.projectId,
        projectName: projectName ?? this.projectName,
        branchName: branchName ?? this.branchName,
        additions: additions ?? this.additions,
        deletions: deletions ?? this.deletions,
        taskIds: taskIds ?? this.taskIds,
        mergeRequestIid:
            clearMergeRequest ? null : (mergeRequestIid ?? this.mergeRequestIid),
        mergeRequestTitle: mergeRequestTitle ?? this.mergeRequestTitle,
        webUrl: webUrl ?? this.webUrl,
      );
}
