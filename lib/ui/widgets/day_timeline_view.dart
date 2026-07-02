import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/day_timeline.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

/// Посуточная шкала: уже в YouTrack + новый план.
class DayTimelineView extends ConsumerWidget {
  const DayTimelineView({
    super.key,
    required this.timelines,
  });

  final List<DayTimeline> timelines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final youTrackBaseUrl = ref.watch(settingsProvider).valueOrNull?.youTrackUrl;
    if (timelines.isEmpty) {
      return const Center(
        child: Text(
          'Нет рабочих дней в периоде',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_view_week_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Загрузка по дням',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Spacer(),
                _LegendDot(color: AppColors.existing, label: 'В YouTrack'),
                const SizedBox(width: 12),
                _LegendDot(color: AppColors.planned, label: 'План'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: timelines.length,
              itemBuilder: (_, i) => _DayCard(
                timeline: timelines[i],
                youTrackBaseUrl: youTrackBaseUrl,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _DayCard extends StatefulWidget {
  const _DayCard({
    required this.timeline,
    this.youTrackBaseUrl,
  });

  final DayTimeline timeline;
  final String? youTrackBaseUrl;

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.timeline;
    final fmt = DateFormat('EEEE, d MMMM', 'ru');
    final ok = t.totalMinutes == t.targetMinutes;
    final over = t.totalMinutes > t.targetMinutes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: over
                    ? AppColors.warning.withValues(alpha: 0.4)
                    : ok
                        ? AppColors.success.withValues(alpha: 0.25)
                        : AppColors.border,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fmt.format(t.day),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${TimeFormat.minutes(t.totalMinutes)} / ${TimeFormat.minutes(t.targetMinutes)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: over
                            ? AppColors.warning
                            : ok
                                ? AppColors.success
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _DayStackedBar(timeline: t),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  if (t.lines.isEmpty)
                    const Text(
                      'Нет записей',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    )
                  else
                    ...t.lines.map(
                      (line) => _TaskLineRow(
                        line: line,
                        youTrackBaseUrl: widget.youTrackBaseUrl,
                      ),
                    ),
                  if (t.remainingMinutes > 0 && t.lines.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Свободно: ${TimeFormat.minutes(t.remainingMinutes)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayStackedBar extends StatelessWidget {
  const _DayStackedBar({required this.timeline});

  final DayTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final t = timeline;
    if (t.targetMinutes <= 0) return const SizedBox(height: 8);

    final existingFlex = t.existingMinutes > 0 ? t.existingMinutes : 0;
    final plannedFlex = t.plannedMinutes > 0 ? t.plannedMinutes : 0;
    final gapFlex = t.totalMinutes < t.targetMinutes
        ? t.targetMinutes - t.totalMinutes
        : 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: t.totalMinutes == 0
            ? Container(color: AppColors.border)
            : Row(
                children: [
                  if (existingFlex > 0)
                    Expanded(
                      flex: existingFlex,
                      child: const ColoredBox(color: AppColors.existing),
                    ),
                  if (plannedFlex > 0)
                    Expanded(
                      flex: plannedFlex,
                      child: const ColoredBox(color: AppColors.planned),
                    ),
                  if (gapFlex > 0)
                    Expanded(
                      flex: gapFlex,
                      child: Container(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TaskLineRow extends StatelessWidget {
  const _TaskLineRow({
    required this.line,
    this.youTrackBaseUrl,
  });

  final DayTaskLine line;
  final String? youTrackBaseUrl;

  @override
  Widget build(BuildContext context) {
    final isExisting = line.kind == DayLineKind.existing;
    final color = isExisting ? AppColors.existing : AppColors.planned;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 36,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${isExisting ? 'Уже в YT' : 'План'} · ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    YouTrackIssueLink(
                      issueIdReadable: line.issueIdReadable,
                      baseUrl: youTrackBaseUrl,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Text(
                  line.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            TimeFormat.minutes(line.minutes),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
