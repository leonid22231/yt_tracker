/// Ссылка на задачу, извлечённая из коммита или ветки.
class TaskReference {
  const TaskReference({
    required this.taskId,
    required this.source,
    this.sourceText = '',
  });

  final String taskId;
  final TaskReferenceSource source;
  final String sourceText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskReference &&
          taskId == other.taskId &&
          source == other.source;

  @override
  int get hashCode => Object.hash(taskId, source);
}

enum TaskReferenceSource {
  commitMessage,
  branchName,
  eventRef,
}
