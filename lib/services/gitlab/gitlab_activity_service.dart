import 'package:youtrack_timer/gitlab/gitlab_client.dart';
import 'package:youtrack_timer/gitlab/gitlab_mock_data.dart';
import 'package:youtrack_timer/models/loading_progress.dart';
import 'package:youtrack_timer/models/gitlab/branch_record.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_user_info.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_analytics_service.dart';
import 'package:youtrack_timer/services/gitlab/task_id_extractor.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Загрузка и обогащение GitLab-активности.
class GitLabActivityService {
  GitLabActivityService({
    GitLabAnalyticsService? analytics,
  }) : _analytics = analytics ?? GitLabAnalyticsService();

  final GitLabAnalyticsService _analytics;

  Future<GitLabActivityData> loadDemo({
    DateTime? endDate,
    int days = 21,
    LoadingProgressTracker? progress,
  }) async {
    progress?.start('Генерация демо-данных');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    progress?.fraction(0.5, detail: 'коммиты и ветки');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    progress?.advance('Расчёт метрик');
    final data = GitLabMockData.build(endDate: endDate, days: days);
    return data;
  }

  Future<GitLabActivityData> loadFromApi({
    required GitLabClient client,
    required DateTime startDate,
    required DateTime endDate,
    LoadingProgressTracker? progress,
  }) async {
    progress?.start('Профиль GitLab');
    final user = await client.getCurrentUser();
    final since = DateUtils.dateOnly(startDate);
    final until = DateUtils.dateOnly(endDate);

    progress?.advance('Список проектов');
    final projects = await client.listMemberProjects();

    final mergeRequests = await client.fetchUserMergeRequests(
      user: user,
      since: since,
      until: until,
    );

    progress?.advance('Загрузка коммитов');
    final commits = await client.fetchUserCommits(
      user: user,
      since: since,
      until: until,
      onProgress: progress != null
          ? (detail, fraction) => progress.fraction(
                fraction,
                detail: detail,
              )
          : null,
    );

    progress?.advance('Активность веток');
    final branches = await client.fetchBranchActivity(
      user: user,
      since: since,
      until: until,
    );

    progress?.advance('Расчёт аналитики');
    final enriched = _enrichWithTaskIds(commits, branches);
    final metrics = _analytics.buildMetrics(
      commits: enriched.$1,
      branches: enriched.$2,
      mergeRequests: mergeRequests,
      rangeStart: since,
      rangeEnd: until,
    );

    return GitLabActivityData(
      user: user,
      commits: enriched.$1,
      branches: enriched.$2,
      mergeRequests: mergeRequests,
      metrics: metrics,
      fetchedAt: DateTime.now(),
      projectCount: projects.length,
      gitLabBaseUrl: client.baseUrl,
    );
  }

  (List<CommitRecord>, List<BranchRecord>) _enrichWithTaskIds(
    List<CommitRecord> commits,
    List<BranchRecord> branches,
  ) {
    final enrichedCommits = commits
        .map(
          (c) => c.copyWith(
            taskIds: TaskIdExtractor.extractFromTexts([
              c.message,
              c.branchName,
            ]),
          ),
        )
        .toList();

    final enrichedBranches = branches
        .map(
          (b) => b.copyWith(
            taskIds: TaskIdExtractor.extractFromTexts([b.name]),
          ),
        )
        .toList();

    return (enrichedCommits, enrichedBranches);
  }

  Future<GitLabUserInfo> validateConnection(GitLabClient client) =>
      client.getCurrentUser();
}
