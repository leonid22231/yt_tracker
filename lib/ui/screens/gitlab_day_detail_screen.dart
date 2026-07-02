import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/gitlab/gitlab_links.dart';
import 'package:youtrack_timer/models/gitlab/branch_record.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/merge_request_record.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_day_analyzer.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/gitlab/gitlab_ai_summary_panel.dart';
import 'package:youtrack_timer/utils/open_external_url.dart';

/// Детальная аналитика GitLab за выбранный день.
class GitLabDayDetailScreen extends StatelessWidget {
  const GitLabDayDetailScreen({
    super.key,
    required this.activity,
    required this.date,
  });

  final GitLabActivityData activity;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final detail = const GitLabDayAnalyzer().build(
      activity: activity,
      date: date,
    );
    final baseUrl = activity.gitLabBaseUrl;
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'ru').format(detail.date);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
              title: Text(
                DateFormat('d MMMM', 'ru').format(detail.date),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.35),
                      AppColors.background,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (!detail.isActive)
                          const Text(
                            'Нет активности в GitLab',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                GitLabAiSummaryPanel(day: date, compact: true),
                const SizedBox(height: 16),
                if (detail.isActive) ...[
                  _HeroStats(detail: detail),
                  const SizedBox(height: 16),
                  if (detail.projects.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.folder_outlined,
                      title: 'Проекты',
                      count: detail.projects.length,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in detail.projects)
                          _LinkChip(
                            label: p,
                            onTap: baseUrl.isNotEmpty
                                ? () => openExternalUrl(
                                      GitLabLinks.projectUrl(baseUrl, p),
                                    )
                                : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (detail.summary.taskIds.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.task_alt_outlined,
                      title: 'Задачи',
                      count: detail.summary.taskIds.length,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final id in detail.summary.taskIds)
                          _TaskChip(taskId: id),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (detail.mergeRequests.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.merge_type_rounded,
                      title: 'Merge requests',
                      count: detail.mergeRequests.length,
                    ),
                    const SizedBox(height: 8),
                    for (final mr in detail.mergeRequests)
                      _MergeRequestTile(mr: mr, baseUrl: baseUrl),
                    const SizedBox(height: 20),
                  ],
                  if (detail.commits.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.call_merge_rounded,
                      title: 'Коммиты',
                      count: detail.commits.length,
                    ),
                    const SizedBox(height: 8),
                    for (final c in detail.commits)
                      _CommitTile(commit: c, baseUrl: baseUrl),
                    const SizedBox(height: 20),
                  ],
                  if (detail.branches.isNotEmpty) ...[
                    _SectionTitle(
                      icon: Icons.account_tree_outlined,
                      title: 'Ветки',
                      count: detail.branches.length,
                    ),
                    const SizedBox(height: 8),
                    for (final b in detail.branches)
                      _BranchTile(branch: b, baseUrl: baseUrl),
                  ],
                ] else
                  _EmptyDayCard(date: detail.date),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStats extends StatelessWidget {
  const _HeroStats({required this.detail});

  final GitLabDayDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [AppColors.card, AppColors.card.withValues(alpha: 0.7)],
        ),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _ScoreRing(score: s.productivityScore),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatPill(icon: Icons.call_merge, label: '${s.commitCount} комм.'),
                _StatPill(icon: Icons.merge_type, label: '${s.mergeRequestCount} MR'),
                _StatPill(
                  icon: Icons.account_tree_outlined,
                  label: '${s.branchesTouched} веток',
                ),
                _StatPill(
                  icon: Icons.task_alt_outlined,
                  label: '${s.activeTaskCount} задач',
                ),
                _StatPill(
                  icon: Icons.schedule,
                  label: TimeFormat.minutes(s.estimatedMinutes),
                ),
                _StatPill(
                  icon: Icons.code,
                  label: '+${s.totalAdditions}/−${s.totalDeletions}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 60
        ? AppColors.success
        : score >= 30
            ? AppColors.warning
            : AppColors.textMuted;
    final t = (score / 100).clamp(0.0, 1.0);

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: t,
              strokeWidth: 8,
              backgroundColor: AppColors.surfaceHigh,
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const Text(
                'score',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MergeRequestTile extends StatelessWidget {
  const _MergeRequestTile({required this.mr, required this.baseUrl});

  final MergeRequestRecord mr;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final url = mr.webUrl.isNotEmpty
        ? mr.webUrl
        : (baseUrl.isNotEmpty
            ? GitLabLinks.mergeRequestUrl(baseUrl, mr.projectPath, mr.iid)
            : '');

    return _ActivityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(mr.reference,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(mr.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${mr.sourceBranch} → ${mr.targetBranch}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('+${mr.additions}/−${mr.deletions}',
                  style: const TextStyle(fontSize: 11)),
              const Spacer(),
              if (url.isNotEmpty)
                TextButton.icon(
                  onPressed: () => openExternalUrl(url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Открыть MR'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommitTile extends StatelessWidget {
  const _CommitTile({required this.commit, required this.baseUrl});

  final CommitRecord commit;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final url = commit.webUrl.isNotEmpty
        ? commit.webUrl
        : (baseUrl.isNotEmpty && commit.id.isNotEmpty
            ? GitLabLinks.commitUrl(baseUrl, commit.projectName, commit.id)
            : '');

    return _ActivityCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(commit.shortId,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              const Spacer(),
              if (url.isNotEmpty)
                IconButton(
                  onPressed: () => openExternalUrl(url),
                  icon: const Icon(Icons.open_in_new, size: 18),
                ),
            ],
          ),
          Text(commit.message.split('\n').first,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(commit.projectName,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          if (commit.mergeRequestIid != null)
            Text('MR !${commit.mergeRequestIid}',
                style: const TextStyle(fontSize: 11, color: AppColors.accent)),
          Row(
            children: [
              Text('+${commit.additions}/−${commit.deletions}',
                  style: const TextStyle(fontSize: 11)),
              const Spacer(),
              if (commit.id.isNotEmpty)
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: commit.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SHA скопирован')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({required this.branch, required this.baseUrl});

  final BranchRecord branch;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final url = baseUrl.isNotEmpty
        ? GitLabLinks.branchUrl(baseUrl, branch.projectName, branch.name)
        : '';

    return _ActivityCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(branch.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(branch.projectName,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (url.isNotEmpty)
            IconButton(
              onPressed: () => openExternalUrl(url),
              icon: const Icon(Icons.open_in_new, size: 18),
            ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
      avatar: const Icon(Icons.folder_outlined, size: 16),
    );
  }
}

class _TaskChip extends StatelessWidget {
  const _TaskChip({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        taskId,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Text(
        'В ${DateFormat('d MMMM', 'ru').format(date)} нет активности',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
