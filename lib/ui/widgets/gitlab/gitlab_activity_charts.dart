import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/models/gitlab/productivity_metric.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';

/// Графики GitLab-аналитики с улучшенным дизайном.
class GitLabActivityCharts extends StatelessWidget {
  const GitLabActivityCharts({
    super.key,
    required this.metrics,
    this.onDayTap,
    this.selectedDay,
  });

  final ProductivityMetric metrics;
  final void Function(DateTime day)? onDayTap;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final active = metrics.dailySummaries
        .where((d) => d.commitCount > 0 || d.branchesTouched > 0)
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartCard(
          title: 'Активность по дням',
          subtitle: 'Коммиты и оценка времени',
          icon: Icons.stacked_bar_chart_rounded,
          height: 220,
          child: _ComboChart(
            summaries: active,
            onDayTap: onDayTap,
            selectedDay: selectedDay,
          ),
        ),
        const SizedBox(height: 14),
        _ChartCard(
          title: 'Продуктивность',
          subtitle: 'Индекс 0–100',
          icon: Icons.show_chart_rounded,
          height: 200,
          child: _ProductivityChart(
            summaries: active,
            onDayTap: onDayTap,
            selectedDay: selectedDay,
          ),
        ),
        const SizedBox(height: 14),
        _ChartCard(
          title: 'Изменения кода',
          subtitle: 'Добавления и удаления',
          icon: Icons.code_rounded,
          height: 200,
          child: _ChangesChart(
            summaries: active,
            onDayTap: onDayTap,
            selectedDay: selectedDay,
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.height = 180,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

FlTitlesData _bottomTitles(List<DailyActivitySummary> summaries) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: const AxisTitles(
      sideTitles: SideTitles(showTitles: true, reservedSize: 32),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        getTitlesWidget: (value, meta) {
          final i = value.toInt();
          if (i < 0 || i >= summaries.length) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              DateFormat('dd').format(summaries[i].date),
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
            ),
          );
        },
      ),
    ),
  );
}

FlGridData get _grid => FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: AppColors.border.withValues(alpha: 0.6), strokeWidth: 1),
    );

class _ComboChart extends StatelessWidget {
  const _ComboChart({
    required this.summaries,
    this.onDayTap,
    this.selectedDay,
  });

  final List<DailyActivitySummary> summaries;
  final void Function(DateTime day)? onDayTap;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final maxCommits =
        summaries.map((s) => s.commitCount).fold<int>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxCommits + 1).toDouble(),
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _bottomTitles(summaries),
        barTouchData: BarTouchData(
          enabled: onDayTap != null,
          touchCallback: (event, response) {
            final idx = response?.spot?.touchedBarGroupIndex;
            if (idx != null && idx >= 0 && idx < summaries.length) {
              onDayTap?.call(summaries[idx].date);
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceHigh,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final s = summaries[group.x.toInt()];
              return BarTooltipItem(
                '${DateFormat('d MMM', 'ru').format(s.date)}\n'
                '${s.commitCount} комм. · ${s.estimatedMinutes} м',
                const TextStyle(color: AppColors.textPrimary, fontSize: 11),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < summaries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: summaries[i].commitCount.toDouble(),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x995B4FD6), Color(0xFF7C6CF0)],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProductivityChart extends StatelessWidget {
  const _ProductivityChart({
    required this.summaries,
    this.onDayTap,
    this.selectedDay,
  });

  final List<DailyActivitySummary> summaries;
  final void Function(DateTime day)? onDayTap;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < summaries.length; i++)
        FlSpot(i.toDouble(), summaries[i].productivityScore),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _bottomTitles(summaries),
        lineTouchData: LineTouchData(
          enabled: onDayTap != null,
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) return;
            final idx = spots.first.spotIndex;
            if (idx >= 0 && idx < summaries.length) {
              onDayTap?.call(summaries[idx].date);
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceHigh,
            getTooltipItems: (spots) => spots.map((s) {
              final day = summaries[s.spotIndex];
              return LineTooltipItem(
                '${DateFormat('d MMM', 'ru').format(day.date)}\n'
                '${day.productivityScore.toStringAsFixed(0)} pts',
                const TextStyle(color: AppColors.textPrimary, fontSize: 11),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.warning,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: AppColors.warning,
                strokeWidth: 2,
                strokeColor: AppColors.card,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.warning.withValues(alpha: 0.25),
                  AppColors.warning.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangesChart extends StatelessWidget {
  const _ChangesChart({
    required this.summaries,
    this.onDayTap,
    this.selectedDay,
  });

  final List<DailyActivitySummary> summaries;
  final void Function(DateTime day)? onDayTap;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final maxY = summaries
        .map((s) => s.totalAdditions > s.totalDeletions ? s.totalAdditions : s.totalDeletions)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxY + 50).toDouble(),
        gridData: _grid,
        borderData: FlBorderData(show: false),
        titlesData: _bottomTitles(summaries),
        barTouchData: BarTouchData(
          enabled: onDayTap != null,
          touchCallback: (event, response) {
            final idx = response?.spot?.touchedBarGroupIndex;
            if (idx != null && idx >= 0 && idx < summaries.length) {
              onDayTap?.call(summaries[idx].date);
            }
          },
        ),
        barGroups: [
          for (var i = 0; i < summaries.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: summaries[i].totalAdditions.toDouble(),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color: AppColors.success,
                ),
                BarChartRodData(
                  toY: summaries[i].totalDeletions.toDouble(),
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color: AppColors.danger.withValues(alpha: 0.85),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
