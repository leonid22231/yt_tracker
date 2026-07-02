import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/labeled_slider.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

/// Редактор задачи: лимит + слайдеры по дням.
class PlanIssueEditor extends StatefulWidget {
  const PlanIssueEditor({
    super.key,
    required this.issue,
    required this.entries,
    required this.planTotalMinutes,
    required this.budgetMinutes,
    required this.isRecalculating,
    required this.onBudgetChanged,
    required this.onEntryMinutesCommit,
    required this.onExclude,
    this.compact = false,
    this.youTrackBaseUrl,
  });

  final YouTrackIssue issue;
  final List<PlannedEntry> entries;
  final int planTotalMinutes;
  final int? budgetMinutes;
  final bool isRecalculating;
  final void Function(double? hours, {required bool commit}) onBudgetChanged;
  final void Function(DateTime date, int minutes) onEntryMinutesCommit;
  final VoidCallback onExclude;
  final bool compact;
  final String? youTrackBaseUrl;

  @override
  State<PlanIssueEditor> createState() => _PlanIssueEditorState();
}

class _PlanIssueEditorState extends State<PlanIssueEditor> {
  double? _localBudgetHours;
  bool _draggingBudget = false;
  final _localEntryHours = <int, double>{};
  final _draggingEntryDays = <int>{};

  double get _budgetDisplay {
    if (_draggingBudget && _localBudgetHours != null) {
      return _localBudgetHours!;
    }
    final mins = widget.budgetMinutes ?? widget.planTotalMinutes;
    return mins / 60.0;
  }

  double _entryHours(PlannedEntry e) {
    final key = e.date.millisecondsSinceEpoch;
    if (_draggingEntryDays.contains(key) && _localEntryHours.containsKey(key)) {
      return _localEntryHours[key]!;
    }
    return e.minutes / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    final hasManualBudget = widget.budgetMinutes != null;
    const sliderMax = 40.0;
    final dateFmt = DateFormat('EEE d MMM', 'ru');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          YouTrackIssueLink(
            issueIdReadable: widget.issue.idReadable,
            baseUrl: widget.youTrackBaseUrl,
            showIcon: true,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            widget.issue.summary,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],
        LabeledSlider(
          label: 'Лимит на задачу за период',
          subtitle: hasManualBudget
              ? 'Отпустите ползунок — пересчёт AI'
              : 'Лимит и пересчёт — после отпускания',
          value: _budgetDisplay.clamp(0, sliderMax),
          min: 0,
          max: sliderMax,
          divisions: (sliderMax * 2).round(),
          valueLabel:
              _budgetDisplay <= 0 ? 'авто' : TimeFormat.hours(_budgetDisplay),
          enabled: !widget.isRecalculating,
          onChanged: (v) {
            setState(() {
              _draggingBudget = true;
              _localBudgetHours = v;
            });
            if (v <= 0) {
              widget.onBudgetChanged(null, commit: false);
            } else {
              widget.onBudgetChanged(v, commit: false);
            }
          },
          onChangeEnd: (v) {
            setState(() {
              _draggingBudget = false;
              _localBudgetHours = null;
            });
            if (v <= 0) {
              widget.onBudgetChanged(null, commit: true);
            } else {
              widget.onBudgetChanged(v, commit: true);
            }
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.isRecalculating ? null : widget.onExclude,
          icon: const Icon(Icons.remove_circle_outline, size: 16),
          label: const Text('Убрать из плана'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'По дням',
          style: TextStyle(
            fontSize: widget.compact ? 10 : 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.entries.map((e) {
          final dayKey = e.date.millisecondsSinceEpoch;
          final hours = _entryHours(e);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _SourceBadge(source: e.source),
                      const SizedBox(width: 8),
                      Text(
                        dateFmt.format(e.date),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        TimeFormat.minutes(
                          TimeFormat.sliderHoursToMinutes(hours),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: hours.clamp(0, 8),
                    min: 0,
                    max: 8,
                    divisions: 32,
                    onChanged: (v) {
                      setState(() {
                        _draggingEntryDays.add(dayKey);
                        _localEntryHours[dayKey] = v;
                      });
                    },
                    onChangeEnd: (v) {
                      setState(() {
                        _draggingEntryDays.remove(dayKey);
                        _localEntryHours.remove(dayKey);
                      });
                      widget.onEntryMinutesCommit(
                        e.date,
                        TimeFormat.sliderHoursToMinutes(v),
                      );
                    },
                  ),
                  if (e.reasoning != null && e.reasoning!.isNotEmpty)
                    Text(
                      e.reasoning!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final PlanSource source;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (source) {
      PlanSource.ai => (Icons.auto_awesome, 'AI', AppColors.accent),
      PlanSource.manual => (Icons.tune, 'ручн.', AppColors.warning),
      PlanSource.even => (Icons.balance, 'равн.', AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
