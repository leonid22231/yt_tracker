import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/labeled_slider.dart';
import 'package:youtrack_timer/ui/widgets/plan/plan_data_table_large.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

/// Список задач плана с редактированием через слайдеры.
class PlanListView extends ConsumerStatefulWidget {
  const PlanListView({super.key, required this.plan});

  final PlanBuildResult plan;

  @override
  ConsumerState<PlanListView> createState() => _PlanListViewState();
}

class _PlanListViewState extends ConsumerState<PlanListView> {
  String _query = '';
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _expandFirstIssue();
  }

  @override
  void didUpdateWidget(PlanListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan != widget.plan) {
      _expanded.clear();
      _expandFirstIssue();
    }
  }

  void _expandFirstIssue() {
    if (widget.plan.entries.isEmpty) return;
    _expanded.add(widget.plan.entries.first.issue.id);
  }

  @override
  Widget build(BuildContext context) {
    final isLarge = ref.watch(designVariantProvider).isLarge;
    if (isLarge) {
      return PlanDataTableLarge(plan: widget.plan);
    }

    final home = ref.watch(homeProvider);
    final youTrackBaseUrl = ref.watch(settingsProvider).valueOrNull?.youTrackUrl;
    final grouped = <String, List<PlannedEntry>>{};
    final issueOrder = <String>[];

    for (final e in widget.plan.entries) {
      if (!grouped.containsKey(e.issue.id)) {
        issueOrder.add(e.issue.id);
        grouped[e.issue.id] = [];
      }
      grouped[e.issue.id]!.add(e);
    }

    for (final list in grouped.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }

    final excluded = home.excludedIssueIds;
    final activeIds =
        issueOrder.where((id) => !excluded.contains(id)).toList();

    final q = _query.trim().toLowerCase();
    bool matches(YouTrackIssue issue) {
      if (q.isEmpty) return true;
      return issue.idReadable.toLowerCase().contains(q) ||
          issue.summary.toLowerCase().contains(q);
    }

    final filtered = activeIds.where((id) => matches(grouped[id]!.first.issue)).toList();

    final issueById = {for (final i in widget.plan.issues) i.id: i};
    final excludedIssues = excluded
        .map((id) => issueById[id])
        .whereType<YouTrackIssue>()
        .where(matches)
        .toList();

    final activeMinutes = home.activeEntries.fold<int>(0, (s, e) => s + e.minutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Поиск задачи…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _query = ''),
                    )
                  : null,
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _StatBadge(
                icon: Icons.task_alt,
                label: '${filtered.length} задач',
              ),
              const SizedBox(width: 8),
              _StatBadge(
                icon: Icons.schedule,
                label: TimeFormat.minutes(activeMinutes),
              ),
              if (excludedIssues.isNotEmpty) ...[
                const SizedBox(width: 8),
                _StatBadge(
                  icon: Icons.block,
                  label: '${excludedIssues.length} исключ.',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty && excludedIssues.isEmpty
              ? const Center(
                  child: Text(
                    'Нет задач по запросу',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    ...filtered.map((issueId) {
                      final entries = grouped[issueId]!;
                      final issue = entries.first.issue;
                      final planTotalMin =
                          entries.fold<int>(0, (s, e) => s + e.minutes);
                      final expanded = _expanded.contains(issueId);

                      return _IssuePlanCard(
                        key: ValueKey(issueId),
                        issue: issue,
                        entries: entries,
                        planTotalMinutes: planTotalMin,
                        budgetMinutes: home.issueBudgetMinutes[issueId],
                        expanded: expanded,
                        isRecalculating: home.isLoading,
                        youTrackBaseUrl: youTrackBaseUrl,
                        onToggle: () => setState(() {
                          if (expanded) {
                            _expanded.remove(issueId);
                          } else {
                            _expanded.add(issueId);
                          }
                        }),
                        onBudgetChanged: (hours, {required bool commit}) {
                          final n = ref.read(homeProvider.notifier);
                          if (hours == null) {
                            n.clearIssueBudget(
                              issueId,
                              scheduleRecalc: commit,
                            );
                          } else {
                            n.setIssueBudgetHours(
                              issueId,
                              hours,
                              scheduleRecalc: commit,
                            );
                          }
                        },
                        onEntryMinutesCommit: (date, minutes) {
                          ref.read(homeProvider.notifier).updateEntryMinutes(
                                issueId: issueId,
                                date: date,
                                minutes: minutes,
                              );
                        },
                        onExclude: () {
                          ref
                              .read(homeProvider.notifier)
                              .excludeIssueFromPlan(issueId);
                          setState(() => _expanded.remove(issueId));
                        },
                      );
                    }),
                    if (excludedIssues.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          'Исключены из плана',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      ...excludedIssues.map(
                        (issue) => _ExcludedIssueCard(
                          issue: issue,
                          isRecalculating: home.isLoading,
                          youTrackBaseUrl: youTrackBaseUrl,
                          onRestore: () => ref
                              .read(homeProvider.notifier)
                              .includeIssueInPlan(issue.id),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _IssuePlanCard extends StatefulWidget {
  const _IssuePlanCard({
    super.key,
    required this.issue,
    required this.entries,
    required this.planTotalMinutes,
    required this.budgetMinutes,
    required this.expanded,
    required this.isRecalculating,
    required this.youTrackBaseUrl,
    required this.onToggle,
    required this.onBudgetChanged,
    required this.onEntryMinutesCommit,
    required this.onExclude,
  });

  final YouTrackIssue issue;
  final List<PlannedEntry> entries;
  final int planTotalMinutes;
  final int? budgetMinutes;
  final bool expanded;
  final bool isRecalculating;
  final String? youTrackBaseUrl;
  final VoidCallback onToggle;
  final void Function(double? hours, {required bool commit}) onBudgetChanged;
  final void Function(DateTime date, int minutes) onEntryMinutesCommit;
  final VoidCallback onExclude;

  @override
  State<_IssuePlanCard> createState() => _IssuePlanCardState();
}

class _IssuePlanCardState extends State<_IssuePlanCard> {
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
    final sliderMax = 40.0;
    final dateFmt = DateFormat('EEE d MMM', 'ru');
    final issue = widget.issue;
    final expanded = widget.expanded;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      issue.idReadable.split('-').last,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            YouTrackIssueLink(
                              issueIdReadable: issue.idReadable,
                              baseUrl: widget.youTrackBaseUrl,
                              showIcon: true,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            if (issue.isDaily) ...[
                              const SizedBox(width: 8),
                              const Chip(
                                label: Text('daily'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                            const Spacer(),
                            Text(
                              TimeFormat.minutes(widget.planTotalMinutes),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          issue.summary,
                          maxLines: expanded ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.entries.length} ${_dayLabel(widget.entries.length)} в плане',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LabeledSlider(
                label: 'Лимит на задачу за период',
                subtitle: hasManualBudget
                    ? 'Отпустите ползунок — пересчёт AI'
                    : 'Лимит и пересчёт — после отпускания',
                value: _budgetDisplay.clamp(0, sliderMax),
                min: 0,
                max: sliderMax,
                divisions: (sliderMax * 2).round(),
                valueLabel: _budgetDisplay <= 0
                    ? 'авто'
                    : TimeFormat.hours(_budgetDisplay),
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: OutlinedButton.icon(
                onPressed: widget.isRecalculating ? null : widget.onExclude,
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: const Text('Убрать из плана'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
              ),
            ),
            ...widget.entries.map((e) {
              final dayKey = e.date.millisecondsSinceEpoch;
              final hours = _entryHours(e);
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(height: 4),
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
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _dayLabel(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'день';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'дня';
    }
    return 'дней';
  }
}

class _ExcludedIssueCard extends StatelessWidget {
  const _ExcludedIssueCard({
    required this.issue,
    required this.isRecalculating,
    required this.youTrackBaseUrl,
    required this.onRestore,
  });

  final YouTrackIssue issue;
  final bool isRecalculating;
  final String? youTrackBaseUrl;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.block, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  YouTrackIssueLink(
                    issueIdReadable: issue.idReadable,
                    baseUrl: youTrackBaseUrl,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    issue.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: isRecalculating ? null : onRestore,
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Вернуть'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final PlanSource source;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (source) {
      PlanSource.ai => (
          Icons.auto_awesome,
          'AI',
          AppColors.accent,
        ),
      PlanSource.manual => (
          Icons.tune,
          'ручн.',
          AppColors.warning,
        ),
      PlanSource.even => (
          Icons.balance,
          'равн.',
          AppColors.textMuted,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
