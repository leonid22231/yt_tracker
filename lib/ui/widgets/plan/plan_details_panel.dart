import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/business/business_toolbar.dart';
import 'package:youtrack_timer/ui/widgets/plan/plan_issue_editor.dart';
import 'package:youtrack_timer/ui/widgets/plan/plan_utils.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

/// Правая панель реквизитов (1С desktop large).
class PlanDetailsPanel extends ConsumerWidget {
  const PlanDetailsPanel({super.key, required this.plan});

  final PlanBuildResult plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final p = ref.watch(designVariantProvider).palette;
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

    return ColoredBox(
      color: p.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: p.panelHeader,
              border: Border(
                bottom: BorderSide(color: p.border),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.description_outlined, size: 14, color: p.textPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group != null
                        ? 'Реквизиты · ${group.issue.idReadable}'
                        : 'Реквизиты',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  icon: Icon(Icons.close, size: 14, color: p.textPrimary),
                  onPressed: () =>
                      ref.read(shellLayoutProvider.notifier).toggleDetailsPanel(),
                ),
              ],
            ),
          ),
          Expanded(
            child: group == null
                ? _EmptyDetails(palette: p)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BusinessFormSection(
                          palette: p,
                          title: 'Основное',
                          dense: true,
                          child: Column(
                            children: [
                              BusinessFormField(
                                palette: p,
                                label: 'Задача',
                                valueWidget: YouTrackIssueLink(
                                  issueIdReadable: group.issue.idReadable,
                                  baseUrl: youTrackBaseUrl,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: p.link,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              BusinessFormField(
                                palette: p,
                                label: 'Наименование',
                                value: group.issue.summary,
                              ),
                              BusinessFormField(
                                palette: p,
                                label: 'Проект',
                                value: group.projectName,
                              ),
                              BusinessFormField(
                                palette: p,
                                label: 'Итого',
                                value: TimeFormat.minutes(group.totalMinutes),
                              ),
                              BusinessFormField(
                                palette: p,
                                label: 'Рабочих дней',
                                value: dayCountLabel(group.entries.length),
                              ),
                              if (group.issue.estimatePresentation != null)
                                BusinessFormField(
                                  palette: p,
                                  label: 'Оценка AI',
                                  value: group.issue.estimatePresentation,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        BusinessFormSection(
                          palette: p,
                          title: 'Распределение',
                          dense: true,
                          child: PlanIssueEditor(
                            issue: group.issue,
                            entries: group.entries,
                            planTotalMinutes: group.totalMinutes,
                            budgetMinutes:
                                home.issueBudgetMinutes[group.issueId],
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

class _EmptyDetails extends StatelessWidget {
  const _EmptyDetails({required this.palette});

  final VariantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Выберите строку в списке',
        style: TextStyle(fontSize: 11, color: palette.textMuted),
      ),
    );
  }
}
