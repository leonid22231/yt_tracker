import 'package:youtrack_timer/utils/date_utils.dart';

/// Построение поисковых запросов YouTrack (синтаксис advanced search).
///
/// Поле `started` в большинстве инстансов отсутствует — используем
/// `updated` / `created`, которые есть везде.
class YouTrackQuery {
  /// Задачи, назначенные на меня и обновлённые в периоде (основной запрос).
  static String assignedInPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = DateUtils.formatForQuery(startDate);
    final end = DateUtils.formatForQuery(endDate);
    return 'assignee: me updated: $start .. $end';
  }

  /// Задачи, назначенные на меня и созданные в периоде.
  static String assignedCreatedInPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = DateUtils.formatForQuery(startDate);
    final end = DateUtils.formatForQuery(endDate);
    return 'assignee: me created: $start .. $end';
  }

  /// Все задачи на мне (без фильтра по дате) — запасной вариант.
  static String assignedToMe() => 'assignee: me';

  /// Задачи, где **я** списывал время в периоде (даже без assignee: me / updated).
  static String workByMeInPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = DateUtils.formatForQuery(startDate);
    final end = DateUtils.formatForQuery(endDate);
    return 'work author: me work date: $start .. $end';
  }

  /// Список запросов от более точного к более широкому (для fallback).
  static List<String> assignedInPeriodWithFallbacks({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      [
        assignedToMe(),
        assignedInPeriod(startDate: startDate, endDate: endDate),
        assignedCreatedInPeriod(startDate: startDate, endDate: endDate),
        'for: me updated: ${DateUtils.formatForQuery(startDate)} '
            '.. ${DateUtils.formatForQuery(endDate)}',
      ];

  /// Запрос явно ищет assignee: me — доверяем результату даже без поля assignee в JSON.
  static bool queryTrustsAssigneeMe(String query) {
    final q = query.toLowerCase();
    return q.contains('assignee: me') || q == 'assignee: me';
  }

  /// Только для посуточной шкалы «Моё в YT» (не в план и не в AI).
  static List<String> myWorkTimelineQueries({
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      [
        workByMeInPeriod(startDate: startDate, endDate: endDate),
        'work author: me',
        'has: work work author: me',
      ];
}
