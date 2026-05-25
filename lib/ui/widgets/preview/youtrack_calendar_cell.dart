import 'package:flutter/material.dart';
import 'package:youtrack_timer/models/plan_preview_entry.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';

/// Цвета календаря в стиле YouTrack (таймшит).
abstract final class YtCalendarColors {
  static const cellBg = Color(0xFF2A2D34);
  static const cellBorder = Color(0xFF3A3F4B);
  static const rowBg = Color(0xFF32363F);
  static const rowBorder = Color(0xFF434956);
  static const link = Color(0xFF6B9FFF);
  static const badgeOk = Color(0xFF2D6A4F);
  static const badgeWarn = Color(0xFFB45309);
  static const badgeOkText = Color(0xFF86EFAC);
  static const badgeWarnText = Color(0xFFFCD34D);
  static const newPlanned = Color(0xFF7C6CF0);
  static const skipped = Color(0xFF64748B);
}

/// Ячейка одного дня в сетке проверки.
class YoutrackCalendarCell extends StatelessWidget {
  const YoutrackCalendarCell({
    super.key,
    required this.day,
    required this.onIssueTap,
  });

  final PlanPreviewDay day;
  final void Function(PlanPreviewRow row) onIssueTap;

  @override
  Widget build(BuildContext context) {
    final total = day.totalMinutes;
    final target = day.targetMinutes;
    final meets = day.meetsTarget;

    return Container(
      decoration: BoxDecoration(
        color: YtCalendarColors.cellBg,
        border: Border.all(color: YtCalendarColors.cellBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
            child: Row(
              children: [
                Text(
                  '${day.day.day}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                _DayTotalBadge(
                  totalMinutes: total,
                  targetMinutes: target,
                  meetsTarget: meets,
                ),
              ],
            ),
          ),
          Expanded(
            child: day.rows.isEmpty
                ? const Center(
                    child: Text(
                      '—',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                    itemCount: day.rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) => _IssueRow(
                      row: day.rows[i],
                      onTap: () => onIssueTap(day.rows[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayTotalBadge extends StatelessWidget {
  const _DayTotalBadge({
    required this.totalMinutes,
    required this.targetMinutes,
    required this.meetsTarget,
  });

  final int totalMinutes;
  final int targetMinutes;
  final bool meetsTarget;

  @override
  Widget build(BuildContext context) {
    final bg = meetsTarget ? YtCalendarColors.badgeOk : YtCalendarColors.badgeWarn;
    final fg =
        meetsTarget ? YtCalendarColors.badgeOkText : YtCalendarColors.badgeWarnText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${TimeFormat.minutes(totalMinutes)} из ${TimeFormat.minutes(targetMinutes)}',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.row, required this.onTap});

  final PlanPreviewRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayMinutes = row.totalMinutes;
    final isNew = row.hasPlanned &&
        row.plannedStatus != PreviewWriteStatus.willSkip;
    final isSkip = row.plannedStatus == PreviewWriteStatus.willSkip;

    return Material(
      color: YtCalendarColors.rowBg,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: YtCalendarColors.link.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isNew
                  ? YtCalendarColors.newPlanned.withValues(alpha: 0.5)
                  : isSkip
                      ? YtCalendarColors.skipped.withValues(alpha: 0.4)
                      : YtCalendarColors.rowBorder,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.issueIdReadable,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSkip ? YtCalendarColors.skipped : YtCalendarColors.link,
                    decoration:
                        isSkip ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                TimeFormat.minutes(displayMinutes),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSkip
                      ? YtCalendarColors.skipped
                      : AppColors.textSecondary,
                ),
              ),
              if (row.hasPlanned) ...[
                const SizedBox(width: 4),
                Icon(
                  isSkip ? Icons.block : Icons.add_circle_outline,
                  size: 12,
                  color: isSkip
                      ? YtCalendarColors.skipped
                      : YtCalendarColors.newPlanned,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Пустая ячейка в сетке (выходной / паддинг).
class YoutrackCalendarEmptyCell extends StatelessWidget {
  const YoutrackCalendarEmptyCell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF23262D),
        border: Border.all(color: YtCalendarColors.cellBorder),
      ),
    );
  }
}
