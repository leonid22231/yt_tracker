import 'package:youtrack_timer/models/gitlab/task_reference.dart';

/// Извлекает task ID по шаблону ABC-123 из текста.
class TaskIdExtractor {
  static final RegExp taskIdPattern = RegExp(r'\b([A-Z][A-Z0-9]+-\d+)\b');

  static List<String> extractFromText(
    String text, {
    TaskReferenceSource source = TaskReferenceSource.commitMessage,
  }) {
    if (text.isEmpty) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final match in taskIdPattern.allMatches(text)) {
      final id = match.group(1)!;
      if (seen.add(id)) result.add(id);
    }
    return result;
  }

  static List<String> extractFromTexts(Iterable<String> texts) {
    final seen = <String>{};
    final result = <String>[];
    for (final text in texts) {
      for (final id in extractFromText(text)) {
        if (seen.add(id)) result.add(id);
      }
    }
    return result;
  }

  static List<TaskReference> extractReferences(String text, TaskReferenceSource source) {
    if (text.isEmpty) return const [];
    final seen = <String>{};
    final result = <TaskReference>[];
    for (final match in taskIdPattern.allMatches(text)) {
      final id = match.group(1)!;
      if (seen.add(id)) {
        result.add(TaskReference(taskId: id, source: source, sourceText: text));
      }
    }
    return result;
  }
}
