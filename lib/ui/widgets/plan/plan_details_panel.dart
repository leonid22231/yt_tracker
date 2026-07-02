import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/plan/plan_issue_editor.dart';
import 'package:youtrack_timer/ui/widgets/plan/plan_utils.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

/// Правая панель детализации задачи (large-режим).
class PlanDetailsPanel extends ConsumerWidget {
  const PlanDetailsPanel({super.key, required this.plan});

  final PlanBuildResult plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final selectedId = ref.watch(shellLayoutProvider).selectedIssueId;
    final youTrackBaseUrl = ref.watch(settingsProvider).valueOrNull?.youTrackUrl;
    final groups = groupPlanEntries(plan);
    PlanIssueGroup? group;
    if (selectedId != null) {
      for (final g in groups) {
        if (g.issueId == selectedId) {
          group = g;
          break;
        }
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            issueId: group?.issue.idReadable,
            youTrackBaseUrl: youTrackBaseUrl,
            onClose: () =>
                ref.read(shellLayoutProvider.notifier).toggleDetailsPanel(),
          ),
          Expanded(
            child: group == null
                ? const _EmptyDetails()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          group.issue.summary,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _MetaChip(
                              label: TimeFormat.minutes(group.totalMinutes),
                              icon: Icons.schedule,
                            ),
                            const SizedBox(width: 6),
                            _MetaChip(
                              label: dayCountLabel(group.entries.length),
                              icon: Icons.calendar_today_outlined,
                            ),
                            if (group.issue.estimatePresentation != null) ...[
                              const SizedBox(width: 6),
                              _MetaChip(
                                label: 'AI ${group.issue.estimatePresentation}',
                                icon: Icons.auto_awesome,
                              ),
                            ],
                          ],
                        ),
                        const Divider(height: 24),
                        PlanIssueEditor(
                          issue: group.issue,
                          entries: group.entries,
                          planTotalMinutes: group.totalMinutes,
                          budgetMinutes: home.issueBudgetMinutes[group.issueId],
                          isRecalculating: home.isLoading,
                          compact: true,
                          youTrackBaseUrl: youTrackBaseUrl,
                          onBudgetChanged: (hours, {required commit}) {
                            final n = ref.read(homeProvider.notifier);
                            if (hours == null) {
                              n.clearIssueBudget(
                                group!.issueId,
                                scheduleRecalc: commit,
                              );
                            } else {
                              n.setIssueBudgetHours(
                                group!.issueId,
                                hours,
                                scheduleRecalc: commit,
                              );
                            }
                          },
                          onEntryMinutesCommit: (date, minutes) {
                            ref.read(homeProvider.notifier).updateEntryMinutes(
                                  issueId: group!.issueId,
                                  date: date,
                                  minutes: minutes,
                                );
                          },
                          onExclude: () {
                            ref
                                .read(homeProvider.notifier)
                                .excludeIssueFromPlan(group!.issueId);
                            ref
                                .read(shellLayoutProvider.notifier)
                                .selectIssue(null);
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.issueId,
    required this.youTrackBaseUrl,
    required this.onClose,
  });

  final String? issueId;
  final String? youTrackBaseUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (issueId != null)
            YouTrackIssueLink(
              issueIdReadable: issueId!,
              baseUrl: youTrackBaseUrl,
              showIcon: true,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              'ДЕТАЛИ',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Закрыть панель',
            icon: const Icon(Icons.close, size: 16),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _EmptyDetails extends StatelessWidget {
  const _EmptyDetails();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 32,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'Выберите задачу в таблице',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
