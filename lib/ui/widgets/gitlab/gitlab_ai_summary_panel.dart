import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_ai_summary.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/gitlab_provider.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/widgets/gitlab/gitlab_ai_summary_markdown.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Панель запроса AI-сводки GitLab через Cursor Agent.
class GitLabAiSummaryPanel extends ConsumerStatefulWidget {
  const GitLabAiSummaryPanel({
    super.key,
    this.day,
    this.compact = false,
  });

  /// Если задан — сводка за конкретный день, иначе за период.
  final DateTime? day;
  final bool compact;

  @override
  ConsumerState<GitLabAiSummaryPanel> createState() =>
      _GitLabAiSummaryPanelState();
}

class _GitLabAiSummaryPanelState extends ConsumerState<GitLabAiSummaryPanel> {
  final _hintCtrl = TextEditingController();

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  bool _sameScope(DateTime? scopeDay) {
    final day = widget.day;
    if (day == null) return scopeDay == null;
    return scopeDay != null && DateUtils.isSameDay(scopeDay, day);
  }

  bool _matchesSummary(GitLabAiSummary? summary) {
    if (summary == null) return false;
    final day = widget.day;
    if (day == null) return summary.isPeriod;
    return summary.day != null && DateUtils.isSameDay(summary.day!, day);
  }

  @override
  Widget build(BuildContext context) {
    final gitLab = ref.watch(gitLabProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final hasCursor = settings?.hasCursor == true && settings?.useAi == true;
    final hasComparison = gitLab.timeComparison != null;
    final loading =
        gitLab.isAiSummaryLoading && _sameScope(gitLab.aiSummaryLoadingDay);
    final summary =
        _matchesSummary(gitLab.aiSummary) ? gitLab.aiSummary : null;
    final showError = gitLab.aiSummaryError.isNotEmpty &&
        _sameScope(gitLab.aiSummaryErrorDay) &&
        !loading;
    final isDay = widget.day != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.card,
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDay ? 'AI-сводка за день' : 'AI-сводка за период',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      hasCursor
                          ? 'Cursor Agent проанализирует активность'
                          : 'Укажите CURSOR_API_KEY в настройках',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _hintCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Подсказка для AI (необязательно)',
                isDense: true,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: !hasCursor || gitLab.isAiSummaryLoading
                    ? null
                    : () => _generate(withYouTrack: false),
                icon: const Icon(Icons.hub_outlined, size: 16),
                label: Text(isDay ? 'Только GitLab' : 'GitLab'),
              ),
              FilledButton.tonalIcon(
                onPressed: !hasCursor ||
                        gitLab.isAiSummaryLoading ||
                        !hasComparison
                    ? null
                    : () => _generate(withYouTrack: true),
                icon: const Icon(Icons.compare_arrows, size: 16),
                label: Text(isDay ? '+ YouTrack' : 'GitLab + YouTrack'),
              ),
            ],
          ),
          if (!hasComparison)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Для сводки с YouTrack выполните «Сверка с YouTrack»',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          if (loading) ...[
            const SizedBox(height: 16),
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cursor Agent формирует сводку…',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (showError) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                gitLab.aiSummaryError,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
          ],
          if (summary != null && !loading) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  summary.withYouTrack
                      ? Icons.compare_arrows
                      : Icons.hub_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${summary.withYouTrack ? 'GitLab + YouTrack' : 'GitLab'} · '
                  '${DateFormat('HH:mm').format(summary.generatedAt)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Очистить',
                  onPressed: () =>
                      ref.read(gitLabProvider.notifier).clearAiSummary(),
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: GitLabAiSummaryMarkdown(data: summary.text),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generate({required bool withYouTrack}) async {
    final hint = _hintCtrl.text.trim();
    final notifier = ref.read(gitLabProvider.notifier);
    if (widget.day != null) {
      await notifier.generateDayAiSummary(
        widget.day!,
        withYouTrack: withYouTrack,
        userHint: hint.isEmpty ? null : hint,
      );
    } else {
      await notifier.generatePeriodAiSummary(
        withYouTrack: withYouTrack,
        userHint: hint.isEmpty ? null : hint,
      );
    }
  }
}
