import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/plan_preview_entry.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
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
      return const Center(
        child: Text(
          'Нет рабочих дней в периоде',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
    final fmt = DateFormat('EEEE, d MMMM', 'ru');
    final meets = day.meetsTarget;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  fmt.format(day.day),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _TotalBadge(
                  total: day.totalMinutes,
                  target: day.targetMinutes,
                  meets: meets,
                ),
              ],
            ),
          ),
          if (day.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Нет записей',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            for (var i = 0; i < day.rows.length; i++)
              _IssueRow(
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
    required this.total,
    required this.target,
    required this.meets,
  });

  final int total;
  final int target;
  final bool meets;

  @override
  Widget build(BuildContext context) {
    final color = meets ? AppColors.success : AppColors.warning;
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
    required this.row,
    required this.baseUrl,
    required this.isLast,
    this.onTap,
  });

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
                : const Border(bottom: BorderSide(color: AppColors.border)),
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
                    color: isSkip ? AppColors.textMuted : AppColors.primary,
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
                    color: isSkip
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
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
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (row.hasPlanned) ...[
                    const SizedBox(height: 2),
                    _StatusBadge(isNew: isNew, isSkip: isSkip),
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
  const _StatusBadge({required this.isNew, required this.isSkip});

  final bool isNew;
  final bool isSkip;

  @override
  Widget build(BuildContext context) {
    final (label, color) = isSkip
        ? ('пропуск', AppColors.textMuted)
        : isNew
            ? ('запишется', AppColors.accent)
            : ('в YT', AppColors.existing);

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
