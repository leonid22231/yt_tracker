import 'package:test/test.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_user_info.dart';
import 'package:youtrack_timer/models/gitlab/productivity_metric.dart';
import 'package:youtrack_timer/models/gitlab/tracked_time_record.dart';
import 'package:youtrack_timer/models/gitlab/youtrack_gitlab_comparison.dart';
import 'package:youtrack_timer/services/gitlab/youtrack_gitlab_analyzer.dart';

void main() {
  group('YouTrackGitLabAnalyzer', () {
    const analyzer = YouTrackGitLabAnalyzer();
    final day = DateTime(2025, 6, 10);

    GitLabActivityData gitLabData({
      required List<CommitRecord> commits,
      List<DailyActivitySummary>? summaries,
    }) =>
        GitLabActivityData(
          user: const GitLabUserInfo(
            id: 1,
            username: 'dev',
            name: 'Dev',
            email: 'dev@test.com',
          ),
          commits: commits,
          branches: const [],
          metrics: ProductivityMetric(
            dailySummaries: summaries ??
                [
                  DailyActivitySummary(
                    date: day,
                    commitCount: commits.length,
                    estimatedMinutes: 120,
                    taskIds: const ['KIOSK-100'],
                  ),
                ],
          ),
          fetchedAt: DateTime.now(),
        );

    test('находит день только с GitLab-активностью', () {
      final comparison = analyzer.analyze(
        gitLab: gitLabData(
          commits: [
            CommitRecord(
              id: '1',
              shortId: 'abc',
              message: 'KIOSK-100 fix',
              committedAt: day,
              projectId: 1,
              projectName: 'p',
              taskIds: const ['KIOSK-100'],
            ),
          ],
        ),
        youTrack: YouTrackTrackedTimeData(
          entries: const [],
          dailySummaries: const [],
          fetchedAt: DateTime.now(),
        ),
        rangeStart: day,
        rangeEnd: day,
      );

      expect(comparison.gitlabOnlyDays, 1);
      expect(
        comparison.taskComparisons.first.status,
        TimeAlignmentStatus.gitlabOnly,
      );
    });

    test('согласует день с близким временем', () {
      final comparison = analyzer.analyze(
        gitLab: gitLabData(
          commits: [
            CommitRecord(
              id: '1',
              shortId: 'abc',
              message: 'KIOSK-100',
              committedAt: day,
              projectId: 1,
              projectName: 'p',
              additions: 100,
              taskIds: const ['KIOSK-100'],
            ),
          ],
          summaries: [
            DailyActivitySummary(
              date: day,
              commitCount: 1,
              estimatedMinutes: 100,
              taskIds: const ['KIOSK-100'],
            ),
          ],
        ),
        youTrack: YouTrackTrackedTimeData(
          entries: [
            TrackedWorkEntry(
              taskId: 'KIOSK-100',
              issueSummary: 'Fix',
              date: day,
              minutes: 90,
            ),
          ],
          dailySummaries: [
            DailyTrackedSummary(
              date: day,
              totalMinutes: 90,
              taskIds: const ['KIOSK-100'],
            ),
          ],
          fetchedAt: DateTime.now(),
        ),
        rangeStart: day,
        rangeEnd: day,
      );

      expect(comparison.alignedDays, 1);
      expect(
        comparison.taskComparisons.first.status,
        TimeAlignmentStatus.aligned,
      );
    });

    test('находит списание без GitLab-коммитов', () {
      final comparison = analyzer.analyze(
        gitLab: gitLabData(
          commits: const [],
          summaries: [
            DailyActivitySummary(date: day),
          ],
        ),
        youTrack: YouTrackTrackedTimeData(
          entries: [
            TrackedWorkEntry(
              taskId: 'KIOSK-050',
              issueSummary: 'Meetup',
              date: day,
              minutes: 60,
            ),
          ],
          dailySummaries: [
            DailyTrackedSummary(
              date: day,
              totalMinutes: 60,
              taskIds: const ['KIOSK-050'],
            ),
          ],
          fetchedAt: DateTime.now(),
        ),
        rangeStart: day,
        rangeEnd: day,
      );

      expect(comparison.youtrackOnlyDays, 1);
    });
  });
}
