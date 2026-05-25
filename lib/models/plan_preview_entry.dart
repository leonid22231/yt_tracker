import 'package:youtrack_timer/models/day_timeline.dart';

/// Статус новой записи при проверке (без записи в API).
enum PreviewWriteStatus {
  pending,
  willCreate,
  willSkip,
}

/// Одна строка в ячейке календаря.
class PlanPreviewRow {
  PlanPreviewRow({
    required this.issueIdReadable,
    required this.summary,
    required this.existingMinutes,
    required this.plannedMinutes,
    this.plannedStatus,
  });

  final String issueIdReadable;
  final String summary;
  final int existingMinutes;
  final int plannedMinutes;
  final PreviewWriteStatus? plannedStatus;

  int get totalMinutes => existingMinutes + plannedMinutes;

  bool get hasPlanned => plannedMinutes > 0;

  DayLineKind? get primaryKind {
    if (plannedMinutes > 0) return DayLineKind.planned;
    if (existingMinutes > 0) return DayLineKind.existing;
    return null;
  }
}

/// Один день в календаре проверки.
class PlanPreviewDay {
  PlanPreviewDay({
    required this.day,
    required this.rows,
    required this.targetMinutes,
  });

  final DateTime day;
  final List<PlanPreviewRow> rows;
  final int targetMinutes;

  int get totalMinutes =>
      rows.fold(0, (sum, r) => sum + r.totalMinutes);

  bool get meetsTarget => totalMinutes >= targetMinutes;
}
