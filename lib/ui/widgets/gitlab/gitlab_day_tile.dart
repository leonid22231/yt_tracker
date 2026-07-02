import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
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
    final active =
        summary.commitCount > 0 || summary.branchesTouched > 0;
    final score = summary.productivityScore;
    final color = score >= 60
        ? AppColors.success
        : score >= 30
            ? AppColors.warning
            : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 132,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE', 'ru').format(summary.date),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('d MMM', 'ru').format(summary.date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (!active)
                  const Text(
                    '—',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                else ...[
                  Row(
                    children: [
                      Icon(Icons.call_merge, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '${summary.commitCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeFormat.minutes(summary.estimatedMinutes),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
