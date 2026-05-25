import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/youtrack_user.dart';

/// Запись затраченного времени (work item) в YouTrack.
class YouTrackWorkItem {
  YouTrackWorkItem({
    required this.id,
    required this.date,
    required this.minutes,
    this.text,
    this.authorId,
    this.authorLogin,
    this.authorName,
    this.creatorId,
    this.creatorLogin,
    this.creatorName,
  });

  final String id;

  /// Дата работы (только дата, без времени).
  final DateTime date;
  final int minutes;
  final String? text;

  final String? authorId;
  final String? authorLogin;
  final String? authorName;
  final String? creatorId;
  final String? creatorLogin;
  final String? creatorName;

  /// Запись списана текущим пользователем (author или creator).
  bool isAuthoredBy(YouTrackUser user) {
    if (_matchesUser(user, authorId, authorLogin)) return true;
    if (_matchesUser(user, creatorId, creatorLogin)) return true;
    if (_matchesName(user, authorName)) return true;
    if (_matchesName(user, creatorName)) return true;
    // Нет автора в ответе API — не отбрасываем (часто это свои записи).
    if (authorId == null &&
        authorLogin == null &&
        creatorId == null &&
        creatorLogin == null) {
      return true;
    }
    return false;
  }

  static bool _matchesUser(
    YouTrackUser user,
    String? id,
    String? login,
  ) {
    if (id != null && id == user.id) return true;
    if (login != null && login.toLowerCase() == user.login.toLowerCase()) {
      return true;
    }
    return false;
  }

  static bool _matchesName(YouTrackUser user, String? name) {
    if (name == null || user.name == null) return false;
    return name.toLowerCase() == user.name!.toLowerCase();
  }
}

/// Планируемая запись времени перед отправкой в API.
class PlannedWorkItem {
  PlannedWorkItem({
    required this.issue,
    required this.date,
    required this.minutes,
    this.comment,
  });

  final YouTrackIssue issue;
  final DateTime date;
  final int minutes;
  final String? comment;
}
