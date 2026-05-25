import 'package:youtrack_timer/models/youtrack_user.dart';

/// Задача YouTrack.
class YouTrackIssue {
  YouTrackIssue({
    required this.id,
    required this.idReadable,
    required this.summary,
    required this.created,
    required this.updated,
    required this.isDaily,
    this.tags = const [],
    this.estimateMinutes,
    this.estimatePresentation,
    this.estimateFieldName,
    this.assigneeId,
    this.assigneeLogin,
    this.assigneeName,
  });

  /// Внутренний ID (например, 2-35) — используется в API.
  final String id;

  /// Человекочитаемый ключ (например, PROJ-123).
  final String idReadable;
  final String summary;
  final DateTime created;
  final DateTime updated;
  final bool isDaily;
  final List<String> tags;

  /// Оценка задачи из YouTrack (поле Period: Estimation и т.п.), в минутах.
  final int? estimateMinutes;

  /// Человекочитаемая оценка (например, «2d 4h»).
  final String? estimatePresentation;

  /// Имя поля оценки в проекте.
  final String? estimateFieldName;

  final String? assigneeId;
  final String? assigneeLogin;
  final String? assigneeName;

  /// Исполнитель совпадает с текущим пользователем.
  bool isAssignedTo(YouTrackUser user) {
    if (assigneeId != null && assigneeId == user.id) return true;
    if (assigneeLogin != null &&
        assigneeLogin!.toLowerCase() == user.login.toLowerCase()) {
      return true;
    }
    return false;
  }

  @override
  String toString() => '$idReadable: $summary';
}
