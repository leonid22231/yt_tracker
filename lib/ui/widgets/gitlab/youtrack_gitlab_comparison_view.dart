import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/youtrack_gitlab_comparison.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';

/// UI сверки YouTrack и GitLab.
class YouTrackGitLabComparisonView extends StatelessWidget {
  const YouTrackGitLabComparisonView({
    super.key,
    required this.comparison,
    this.trackedIsDemo = false,
  });

  final YouTrackGitLabComparison comparison;
  final bool trackedIsDemo;

  @override
  Widget build(BuildContext context) {
    final activeDays = comparison.activeDays.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OverviewCard(comparison: comparison, trackedIsDemo: trackedIsDemo),
        if (comparison.insights.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InsightsCard(insights: comparison.insights),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.compare_arrows, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'YouTrack vs GitLab по дням',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(height: 200, child: _DualBarChart(days: activeDays)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (comparison.mismatchedTasks.isNotEmpty) ...[
          const Text(
            'Задачи с расхождениями',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          for (final task in comparison.mismatchedTasks)
            _TaskComparisonCard(task: task),
          const SizedBox(height: 16),
        ],
        const Text(
          'По дням',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 8),
        for (final day in activeDays) _DailyComparisonCard(day: day),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.comparison,
    required this.trackedIsDemo,
  });

  final YouTrackGitLabComparison comparison;
  final bool trackedIsDemo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Сверка времени',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (trackedIsDemo)
                        const Text(
                          'Демо-данные YouTrack',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                _AlignmentBadge(score: comparison.overallAlignmentScore),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatChip(
                  label: 'YouTrack',
                  value: TimeFormat.minutes(comparison.totalYoutrackMinutes),
                  color: AppColors.existing,
                ),
                _StatChip(
                  label: 'GitLab оценка',
                  value: TimeFormat.minutes(comparison.totalGitlabEstimatedMinutes),
                  color: AppColors.primary,
                ),
                _StatChip(
                  label: 'Согласовано',
                  value: '${comparison.alignedDays} дн.',
                  color: AppColors.success,
                ),
                _StatChip(
                  label: 'Расхождения',
                  value: '${comparison.mismatchDays} дн.',
                  color: AppColors.warning,
                ),
                _StatChip(
                  label: 'Код без YT',
                  value: '${comparison.gitlabOnlyDays} дн.',
                  color: AppColors.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: AppColors.warning),
                SizedBox(width: 8),
                Text(
                  'Выводы',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final insight in insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.textMuted)),
                    Expanded(
                      child: Text(
                        insight,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DualBarChart extends StatelessWidget {
  const _DualBarChart({required this.days});

  final List<DailyTimeComparison> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Center(
        child: Text('Нет данных для сравнения', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final maxY = days
        .map((d) => d.youtrackMinutes > d.gitlabEstimatedMinutes
            ? d.youtrackMinutes
            : d.gitlabEstimatedMinutes)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxY + 60).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 36),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('dd.MM').format(days[i].date),
                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: days[i].youtrackMinutes.toDouble(),
                  color: AppColors.existing,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: days[i].gitlabEstimatedMinutes.toDouble(),
                  color: AppColors.primary,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DailyComparisonCard extends StatelessWidget {
  const _DailyComparisonCard({required this.day});

  final DailyTimeComparison day;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, d MMM', 'ru').format(day.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                _StatusChip(status: day.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'YouTrack',
                    value: TimeFormat.minutes(day.youtrackMinutes),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'GitLab',
                    value: TimeFormat.minutes(day.gitlabEstimatedMinutes),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Δ',
                    value: '${day.deltaMinutes >= 0 ? '+' : ''}${day.deltaMinutes}м',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              day.insight,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskComparisonCard extends StatelessWidget {
  const _TaskComparisonCard({required this.task});

  final TaskTimeComparison task;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.taskId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (task.issueSummary.isNotEmpty)
                    Text(
                      task.issueSummary,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    task.note,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusChip(status: task.status, compact: true),
                const SizedBox(height: 4),
                Text(
                  'YT ${TimeFormat.minutes(task.youtrackMinutes)}',
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  'GL ${task.gitlabCommitCount} комм.',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlignmentBadge extends StatelessWidget {
  const _AlignmentBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? AppColors.success
        : score >= 40
            ? AppColors.warning
            : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${score.toStringAsFixed(0)}%',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.compact = false});

  final TimeAlignmentStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TimeAlignmentStatus.aligned => ('OK', AppColors.success),
      TimeAlignmentStatus.gitlabOnly => ('Код', AppColors.danger),
      TimeAlignmentStatus.youtrackOnly => ('YT', AppColors.warning),
      TimeAlignmentStatus.mismatch => ('Δ', AppColors.warning),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
