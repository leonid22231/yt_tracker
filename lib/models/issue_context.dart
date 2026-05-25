import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_activity.dart';
import 'package:youtrack_timer/models/work_item.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Контекст задачи для передачи в Cursor Agent.
class IssueContext {
  IssueContext({
    required this.issue,
    required this.activities,
    this.existingWorkItems = const [],
  });

  final YouTrackIssue issue;
  final List<IssueActivity> activities;

  /// Уже списанное **мной** время в YouTrack (чужие work items исключены).
  final List<YouTrackWorkItem> existingWorkItems;

  int get existingTotalMinutes =>
      existingWorkItems.fold(0, (s, w) => s + w.minutes);

  /// Сериализация для промпта (без секретов).
  Map<String, dynamic> toJson() => {
        'idReadable': issue.idReadable,
        'summary': issue.summary,
        'isDaily': issue.isDaily,
        'tags': issue.tags,
        'created': issue.created.toIso8601String(),
        'updated': issue.updated.toIso8601String(),
        if (issue.estimateMinutes != null)
          'taskEstimateMinutes': issue.estimateMinutes,
        if (issue.estimatePresentation != null)
          'taskEstimatePresentation': issue.estimatePresentation,
        if (issue.estimateFieldName != null)
          'taskEstimateFieldName': issue.estimateFieldName,
        if (issue.estimateMinutes != null)
          'taskEstimateRemainingMinutes': _remainingEstimateMinutes(),
        'existingWorkItemsScope': 'currentUserOnly',
        'existingWorkItemsTotalMinutes': existingTotalMinutes,
        'existingWorkItems': existingWorkItems
            .map(
              (w) => {
                'date': DateUtils.formatForQuery(w.date),
                'minutes': w.minutes,
                if (w.text != null && w.text!.isNotEmpty) 'text': w.text,
              },
            )
            .toList(),
        'activities': activities
            .map(
              (a) => {
                'timestamp': a.timestamp.toIso8601String(),
                'type': a.type,
                'author': a.author,
                'added': a.added,
                'removed': a.removed,
                if (a.commentText != null) 'comment': a.commentText,
              },
            )
            .toList(),
      };

  /// Оценка минус уже списанное (не ниже 0).
  int? _remainingEstimateMinutes() {
    final estimate = issue.estimateMinutes;
    if (estimate == null) return null;
    final remaining = estimate - existingTotalMinutes;
    return remaining > 0 ? remaining : 0;
  }
}
