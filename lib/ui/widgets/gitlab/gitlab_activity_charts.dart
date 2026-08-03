import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/models/gitlab/productivity_metric.dart';
import 'package:youtrack_timer/ui/theme/variant_chart_theme.dart';

/// Открывает детали дня только по клику, не при наведении (desktop hover).
bool _isChartTap(FlTouchEvent event) => event is FlTapUpEvent;

/// Графики GitLab-аналитики.
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
    final theme = VariantChartTheme.of(context);
    final active = metrics.dailySummaries
        .where((d) => d.commitCount > 0 || d.branchesTouched > 0)
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartCard(
          theme: theme,
          title: 'Активность по дням',
          subtitle: 'Коммиты',
          icon: Icons.stacked_bar_chart_rounded,
          height: theme.palette.isOneC ? 200 : 220,
          child: _ComboChart(
            theme: theme,
            summaries: active,
            onDayTap: onDayTap,
          ),
        ),
        SizedBox(height: theme.spacingAfterPanel),
        _ChartCard(
          theme: theme,
          title: 'Продуктивность',
          subtitle: 'Индекс 0–100',
          icon: Icons.show_chart_rounded,
          height: theme.palette.isOneC ? 180 : 200,
          child: _ProductivityChart(
            theme: theme,
            summaries: active,
            onDayTap: onDayTap,
          ),
        ),
        SizedBox(height: theme.spacingAfterPanel),
        _ChartCard(
          theme: theme,
          title: 'Изменения кода',
          subtitle: 'Добавления и удаления',
          icon: Icons.code_rounded,
          height: theme.palette.isOneC ? 180 : 200,
          legend: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChartLegendItem(
                theme: theme,
                color: theme.additionsBar,
                label: '+',
              ),
              ChartLegendItem(
                theme: theme,
                color: theme.deletionsBar,
                label: '−',
              ),
            ],
          ),
          child: _ChangesChart(
            theme: theme,
            summaries: active,
            onDayTap: onDayTap,
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.legend,
    this.height = 180,
  });

  final VariantChartTheme theme;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? legend;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: theme.panelDecoration(),
      padding: theme.panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartPanelHeader(
            theme: theme,
            title: title,
            subtitle: subtitle,
            icon: icon,
            legend: legend,
          ),
          SizedBox(height: theme.palette.isOneC ? 8 : 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

class _ComboChart extends StatelessWidget {
  const _ComboChart({
    required this.theme,
    required this.summaries,
    this.onDayTap,
  });

  final VariantChartTheme theme;
  final List<DailyActivitySummary> summaries;
  final void Function(DateTime day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final maxCommits =
        summaries.map((s) => s.commitCount).fold<int>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxCommits + 1).toDouble(),
        gridData: theme.grid(),
        borderData: FlBorderData(show: false),
        titlesData: theme.bottomTitlesForSummaries(summaries),
        barTouchData: BarTouchData(
          enabled: onDayTap != null,
          touchCallback: (event, response) {
            if (!_isChartTap(event)) return;
            if (response?.spot == null) return;
            final idx = response!.spot!.touchedBarGroupIndex;
            if (idx >= 0 && idx < summaries.length) {
              onDayTap?.call(summaries[idx].date);
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.tooltipBackground,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final s = summaries[group.x.toInt()];
              return BarTooltipItem(
                '${DateFormat('d MMM', 'ru').format(s.date)}\n'
                '${s.commitCount} комм. · ${s.estimatedMinutes} м',
                theme.tooltipText,
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
                  width: theme.barWidth,
                  borderRadius: theme.barRadius,
                  color: theme.palette.isOneC ? theme.commitsBar : null,
                  gradient: theme.palette.isOneC
                      ? null
                      : const LinearGradient(
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
    required this.theme,
    required this.summaries,
    this.onDayTap,
  });

  final VariantChartTheme theme;
  final List<DailyActivitySummary> summaries;
  final void Function(DateTime day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < summaries.length; i++)
        FlSpot(i.toDouble(), summaries[i].productivityScore),
    ];
    final p = theme.palette;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: theme.grid(),
        borderData: FlBorderData(show: false),
        titlesData: theme.bottomTitlesForSummaries(summaries),
        lineTouchData: LineTouchData(
          enabled: onDayTap != null,
          touchCallback: (event, response) {
            if (!_isChartTap(event)) return;
            final touched = response?.lineBarSpots;
            if (touched == null || touched.isEmpty) return;
            final idx = touched.first.spotIndex;
            if (idx >= 0 && idx < summaries.length) {
              onDayTap?.call(summaries[idx].date);
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.tooltipBackground,
            getTooltipItems: (spots) => spots.map((s) {
              final day = summaries[s.spotIndex];
              return LineTooltipItem(
                '${DateFormat('d MMM', 'ru').format(day.date)}\n'
                '${day.productivityScore.toStringAsFixed(0)} pts',
                theme.tooltipText,
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: !p.isOneC,
            curveSmoothness: 0.35,
            color: theme.productivityLine,
            barWidth: p.isOneC ? 2 : 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: p.isOneC ? 3 : 4,
                color: theme.productivityLine,
                strokeWidth: p.isOneC ? 1 : 2,
                strokeColor: p.isOneC ? p.formBackground : p.panel,
              ),
            ),
            belowBarData: BarAreaData(
              show: !p.isOneC,
              gradient: p.isOneC
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.productivityLine.withValues(alpha: 0.25),
                        theme.productivityLine.withValues(alpha: 0.02),
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
    required this.theme,
    required this.summaries,
    this.onDayTap,
  });

  final VariantChartTheme theme;
  final List<DailyActivitySummary> summaries;
  final void Function(DateTime day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final maxY = summaries
        .map((s) => s.totalAdditions > s.totalDeletions
            ? s.totalAdditions
            : s.totalDeletions)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxY + 50).toDouble(),
        gridData: theme.grid(),
        borderData: FlBorderData(show: false),
        titlesData: theme.bottomTitlesForSummaries(summaries),
        barTouchData: BarTouchData(
          enabled: onDayTap != null,
          touchCallback: (event, response) {
            if (!_isChartTap(event)) return;
            if (response?.spot == null) return;
            final idx = response!.spot!.touchedBarGroupIndex;
            if (idx >= 0 && idx < summaries.length) {
              onDayTap?.call(summaries[idx].date);
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.tooltipBackground,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final s = summaries[group.x.toInt()];
              return BarTooltipItem(
                '${DateFormat('d MMM', 'ru').format(s.date)}\n'
                '+${s.totalAdditions} / −${s.totalDeletions}',
                theme.tooltipText,
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < summaries.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: theme.barsSpace,
              barRods: [
                BarChartRodData(
                  toY: summaries[i].totalAdditions.toDouble(),
                  width: theme.narrowBarWidth,
                  borderRadius: theme.smallBarRadius,
                  color: theme.additionsBar,
                ),
                BarChartRodData(
                  toY: summaries[i].totalDeletions.toDouble(),
                  width: theme.narrowBarWidth,
                  borderRadius: theme.smallBarRadius,
                  color: theme.deletionsBar,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
