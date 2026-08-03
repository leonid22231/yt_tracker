import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';

/// Компактная плитка дня для горизонтальной ленты.
class GitLabDayTile extends StatelessWidget {
  const GitLabDayTile({
    super.key,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final DailyActivitySummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = summary.commitCount > 0 || summary.branchesTouched > 0;
    final score = summary.productivityScore;
    final color = score >= 60
        ? p.success
        : score >= 30
            ? p.warning
            : p.textMuted;

    BoxDecoration decoration;
    if (p.isOneC) {
      decoration = selected
          ? BoxDecoration(
              color: p.tableSelected,
              border: Border.all(color: p.border),
            )
          : OneCDecorations.raised(p);
    } else {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [
                  AppColors.primary.withValues(alpha: 0.35),
                  AppColors.accent.withValues(alpha: 0.12),
                ]
              : [
                  AppColors.card,
                  AppColors.surfaceHigh,
                ],
        ),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
          width: selected ? 2 : 1,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: p.isOneC ? BorderRadius.zero : BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: p.isOneC ? 120 : 132,
            padding: EdgeInsets.all(p.isOneC ? 8 : 12),
            decoration: decoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE', 'ru').format(summary.date),
                  style: TextStyle(
                    fontSize: 10,
                    color: selected && p.isOneC ? p.tableSelectedText : p.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('d MMM', 'ru').format(summary.date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected && p.isOneC ? p.tableSelectedText : p.textPrimary,
                  ),
                ),
                const Spacer(),
                if (!active)
                  Text(
                    '—',
                    style: TextStyle(
                      color: selected && p.isOneC ? p.tableSelectedText : p.textMuted,
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Icon(
                        Icons.call_merge,
                        size: 12,
                        color: selected && p.isOneC ? p.tableSelectedText : color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${summary.commitCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected && p.isOneC ? p.tableSelectedText : p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeFormat.minutes(summary.estimatedMinutes),
                    style: TextStyle(
                      fontSize: 10,
                      color: selected && p.isOneC ? p.tableSelectedText : p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (p.isOneC)
                    Text(
                      score.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected ? p.tableSelectedText : color,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        score.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
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
