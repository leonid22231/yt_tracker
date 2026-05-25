import 'package:youtrack_timer/models/issue.dart';

/// AI-оценка времени на задачу в конкретный день.
class TimeEstimate {
  TimeEstimate({
    required this.issueIdReadable,
    required this.date,
    required this.minutes,
    required this.reasoning,
    this.confidence = 0.5,
  });

  final String issueIdReadable;
  final DateTime date;
  final int minutes;
  final String reasoning;
  final double confidence;

  factory TimeEstimate.fromJson(Map<String, dynamic> json) {
    final dayStr = json['day'] as String? ?? json['date'] as String? ?? '';
    final parts = dayStr.split('-');
    final date = parts.length == 3
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
        : DateTime.now();

    return TimeEstimate(
      issueIdReadable:
          json['issueIdReadable'] as String? ?? json['issue'] as String? ?? '',
      date: date,
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      reasoning: json['reasoning'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

/// Результат анализа Cursor Agent.
class AiEstimationResult {
  AiEstimationResult({
    required this.estimates,
    this.summary = '',
    this.usedAi = true,
  });

  final List<TimeEstimate> estimates;
  final String summary;
  final bool usedAi;
}

/// Запись плана с обоснованием (для UI).
class PlannedEntry {
  PlannedEntry({
    required this.issue,
    required this.date,
    required this.minutes,
    this.comment,
    this.reasoning,
    this.source = PlanSource.even,
  });

  final YouTrackIssue issue;
  final DateTime date;
  final int minutes;
  final String? comment;
  final String? reasoning;
  final PlanSource source;
}

enum PlanSource { ai, even, manual }
