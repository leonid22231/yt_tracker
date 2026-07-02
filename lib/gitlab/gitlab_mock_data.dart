import 'package:youtrack_timer/models/gitlab/branch_record.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_user_info.dart';
import 'package:youtrack_timer/models/gitlab/merge_request_record.dart';
import 'package:youtrack_timer/gitlab/gitlab_links.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_analytics_service.dart';
import 'package:youtrack_timer/services/gitlab/task_id_extractor.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Демо-данные для проверки UI без реального GitLab token.
class GitLabMockData {
  static GitLabActivityData build({
    DateTime? endDate,
    int days = 14,
  }) {
    final end = DateUtils.dateOnly(endDate ?? DateTime.now());
    final start = end.subtract(Duration(days: days - 1));
    final user = const GitLabUserInfo(
      id: 0,
      username: 'demo_user',
      name: 'Demo Developer',
      email: 'demo@example.com',
    );

    final commits = <CommitRecord>[];
    final branches = <BranchRecord>[];
    final mergeRequests = <MergeRequestRecord>[];
    final taskPool = [
      'KIOSK-100',
      'KIOSK-102',
      'KIOSK-201',
      'KIOSK-305',
      'KIOSK-410',
      'KIOSK-512',
    ];

    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      if (day.weekday > DateTime.friday) continue;

      final intensity = (i % 5) + 1;
      final dayTasks = taskPool.sublist(0, (intensity % taskPool.length) + 1);

      for (var c = 0; c < intensity; c++) {
        final tasks = c == 0 && dayTasks.length > 1
            ? '${dayTasks[0]} ${dayTasks[1]}'
            : dayTasks[c % dayTasks.length];
        commits.add(
          CommitRecord(
            id: 'demo-${day.millisecondsSinceEpoch}-$c',
            shortId: 'demo${c.toString().padLeft(4, '0')}',
            message: '$tasks: implement feature part ${c + 1}',
            committedAt: day.add(Duration(hours: 10 + c * 2)),
            projectId: 1,
            projectName: 'kiosk/mobile-app',
            branchName: 'feature/$tasks',
            additions: 40 + c * 25 + i * 3,
            deletions: 10 + c * 5,
            taskIds: TaskIdExtractor.extractFromTexts([
              tasks,
              'feature/$tasks',
            ]),
            mergeRequestIid: c == 0 && i % 2 == 0 ? 100 + i : null,
            mergeRequestTitle: c == 0 && i % 2 == 0
                ? '$tasks: demo merge request'
                : '',
            webUrl: GitLabLinks.commitUrl(
              'https://gitlab.com',
              'kiosk/mobile-app',
              'demo${c.toString().padLeft(4, '0')}',
            ),
          ),
        );
      }

      if (i % 2 == 0) {
        mergeRequests.add(
          MergeRequestRecord(
            projectId: 1,
            projectPath: 'kiosk/mobile-app',
            iid: 100 + i,
            title: '${dayTasks.first}: demo merge request',
            sourceBranch: 'feature/${dayTasks.first}',
            targetBranch: 'develop',
            state: i % 4 == 0 ? 'merged' : 'opened',
            createdAt: day.add(const Duration(hours: 8)),
            updatedAt: day.add(const Duration(hours: 16)),
            mergedAt: i % 4 == 0 ? day.add(const Duration(hours: 17)) : null,
            additions: 120 + i * 10,
            deletions: 45 + i * 3,
            taskIds: TaskIdExtractor.extractFromTexts([dayTasks.first]),
            webUrl: GitLabLinks.mergeRequestUrl(
              'https://gitlab.com',
              'kiosk/mobile-app',
              100 + i,
            ),
          ),
        );
      }

      branches.add(
        BranchRecord(
          name: 'feature/${dayTasks.first}-day-$i',
          projectId: 1,
          projectName: 'kiosk/mobile-app',
          lastActivityAt: day.add(const Duration(hours: 9)),
          isNew: i % 3 == 0,
          taskIds: TaskIdExtractor.extractFromTexts([dayTasks.first]),
        ),
      );
    }

    final enrichedCommits = commits
        .map(
          (c) => c.copyWith(
            taskIds: c.taskIds.isNotEmpty
                ? c.taskIds
                : TaskIdExtractor.extractFromTexts([
                    c.message,
                    c.branchName,
                  ]),
          ),
        )
        .toList();

    final enrichedBranches = branches
        .map(
          (b) => b.copyWith(
            taskIds: b.taskIds.isNotEmpty
                ? b.taskIds
                : TaskIdExtractor.extractFromTexts([b.name]),
          ),
        )
        .toList();

    final metrics = GitLabAnalyticsService().buildMetrics(
      commits: enrichedCommits,
      branches: enrichedBranches,
      mergeRequests: mergeRequests,
      rangeStart: start,
      rangeEnd: end,
    );

    return GitLabActivityData(
      user: user,
      commits: enrichedCommits,
      branches: enrichedBranches,
      mergeRequests: mergeRequests,
      metrics: metrics,
      fetchedAt: DateTime.now(),
      projectCount: 3,
      isDemo: true,
      gitLabBaseUrl: 'https://gitlab.com',
    );
  }
}
