/// Утилиты для работы с календарём и рабочими днями.
class DateUtils {
  /// Возвращает список рабочих дней (пн–пт) в диапазоне [start, end] включительно.
  static List<DateTime> workingDays(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(last)) {
      if (_isWeekday(current)) {
        days.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  /// Рабочие дни периода без [excludedDates] (больничные, отпуск и т.п.).
  static List<DateTime> activeWorkingDays(
    DateTime start,
    DateTime end, {
    Set<DateTime> excludedDates = const {},
  }) {
    if (excludedDates.isEmpty) return workingDays(start, end);
    final excluded = excludedDates.map(dateOnly).toSet();
    return workingDays(start, end)
        .where((d) => !excluded.contains(dateOnly(d)))
        .toList();
  }

  static bool _isWeekday(DateTime date) {
    // DateTime.weekday: 1 = пн, 7 = вс
    return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
  }

  /// Сравнивает две даты только по календарному дню.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Начало дня в UTC (миллисекунды) — формат даты для YouTrack API.
  static int toYouTrackDateMillis(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    return utc.millisecondsSinceEpoch;
  }

  /// Парсит дату из строки yyyy-MM-dd.
  static DateTime parseDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('Ожидается формат yyyy-MM-dd, получено: $value');
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Календарный день work item из API (без сдвига часового пояса).
  static DateTime parseWorkItemDate(dynamic value) {
    if (value is int) {
      final utc = DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      return DateTime(utc.year, utc.month, utc.day);
    }
    if (value is String) {
      final parsed = DateTime.parse(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Форматирует дату для YouTrack query (yyyy-MM-dd).
  static String formatForQuery(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
