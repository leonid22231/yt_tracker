/// Ветка, связанная с активностью пользователя.
class BranchRecord {
  const BranchRecord({
    required this.name,
    required this.projectId,
    required this.projectName,
    required this.lastActivityAt,
    this.isNew = false,
    this.taskIds = const [],
  });

  final String name;
  final int projectId;
  final String projectName;
  final DateTime lastActivityAt;
  final bool isNew;
  final List<String> taskIds;

  BranchRecord copyWith({
    String? name,
    int? projectId,
    String? projectName,
    DateTime? lastActivityAt,
    bool? isNew,
    List<String>? taskIds,
  }) =>
      BranchRecord(
        name: name ?? this.name,
        projectId: projectId ?? this.projectId,
        projectName: projectName ?? this.projectName,
        lastActivityAt: lastActivityAt ?? this.lastActivityAt,
        isNew: isNew ?? this.isNew,
        taskIds: taskIds ?? this.taskIds,
      );
}
