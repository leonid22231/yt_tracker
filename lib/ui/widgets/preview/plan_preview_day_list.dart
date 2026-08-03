import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/plan_preview_entry.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

/// Список дней проверки плана (читаемый layout вместо сжатого календаря).
class PlanPreviewDayList extends StatelessWidget {
  const PlanPreviewDayList({
    super.key,
    required this.days,
    required this.baseUrl,
    this.onIssueTap,
  });

  final List<PlanPreviewDay> days;
  final String baseUrl;
  final void Function(PlanPreviewRow row, PlanPreviewDay day)? onIssueTap;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      final p = context.palette;
      return Center(
        child: Text(
          'Нет рабочих дней в периоде',
          style: TextStyle(color: p.textMuted),
        ),
      );
    }

    final p = context.palette;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(p.isOneC ? 8 : 16, 8, p.isOneC ? 8 : 16, 24),
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _DayCard(
        day: days[i],
        baseUrl: baseUrl,
        onIssueTap: onIssueTap,
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.baseUrl,
    this.onIssueTap,
  });

  final PlanPreviewDay day;
  final String baseUrl;
  final void Function(PlanPreviewRow row, PlanPreviewDay day)? onIssueTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fmt = DateFormat('EEEE, d MMMM', 'ru');
    final meets = day.meetsTarget;

    return Container(
      decoration: p.isOneC
          ? OneCDecorations.flatPanel(p)
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: p.isOneC ? p.panelHeader : AppColors.surfaceHigh,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(
              children: [
                Text(
                  fmt.format(day.day),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const Spacer(),
                _TotalBadge(
                  palette: p,
                  total: day.totalMinutes,
                  target: day.targetMinutes,
                  meets: meets,
                ),
              ],
            ),
          ),
          if (day.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Нет записей',
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
            )
          else
            for (var i = 0; i < day.rows.length; i++)
              _IssueRow(
                palette: p,
                row: day.rows[i],
                baseUrl: baseUrl,
                isLast: i == day.rows.length - 1,
                onTap: onIssueTap == null
                    ? null
                    : () => onIssueTap!(day.rows[i], day),
              ),
        ],
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({
    required this.palette,
    required this.total,
    required this.target,
    required this.meets,
  });

  final VariantPalette palette;

  final int total;
  final int target;
  final bool meets;

  @override
  Widget build(BuildContext context) {
    final color = meets ? palette.success : palette.warning;
    if (palette.isOneC) {
      return Text(
        '${TimeFormat.minutes(total)} / ${TimeFormat.minutes(target)}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${TimeFormat.minutes(total)} / ${TimeFormat.minutes(target)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.palette,
    required this.row,
    required this.baseUrl,
    required this.isLast,
    this.onTap,
  });

  final VariantPalette palette;

  final PlanPreviewRow row;
  final String baseUrl;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSkip = row.plannedStatus == PreviewWriteStatus.willSkip;
    final isNew = row.hasPlanned && !isSkip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(bottom: BorderSide(color: palette.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 108,
                child: YouTrackIssueLink(
                  issueIdReadable: row.issueIdReadable,
                  baseUrl: baseUrl,
                  showIcon: true,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSkip ? palette.textMuted : palette.link,
                    decoration:
                        isSkip ? TextDecoration.lineThrough : TextDecoration.underline,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  row.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSkip ? palette.textMuted : palette.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    TimeFormat.minutes(row.totalMinutes),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  if (row.hasPlanned) ...[
                    const SizedBox(height: 2),
                    _StatusBadge(palette: palette, isNew: isNew, isSkip: isSkip),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.palette,
    required this.isNew,
    required this.isSkip,
  });

  final VariantPalette palette;

  final bool isNew;
  final bool isSkip;

  @override
  Widget build(BuildContext context) {
    final (label, color) = isSkip
        ? ('пропуск', palette.textMuted)
        : isNew
            ? ('запишется', palette.planned)
            : ('в YT', palette.existing);

    if (palette.isOneC) {
      return Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
