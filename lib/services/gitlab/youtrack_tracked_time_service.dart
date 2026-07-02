import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/gitlab/youtrack_tracked_mock_data.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/tracked_time_record.dart';
import 'package:youtrack_timer/services/ai_time_estimator.dart';
import 'package:youtrack_timer/utils/date_utils.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

/// Загрузка затреканного времени из YouTrack за период.
class YouTrackTrackedTimeService {
  Future<YouTrackTrackedTimeData> loadDemo({
    required GitLabActivityData gitLabData,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return YouTrackTrackedMockData.build(gitLabData: gitLabData);
  }

  Future<YouTrackTrackedTimeData> loadFromApi({
    required YouTrackClient client,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = DateUtils.dateOnly(startDate);
    final end = DateUtils.dateOnly(endDate);

    final assigned = await client.fetchAssignedIssues(
      startDate: start,
      endDate: end,
    );
    final assignedIds = assigned.map((i) => i.id).toSet();
    final extra = await client.fetchMyWorkTimelineIssues(
      startDate: start,
      endDate: end,
      excludeIssueIds: assignedIds,
    );

    final issues = [...assigned, ...extra];
    final contexts = await buildIssueContexts(
      client: client,
      issues: issues,
      start: start,
      end: end,
    );

    final entries = <TrackedWorkEntry>[];
    for (final ctx in contexts) {
      for (final w in ctx.existingWorkItems) {
        if (w.minutes <= 0) continue;
        entries.add(
          TrackedWorkEntry(
            taskId: ctx.issue.idReadable,
            issueSummary: ctx.issue.summary,
            date: DateUtils.dateOnly(w.date),
            minutes: w.minutes,
            workItemId: w.id,
          ),
        );
      }
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return YouTrackTrackedTimeData(
      entries: entries,
      dailySummaries: _aggregateByDay(entries, start, end),
      fetchedAt: DateTime.now(),
    );
  }

  YouTrackClient createClient({
    required String baseUrl,
    required String token,
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      YouTrackClient(
        AppConfig(
          baseUrl: baseUrl,
          token: token,
          startDate: startDate,
          endDate: endDate,
        ),
      );

  List<DailyTrackedSummary> _aggregateByDay(
    List<TrackedWorkEntry> entries,
    DateTime start,
    DateTime end,
  ) {
    final buckets = <DateTime, DailyTrackedSummary>{};
    var current = start;
    while (!current.isAfter(end)) {
      buckets[current] = DailyTrackedSummary(date: current);
      current = current.add(const Duration(days: 1));
    }

    for (final entry in entries) {
      final day = DateUtils.dateOnly(entry.date);
      if (!buckets.containsKey(day)) continue;
      final prev = buckets[day]!;
      final taskIds = [...prev.taskIds];
      if (!taskIds.contains(entry.taskId)) taskIds.add(entry.taskId);
      buckets[day] = DailyTrackedSummary(
        date: day,
        totalMinutes: prev.totalMinutes + entry.minutes,
        taskIds: taskIds,
        entries: [...prev.entries, entry],
      );
    }

    return buckets.values.toList();
  }
}
