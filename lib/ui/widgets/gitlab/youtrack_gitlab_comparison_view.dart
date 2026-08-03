import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/youtrack_gitlab_comparison.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_chart_theme.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

Widget _comparisonPanel(
  BuildContext context,
  Widget child, {
  EdgeInsetsGeometry? padding,
  EdgeInsetsGeometry? margin,
  Color? cardColor,
}) {
  final p = context.palette;
  if (p.isOneC) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      padding: padding ?? const EdgeInsets.all(10),
      decoration: OneCDecorations.flatPanel(p),
      child: child,
    );
  }
  return Card(
    margin: margin,
    color: cardColor,
    child: Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    ),
  );
}

/// UI сверки YouTrack и GitLab.
class YouTrackGitLabComparisonView extends StatelessWidget {
  const YouTrackGitLabComparisonView({
    super.key,
    required this.comparison,
    this.trackedIsDemo = false,
    this.youTrackBaseUrl,
  });

  final YouTrackGitLabComparison comparison;
  final bool trackedIsDemo;
  final String? youTrackBaseUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final activeDays = comparison.activeDays.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OverviewCard(comparison: comparison, trackedIsDemo: trackedIsDemo),
        if (comparison.insights.isNotEmpty) ...[
          SizedBox(height: p.isOneC ? 6 : 12),
          _InsightsCard(insights: comparison.insights),
        ],
        SizedBox(height: p.isOneC ? 8 : 16),
        _comparisonPanel(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChartPanelHeader(
                theme: VariantChartTheme.of(context),
                title: 'YouTrack vs GitLab по дням',
                subtitle: 'Минуты за день',
                icon: Icons.compare_arrows,
                legend: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChartLegendItem(
                      theme: VariantChartTheme.of(context),
                      color: p.existing,
                      label: 'YT',
                    ),
                    ChartLegendItem(
                      theme: VariantChartTheme.of(context),
                      color: p.link,
                      label: 'GL',
                    ),
                  ],
                ),
              ),
              SizedBox(height: p.isOneC ? 8 : 16),
              SizedBox(height: 200, child: _DualBarChart(days: activeDays)),
            ],
          ),
        ),
        SizedBox(height: p.isOneC ? 8 : 16),
        if (comparison.mismatchedTasks.isNotEmpty) ...[
          Text(
            'Задачи с расхождениями',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: p.isOneC ? 12 : 14,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final task in comparison.mismatchedTasks)
            _TaskComparisonCard(
              task: task,
              youTrackBaseUrl: youTrackBaseUrl,
            ),
          SizedBox(height: p.isOneC ? 8 : 16),
        ],
        Text(
          'По дням',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: p.isOneC ? 12 : 14,
            color: p.textPrimary,
          ),
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
    final p = context.palette;
    return _comparisonPanel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check, color: p.planned, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сверка времени',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: p.isOneC ? 12 : 15,
                        color: p.textPrimary,
                      ),
                    ),
                    if (trackedIsDemo)
                      Text(
                        'Демо-данные YouTrack',
                        style: TextStyle(fontSize: 11, color: p.textMuted),
                      ),
                  ],
                ),
              ),
              _AlignmentBadge(palette: p, score: comparison.overallAlignmentScore),
            ],
          ),
          SizedBox(height: p.isOneC ? 8 : 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(
                palette: p,
                label: 'YouTrack',
                value: TimeFormat.minutes(comparison.totalYoutrackMinutes),
                color: p.existing,
              ),
              _StatChip(
                palette: p,
                label: 'GitLab оценка',
                value: TimeFormat.minutes(comparison.totalGitlabEstimatedMinutes),
                color: p.link,
              ),
              _StatChip(
                palette: p,
                label: 'Согласовано',
                value: '${comparison.alignedDays} дн.',
                color: p.success,
              ),
              _StatChip(
                palette: p,
                label: 'Расхождения',
                value: '${comparison.mismatchDays} дн.',
                color: p.warning,
              ),
              _StatChip(
                palette: p,
                label: 'Код без YT',
                value: '${comparison.gitlabOnlyDays} дн.',
                color: p.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _comparisonPanel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: p.warning),
              const SizedBox(width: 8),
              Text(
                'Выводы',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: p.isOneC ? 12 : 13,
                  color: p.textPrimary,
                ),
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
                  Text('• ', style: TextStyle(color: p.textMuted)),
                  Expanded(
                    child: Text(
                      insight,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      padding: EdgeInsets.all(p.isOneC ? 10 : 14),
      cardColor: p.isOneC ? null : AppColors.surface,
    );
  }
}

class _DualBarChart extends StatelessWidget {
  const _DualBarChart({required this.days});

  final List<DailyTimeComparison> days;

