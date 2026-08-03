import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/day_timeline.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

/// Табель по дням в стиле 1С.
class DayTimelineTimesheet extends ConsumerWidget {
  const DayTimelineTimesheet({
    super.key,
    required this.timelines,
  });

  final List<DayTimeline> timelines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(designVariantProvider).palette;
    final youTrackBaseUrl =
        ref.watch(settingsProvider).valueOrNull?.youTrackUrl;

    if (timelines.isEmpty) {
      return Center(
        child: Text(
          'Нет рабочих дней в периоде',
          style: TextStyle(color: p.textMuted),
        ),
      );
    }

    final days = timelines.map((t) => t.day).toList();
    final dayFmt = DateFormat('E\ndd', 'ru');

    final matrix = <String, Map<DateTime, int>>{};
    final summaries = <String, String>{};

    for (final t in timelines) {
      for (final line in t.lines) {
        matrix.putIfAbsent(line.issueIdReadable, () => {});
        matrix[line.issueIdReadable]![t.day] =
            (matrix[line.issueIdReadable]![t.day] ?? 0) + line.minutes;
        summaries.putIfAbsent(line.issueIdReadable, () => line.summary);
      }
    }

    final issueIds = matrix.keys.toList()..sort();
    final dayTotals = <DateTime, int>{for (final d in days) d: 0};
    final rowTotals = <String, int>{};

    for (final id in issueIds) {
      var rowSum = 0;
      for (final d in days) {
        final m = matrix[id]![d] ?? 0;
        rowSum += m;
        dayTotals[d] = dayTotals[d]! + m;
      }
      rowTotals[id] = rowSum;
    }

    final grandTotal = dayTotals.values.fold(0, (s, v) => s + v);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.workArea,
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: p.toolbar,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(
              children: [
                Text(
                  'Табель по дням',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                const Spacer(),
                _LegendItem(palette: p, color: p.existing, label: 'В YouTrack'),
                const SizedBox(width: 10),
                _LegendItem(palette: p, color: p.planned, label: 'План'),
                const SizedBox(width: 12),
                Text(
                  'Итого: ${TimeFormat.minutes(grandTotal)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 24,
                  dataRowMaxHeight: 28,
                  horizontalMargin: 6,
                  columnSpacing: 0,
                  headingRowColor: WidgetStateProperty.all(p.tableHeader),
                  border: TableBorder.all(color: p.border, width: 1),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Задача',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    ...days.map(
                      (d) => DataColumn(
                        label: Text(
                          dayFmt.format(d),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Итого',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    for (var i = 0; i < issueIds.length; i++)
                      _buildRow(
                        p,
                        issueIds[i],
                        summaries[issueIds[i]]!,
                        days,
                        matrix[issueIds[i]]!,
                        rowTotals[issueIds[i]]!,
                        youTrackBaseUrl,
                        zebra: i.isOdd,
                      ),
                    _buildTotalRow(p, days, dayTotals, grandTotal),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(
    VariantPalette p,
    String issueId,
    String summary,
    List<DateTime> days,
    Map<DateTime, int> cells,
    int rowTotal,
    String? youTrackBaseUrl, {
    required bool zebra,
  }) {
    return DataRow(
      color: WidgetStateProperty.all(zebra ? p.tableZebra : p.tableRow),
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              YouTrackIssueLink(
                issueIdReadable: issueId,
                baseUrl: youTrackBaseUrl,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.link,
                  decoration: TextDecoration.underline,
                ),
              ),
              Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: p.textMuted),
              ),
            ],
          ),
        ),
        ...days.map((d) {
          final m = cells[d] ?? 0;
          return DataCell(
            Center(
              child: Text(
                m > 0 ? TimeFormat.minutes(m) : '—',
                style: TextStyle(
                  fontSize: 11,
                  color: m > 0 ? p.textPrimary : p.textMuted,
                ),
              ),
            ),
          );
        }),
        DataCell(
          Text(
            TimeFormat.minutes(rowTotal),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildTotalRow(
    VariantPalette p,
    List<DateTime> days,
    Map<DateTime, int> dayTotals,
    int grandTotal,
  ) {
    return DataRow(
      color: WidgetStateProperty.all(p.tableHeader),
      cells: [
        DataCell(
          Text(
            'Итого по дням',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
        ),
        ...days.map(
          (d) => DataCell(
            Center(
              child: Text(
                TimeFormat.minutes(dayTotals[d]!),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            TimeFormat.minutes(grandTotal),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: p.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.palette,
    required this.color,
    required this.label,
  });

  final VariantPalette palette;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: palette.border),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: palette.textMuted),
        ),
      ],
    );
  }
}
