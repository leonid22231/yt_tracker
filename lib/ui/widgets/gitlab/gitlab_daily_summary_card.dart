import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

class GitLabDailySummaryCard extends StatelessWidget {
  const GitLabDailySummaryCard({
    super.key,
    required this.summary,
    this.youTrackBaseUrl,
  });

  final DailyActivitySummary summary;
  final String? youTrackBaseUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isActive = summary.commitCount > 0 || summary.branchesTouched > 0;
    final dateLabel = DateFormat('EEEE, d MMMM', 'ru').format(summary.date);

    final content = Padding(
      padding: EdgeInsets.all(p.isOneC ? 8 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: p.isOneC ? 12 : 13,
                    color: isActive ? p.textPrimary : p.textMuted,
                  ),
                ),
              ),
              if (isActive) _ScoreBadge(palette: p, score: summary.productivityScore),
            ],
          ),
          if (!isActive) ...[
            const SizedBox(height: 6),
            Text(
              'Нет активности',
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ] else ...[
            SizedBox(height: p.isOneC ? 6 : 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetricChip(palette: p, icon: Icons.call_merge, label: '${summary.commitCount} комм.'),
                _MetricChip(
                  palette: p,
                  icon: Icons.account_tree_outlined,
                  label: '${summary.branchesTouched} веток',
                ),
                if (summary.branchesCreated > 0)
                  _MetricChip(
                    palette: p,
                    icon: Icons.fiber_new_rounded,
                    label: '${summary.branchesCreated} новых',
                  ),
                _MetricChip(
                  palette: p,
                  icon: Icons.task_alt_outlined,
                  label: '${summary.activeTaskCount} задач',
                ),
                _MetricChip(
                  palette: p,
                  icon: Icons.schedule,
                  label: TimeFormat.minutes(summary.estimatedMinutes),
                ),
                _MetricChip(
                  palette: p,
                  icon: Icons.code,
                  label: '+${summary.totalAdditions}/-${summary.totalDeletions}',
                ),
              ],
            ),
            if (summary.taskIds.isNotEmpty) ...[
              SizedBox(height: p.isOneC ? 6 : 10),
              YouTrackIssueChipList(
                issueIds: summary.taskIds,
                baseUrl: youTrackBaseUrl,
              ),
            ],
          ],
        ],
      ),
    );

    if (p.isOneC) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: OneCDecorations.flatPanel(p),
        child: content,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isActive ? null : AppColors.surface,
      child: content,
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.palette, required this.score});

  final VariantPalette palette;
  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 60
        ? palette.success
        : score >= 30
            ? palette.warning
            : palette.textMuted;

    if (palette.isOneC) {
      return Text(
        score.toStringAsFixed(0),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        score.toStringAsFixed(0),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.palette,
    required this.icon,
    required this.label,
  });

  final VariantPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (palette.isOneC) {
      return Text(
        label,
        style: TextStyle(fontSize: 11, color: palette.textSecondary),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