  @override
  Widget build(BuildContext context) {
    final theme = VariantChartTheme.of(context);
    final p = theme.palette;
    if (days.isEmpty) {
      return Center(
        child: Text(
          'Нет данных для сравнения',
          style: TextStyle(color: p.textMuted),
        ),
      );
    }

    final dates = days.map((d) => d.date).toList();
    final maxY = days
        .map((d) => d.youtrackMinutes > d.gitlabEstimatedMinutes
            ? d.youtrackMinutes
            : d.gitlabEstimatedMinutes)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxY + 60).toDouble(),
        gridData: theme.grid(),
        borderData: FlBorderData(show: false),
        titlesData: theme.bottomTitlesForDates(dates),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.tooltipBackground,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[group.x.toInt()];
              final isYt = rodIndex == 0;
              return BarTooltipItem(
                '${DateFormat('d MMM', 'ru').format(day.date)}\n'
                '${isYt ? 'YT' : 'GL'}: '
                '${TimeFormat.minutes(isYt ? day.youtrackMinutes : day.gitlabEstimatedMinutes)}',
                theme.tooltipText,
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: theme.barsSpace,
              barRods: [
                BarChartRodData(
                  toY: days[i].youtrackMinutes.toDouble(),
                  color: p.existing,
                  width: theme.narrowBarWidth,
                  borderRadius: theme.smallBarRadius,
                ),
                BarChartRodData(
                  toY: days[i].gitlabEstimatedMinutes.toDouble(),
                  color: p.link,
                  width: theme.narrowBarWidth,
                  borderRadius: theme.smallBarRadius,
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
    final p = context.palette;
    return _comparisonPanel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, d MMM', 'ru').format(day.date),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: p.isOneC ? 12 : 13,
                    color: p.textPrimary,
                  ),
                ),
              ),
              _StatusChip(palette: p, status: day.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  palette: p,
                  label: 'YouTrack',
                  value: TimeFormat.minutes(day.youtrackMinutes),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  palette: p,
                  label: 'GitLab',
                  value: TimeFormat.minutes(day.gitlabEstimatedMinutes),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  palette: p,
                  label: 'Δ',
                  value: '${day.deltaMinutes >= 0 ? '+' : ''}${day.deltaMinutes}м',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            day.insight,
            style: TextStyle(fontSize: 11, color: p.textSecondary),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
    );
  }
}

class _TaskComparisonCard extends StatelessWidget {
  const _TaskComparisonCard({
    required this.task,
    this.youTrackBaseUrl,
  });

  final TaskTimeComparison task;
  final String? youTrackBaseUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _comparisonPanel(
      context,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                YouTrackIssueLink(
                  issueIdReadable: task.taskId,
                  baseUrl: youTrackBaseUrl,
                  showIcon: true,
                ),
                if (task.issueSummary.isNotEmpty)
                  Text(
                    task.issueSummary,
                    style: TextStyle(fontSize: 11, color: p.textMuted),
                  ),
                const SizedBox(height: 4),
                Text(
                  task.note,
                  style: TextStyle(fontSize: 11, color: p.textPrimary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusChip(palette: p, status: task.status, compact: true),
              const SizedBox(height: 4),
              Text(
                'YT ${TimeFormat.minutes(task.youtrackMinutes)}',
                style: TextStyle(fontSize: 11, color: p.textPrimary),
              ),
              Text(
                'GL ${task.gitlabCommitCount} комм.',
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
            ],
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
    );
  }
}

class _AlignmentBadge extends StatelessWidget {
  const _AlignmentBadge({required this.palette, required this.score});

  final VariantPalette palette;

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? palette.success
        : score >= 40
            ? palette.warning
            : palette.danger;

    if (palette.isOneC) {
      return Text(
        '${score.toStringAsFixed(0)}%',
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      );
    }

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
  const _StatusChip({
    required this.palette,
    required this.status,
    this.compact = false,
  });

  final VariantPalette palette;
  final TimeAlignmentStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TimeAlignmentStatus.aligned => ('OK', palette.success),
      TimeAlignmentStatus.gitlabOnly => ('Код', palette.danger),
      TimeAlignmentStatus.youtrackOnly => ('YT', palette.warning),
      TimeAlignmentStatus.mismatch => ('Δ', palette.warning),
    };

    if (palette.isOneC) {
      return Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );
    }

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
    required this.palette,
    required this.label,
    required this.value,
    required this.color,
  });

  final VariantPalette palette;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (palette.isOneC) {
      return Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, color: palette.textSecondary),
      );
    }

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
  const _MiniStat({
    required this.palette,
    required this.label,
    required this.value,
  });

  final VariantPalette palette;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: palette.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: palette.textMuted),
        ),
      ],
    );
  }
}
