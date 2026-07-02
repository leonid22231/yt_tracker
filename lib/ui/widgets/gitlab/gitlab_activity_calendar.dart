import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/models/gitlab/productivity_metric.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Календарь-heatmap с кликом по дню.
class GitLabActivityCalendar extends StatelessWidget {
  const GitLabActivityCalendar({
    super.key,
    required this.metrics,
    this.selectedDay,
    required this.onDayTap,
  });

  final ProductivityMetric metrics;
  final DateTime? selectedDay;
  final void Function(DateTime day) onDayTap;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    if (metrics.dailySummaries.isEmpty) return const SizedBox.shrink();

    final start = metrics.dailySummaries.first.date;
    final end = metrics.dailySummaries.last.date;
    final byDay = {
      for (final s in metrics.dailySummaries) DateUtils.dateOnly(s.date): s,
    };
    final maxScore = metrics.dailySummaries
        .map((s) => s.productivityScore)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final effectiveMax = maxScore > 0 ? maxScore : 100.0;

    final weeks = <List<DateTime?>>[];
    var cursor = _weekStart(start);
    final last = DateUtils.dateOnly(end);

    while (!cursor.isAfter(last)) {
      final week = List<DateTime?>.filled(7, null);
      for (var i = 0; i < 7; i++) {
        final day = cursor.add(Duration(days: i));
        if (!day.isBefore(start) && !day.isAfter(last)) {
          week[i] = day;
        }
      }
      weeks.add(week);
      cursor = cursor.add(const Duration(days: 7));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Календарь активности',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Text(
                '${DateFormat('d MMM', 'ru').format(start)} — '
                '${DateFormat('d MMM yyyy', 'ru').format(end)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Нажмите на день для подробной аналитики',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final week in weeks) ...[
            Row(
              children: [
                for (final day in week)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: day == null
                            ? const SizedBox.shrink()
                            : _DayCell(
                                day: day,
                                summary: byDay[day],
                                maxScore: effectiveMax,
                                selected: selectedDay != null &&
                                    DateUtils.isSameDay(day, selectedDay!),
                                onTap: () => onDayTap(day),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _Legend(maxScore: effectiveMax),
        ],
      ),
    );
  }

  static DateTime _weekStart(DateTime date) {
    final d = DateUtils.dateOnly(date);
    final mondayBased = d.weekday - 1;
    return d.subtract(Duration(days: mondayBased));
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.summary,
    required this.maxScore,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final DailyActivitySummary? summary;
  final double maxScore;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = summary != null &&
        (summary!.commitCount > 0 || summary!.branchesTouched > 0);
    final score = summary?.productivityScore ?? 0;
    final t = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
    final bg = active
        ? Color.lerp(AppColors.surfaceHigh, AppColors.primary, t * 0.85 + 0.15)!
        : AppColors.surfaceHigh.withValues(alpha: 0.5);

    return Tooltip(
      message: active
          ? '${DateFormat('d MMMM', 'ru').format(day)}\n'
            '${summary!.commitCount} комм. · ${summary!.activeTaskCount} задач\n'
            'Продуктивность ${score.toStringAsFixed(0)}'
          : DateFormat('d MMMM', 'ru').format(day),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppColors.accent
                    : active
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : AppColors.border.withValues(alpha: 0.5),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active && t > 0.45
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
                if (active) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${summary!.commitCount}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: t > 0.45
                          ? Colors.white.withValues(alpha: 0.9)
                          : AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.maxScore});

  final double maxScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Меньше', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        AppColors.surfaceHigh,
                        AppColors.primary,
                        i / 4 * 0.85 + 0.15,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Text('Больше', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}
