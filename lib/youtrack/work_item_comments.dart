/// Служебные комментарии, которые приложение писало в work items (для очистки).
class WorkItemComments {
  WorkItemComments._();

  static const markers = [
    'youtrack_timer',
    'AI-оценка',
    'Автозаполнение youtrack_timer',
    'Пересчёт youtrack_timer',
    'Дополнение daily',
    'Ручная оценка',
  ];

  static bool isAppMarker(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final lower = text.toLowerCase();
    return markers.any((m) => lower.contains(m.toLowerCase()));
  }
}
