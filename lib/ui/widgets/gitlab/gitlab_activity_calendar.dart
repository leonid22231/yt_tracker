import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/models/gitlab/productivity_metric.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
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

    final p = context.palette;
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
      decoration: p.isOneC
          ? OneCDecorations.flatPanel(p)
          : BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
      padding: EdgeInsets.all(p.isOneC ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: p.isOneC ? 16 : 18,
                color: p.isOneC ? p.link : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Календарь активности',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: p.isOneC ? 12 : 15,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Text(
                '${DateFormat('d MMM', 'ru').format(start)} — '
                '${DateFormat('d MMM yyyy', 'ru').format(end)}',
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Нажмите на день для подробной аналитики',
            style: TextStyle(fontSize: 11, color: p.textMuted),
          ),
          SizedBox(height: p.isOneC ? 8 : 14),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: p.textMuted,
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
                                palette: p,
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
          _Legend(palette: p, maxScore: effectiveMax),
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
    required this.palette,
    required this.day,
    required this.summary,
    required this.maxScore,
    required this.selected,
    required this.onTap,
  });

  final VariantPalette palette;
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

    Color bg;
    Color borderColor;
    Color textColor;
    Color subColor;
    double borderWidth;

    if (palette.isOneC) {
      if (selected) {
        bg = palette.tableSelected;
        borderColor = palette.borderShadow;
        textColor = palette.tableSelectedText;
        subColor = palette.tableSelectedText;
        borderWidth = 1;
      } else if (active) {
        bg = Color.lerp(palette.inputBackground, palette.tableSelected, t * 0.7)!;
        borderColor = palette.border;
        textColor = t > 0.55 ? palette.tableSelectedText : palette.textPrimary;
        subColor = t > 0.55 ? palette.tableSelectedText : palette.link;
        borderWidth = 1;
      } else {
        bg = palette.inputBackground;
        borderColor = palette.border;
        textColor = palette.textMuted;
        subColor = palette.textMuted;
        borderWidth = 1;
      }
    } else {
      bg = active
          ? Color.lerp(AppColors.surfaceHigh, AppColors.primary, t * 0.85 + 0.15)!
          : AppColors.surfaceHigh.withValues(alpha: 0.5);
      borderColor = selected
          ? AppColors.accent
          : active
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border.withValues(alpha: 0.5);
      textColor = active && t > 0.45 ? Colors.white : AppColors.textSecondary;
      subColor = t > 0.45
          ? Colors.white.withValues(alpha: 0.9)
          : AppColors.primary;
      borderWidth = selected ? 2 : 1;
    }

    final radius = palette.isOneC ? BorderRadius.zero : BorderRadius.circular(10);

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
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: !palette.isOneC && selected
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
                    fontSize: palette.isOneC ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                if (active) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${summary!.commitCount}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: subColor,
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
  const _Legend({required this.palette, required this.maxScore});

  final VariantPalette palette;
  final double maxScore;

  @override
  Widget build(BuildContext context) {
    final low = palette.isOneC ? palette.inputBackground : AppColors.surfaceHigh;
    final high = palette.isOneC ? palette.tableSelected : AppColors.primary;

    return Row(
      children: [
        Text('Меньше', style: TextStyle(fontSize: 10, color: palette.textMuted)),
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
                      color: Color.lerp(low, high, i / 4 * 0.85 + 0.15),
                      border: palette.isOneC
                          ? Border.all(color: palette.border)
                          : null,
                      borderRadius: palette.isOneC
                          ? BorderRadius.zero
                          : BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('Больше', style: TextStyle(fontSize: 10, color: palette.textMuted)),
      ],
    );
  }
}
