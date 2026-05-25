/// Разбор исполнителя из ответа Issue (верхний assignee или custom field).
class IssueAssigneeParser {
  static ({String? id, String? login, String? name}) parse(
    Map<String, dynamic> map,
  ) {
    final top = map['assignee'];
    if (top is Map<String, dynamic>) {
      return (
        id: top['id'] as String?,
        login: top['login'] as String?,
        name: top['name'] as String? ?? top['fullName'] as String?,
      );
    }

    final fields = map['customFields'] as List<dynamic>?;
    if (fields == null) return (id: null, login: null, name: null);

    for (final raw in fields) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String?)?.toLowerCase() ?? '';
      if (!_isAssigneeFieldName(name)) continue;

      final value = raw['value'];
      if (value is! Map<String, dynamic>) continue;

      return (
        id: value['id'] as String?,
        login: value['login'] as String?,
        name: value['name'] as String? ?? value['fullName'] as String?,
      );
    }

    return (id: null, login: null, name: null);
  }

  static bool _isAssigneeFieldName(String lower) {
    return lower.contains('assignee') ||
        lower.contains('исполнит') ||
        lower == 'assignee';
  }
}
