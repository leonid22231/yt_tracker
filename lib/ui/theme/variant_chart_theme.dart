import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';

/// Стили графиков fl_chart для планшета и 1С.
class VariantChartTheme {
  const VariantChartTheme(this.palette);

  final VariantPalette palette;

  static VariantChartTheme of(BuildContext context) =>
      VariantChartTheme(context.palette);

  double get barWidth => palette.isOneC ? 12 : 14;
  double get narrowBarWidth => palette.isOneC ? 7 : 8;
  double get barsSpace => palette.isOneC ? 3 : 4;

  BorderRadius get barRadius => palette.isOneC
      ? BorderRadius.zero
      : const BorderRadius.vertical(top: Radius.circular(6));

  BorderRadius get smallBarRadius => palette.isOneC
      ? BorderRadius.zero
      : const BorderRadius.vertical(top: Radius.circular(4));

  Color get tooltipBackground =>
      palette.isOneC ? palette.inputBackground : AppColors.surfaceHigh;

  TextStyle get tooltipText => TextStyle(
        color: palette.textPrimary,
        fontSize: palette.isOneC ? 10 : 11,
      );

  TextStyle get axisLabel => TextStyle(
        fontSize: palette.isOneC ? 9 : 10,
        color: palette.textMuted,
      );

  TextStyle get titleStyle => TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: palette.isOneC ? 12 : 14,
        color: palette.textPrimary,
      );

  TextStyle get subtitleStyle => TextStyle(
        fontSize: palette.isOneC ? 10 : 11,
        color: palette.textMuted,
      );

  Color get commitsBar => palette.isOneC ? palette.link : const Color(0xFF7C6CF0);
  Color get productivityLine => palette.warning;
  Color get additionsBar => palette.success;
  Color get deletionsBar => palette.danger;

  FlGridData grid() => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: palette.isOneC
              ? palette.border.withValues(alpha: 0.45)
              : AppColors.border.withValues(alpha: 0.6),
          strokeWidth: 1,
        ),
      );

  FlTitlesData bottomTitlesForSummaries(List<DailyActivitySummary> summaries) =>
      FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: palette.isOneC ? 28 : 32,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: axisLabel,
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: palette.isOneC ? 26 : 30,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= summaries.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  DateFormat('dd').format(summaries[i].date),
                  style: axisLabel,
                ),
              );
            },
          ),
        ),
      );

  FlTitlesData bottomTitlesForDates(List<DateTime> dates) => FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: palette.isOneC ? 28 : 36,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: axisLabel,
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: palette.isOneC ? 24 : 28,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= dates.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  DateFormat('dd.MM').format(dates[i]),
                  style: axisLabel,
                ),
              );
            },
          ),
        ),
      );

  BoxDecoration panelDecoration() => palette.isOneC
      ? OneCDecorations.flatPanel(palette)
      : BoxDecoration(
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
        );

  EdgeInsets get panelPadding =>
      palette.isOneC
          ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
          : const EdgeInsets.fromLTRB(16, 16, 16, 12);

  double get spacingAfterPanel => palette.isOneC ? 8 : 14;
}

/// Заголовок блока графика.
class ChartPanelHeader extends StatelessWidget {
  const ChartPanelHeader({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.legend,
  });

  final VariantChartTheme theme;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? legend;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.isOneC)
          Icon(icon, size: 16, color: p.link)
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
        SizedBox(width: p.isOneC ? 8 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.titleStyle),
              Text(subtitle, style: theme.subtitleStyle),
            ],
          ),
        ),
        if (legend != null) legend!,
      ],
    );
  }
}

/// Маленькая легенда «цвет — подпись».
class ChartLegendItem extends StatelessWidget {
  const ChartLegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.theme,
  });

  final Color color;
  final String label;
  final VariantChartTheme theme;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: p.isOneC ? 10 : 12,
            height: p.isOneC ? 10 : 12,
            decoration: BoxDecoration(
              color: color,
              border: p.isOneC ? Border.all(color: p.border) : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: theme.subtitleStyle),
        ],
      ),
    );
  }
}
