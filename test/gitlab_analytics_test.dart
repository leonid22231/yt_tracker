import 'package:test/test.dart';
import 'package:youtrack_timer/models/gitlab/branch_record.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_analytics_service.dart';
import 'package:youtrack_timer/services/gitlab/task_id_extractor.dart';

void main() {
  group('TaskIdExtractor', () {
    test('извлекает один task ID из сообщения коммита', () {
      expect(
        TaskIdExtractor.extractFromText('KIOSK-100: fix login'),
        ['KIOSK-100'],
      );
    });

    test('извлекает несколько task ID из одного коммита', () {
      expect(
        TaskIdExtractor.extractFromText('KIOSK-100 KIOSK-102 KIOSK-201'),
        ['KIOSK-100', 'KIOSK-102', 'KIOSK-201'],
      );
    });

    test('извлекает task ID из названия ветки', () {
      expect(
        TaskIdExtractor.extractFromText('feature/KIOSK-305-payment'),
        ['KIOSK-305'],
      );
    });

    test('не дублирует task ID', () {
      expect(
        TaskIdExtractor.extractFromTexts([
          'KIOSK-100 fix',
          'merge KIOSK-100',
        ]),
        ['KIOSK-100'],
      );
    });

    test('игнорирует строки без паттерна', () {
      expect(TaskIdExtractor.extractFromText('fix typo'), isEmpty);
    });
  });

  group('GitLabAnalyticsService', () {
    final service = GitLabAnalyticsService();
    final day = DateTime(2025, 6, 10);

    test('группирует коммиты и ветки по дням', () {
      final commits = [
        CommitRecord(
          id: 'a',
          shortId: 'aaa',
          message: 'KIOSK-100 work',
          committedAt: day.add(const Duration(hours: 10)),
          projectId: 1,
          projectName: 'p',
          additions: 50,
          deletions: 10,
          taskIds: const ['KIOSK-100'],
        ),
        CommitRecord(
          id: 'b',
          shortId: 'bbb',
          message: 'KIOSK-102 KIOSK-201',
          committedAt: day.add(const Duration(hours: 14)),
          projectId: 1,
          projectName: 'p',
          additions: 30,
          deletions: 5,
          taskIds: const ['KIOSK-102', 'KIOSK-201'],
        ),
      ];
      final branches = [
        BranchRecord(
          name: 'feature/KIOSK-100',
          projectId: 1,
          projectName: 'p',
          lastActivityAt: day.add(const Duration(hours: 9)),
          isNew: true,
          taskIds: const ['KIOSK-100'],
        ),
      ];

      final metrics = service.buildMetrics(
        commits: commits,
        branches: branches,
        rangeStart: day,
        rangeEnd: day,
      );

      expect(metrics.totalCommits, 2);
      expect(metrics.totalTasks, 3);
      final summary = metrics.dailySummaries.first;
      expect(summary.commitCount, 2);
      expect(summary.branchesTouched, 1);
      expect(summary.branchesCreated, 1);
      expect(summary.taskIds, containsAll(['KIOSK-100', 'KIOSK-102', 'KIOSK-201']));
      expect(summary.estimatedMinutes, greaterThan(0));
      expect(summary.productivityScore, greaterThan(0));
    });

    test('ветка без коммита с task ID всё равно учитывает задачу', () {
      final branches = [
        BranchRecord(
          name: 'feature/KIOSK-512-only-branch',
          projectId: 1,
          projectName: 'p',
          lastActivityAt: day,
          taskIds: const ['KIOSK-512'],
        ),
      ];

      final metrics = service.buildMetrics(
        commits: const [],
        branches: branches,
        rangeStart: day,
        rangeEnd: day,
      );

      expect(metrics.dailySummaries.first.taskIds, ['KIOSK-512']);
      expect(metrics.dailySummaries.first.branchesTouched, 1);
    });
  });
}
