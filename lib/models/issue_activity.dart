/// Элемент истории задачи (комментарий, смена статуса и т.д.).
class IssueActivity {
  IssueActivity({
    required this.timestamp,
    required this.type,
    this.author,
    this.added = const [],
    this.removed = const [],
    this.commentText,
  });

  final DateTime timestamp;
  final String type;
  final String? author;
  final List<String> added;
  final List<String> removed;
  final String? commentText;
}
