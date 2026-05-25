/// Строка в разбивке дня: уже в YouTrack или новый план.
class DayTaskLine {
  DayTaskLine({
    required this.issueIdReadable,
    required this.summary,
    required this.minutes,
    required this.kind,
    this.note,
  });

  final String issueIdReadable;
  final String summary;
  final int minutes;
  final DayLineKind kind;
  final String? note;
}

enum DayLineKind {
  /// Уже списано в YouTrack до пересчёта.
  existing,

  /// Новые минуты из текущего плана (AI / пересчёт).
  planned,
}

/// Сводка по одному рабочему дню.
class DayTimeline {
  DayTimeline({
    required this.day,
    required this.lines,
    required this.targetMinutes,
  });

  final DateTime day;
  final List<DayTaskLine> lines;
  final int targetMinutes;

  int get existingMinutes =>
      lines.where((l) => l.kind == DayLineKind.existing).fold(0, (s, l) => s + l.minutes);

  int get plannedMinutes =>
      lines.where((l) => l.kind == DayLineKind.planned).fold(0, (s, l) => s + l.minutes);

  int get totalMinutes => existingMinutes + plannedMinutes;

  int get remainingMinutes =>
      (targetMinutes - totalMinutes).clamp(0, targetMinutes);
}
