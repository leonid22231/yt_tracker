/// Результат AI-сводки GitLab-аналитики.
class GitLabAiSummary {
  const GitLabAiSummary({
    required this.text,
    required this.withYouTrack,
    required this.generatedAt,
    this.day,
  });

  final String text;
  final bool withYouTrack;
  final DateTime generatedAt;

  /// `null` — сводка за весь выбранный период.
  final DateTime? day;

  bool get isPeriod => day == null;
}
