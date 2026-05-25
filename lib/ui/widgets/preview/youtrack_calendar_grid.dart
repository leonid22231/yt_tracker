import 'package:flutter/material.dart';
import 'package:youtrack_timer/models/plan_preview_entry.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/widgets/preview/youtrack_calendar_cell.dart';

/// Сетка календаря проверки (пн–пт), как в YouTrack.
class YoutrackCalendarGrid extends StatelessWidget {
  const YoutrackCalendarGrid({
    super.key,
    required this.weekRows,
    required this.onIssueTap,
  });

  final List<List<PlanPreviewDay?>> weekRows;
  final void Function(PlanPreviewRow row, PlanPreviewDay day) onIssueTap;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт'];
  static const _cellHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: _weekdays
              .map(
                (d) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: YtCalendarColors.cellBorder),
                      ),
                    ),
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...weekRows.map(_weekRow),
      ],
    );
  }

  Widget _weekRow(List<PlanPreviewDay?> days) {
    return SizedBox(
      height: _cellHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(5, (col) {
          final day = col < days.length ? days[col] : null;
          return Expanded(
            child: day == null
                ? const YoutrackCalendarEmptyCell()
                : YoutrackCalendarCell(
                    day: day,
                    onIssueTap: (row) => onIssueTap(row, day),
                  ),
          );
        }),
      ),
    );
  }
}
