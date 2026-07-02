import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/tracked_time_record.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// Мок затреканного времени YouTrack для демо-сверки с GitLab.
class YouTrackTrackedMockData {
  static YouTrackTrackedTimeData build({
    required GitLabActivityData gitLabData,
  }) {
    final entries = <TrackedWorkEntry>[];

    for (final day in gitLabData.metrics.dailySummaries) {
      if (day.commitCount == 0 && day.branchesTouched == 0) continue;

      final trackedMinutes = (day.estimatedMinutes * 0.75).round();
      if (trackedMinutes <= 0) continue;

      final tasks = day.taskIds;
      if (tasks.isEmpty) {
        entries.add(
          TrackedWorkEntry(
            taskId: 'KIOSK-999',
            issueSummary: 'Daily sync / meetings',
            date: day.date,
            minutes: trackedMinutes,
          ),
        );
        continue;
      }

      var remaining = trackedMinutes;
      for (var i = 0; i < tasks.length; i++) {
        final taskId = tasks[i];
        final isLast = i == tasks.length - 1;
        final share = isLast
            ? remaining
            : (trackedMinutes / tasks.length).round().clamp(15, remaining);
        remaining -= share;
        if (share <= 0) continue;

        entries.add(
          TrackedWorkEntry(
            taskId: taskId,
            issueSummary: 'Demo: $taskId',
            date: day.date,
            minutes: share,
          ),
        );
      }

      if (day.date.day % 4 == 0) {
        entries.add(
          TrackedWorkEntry(
            taskId: 'KIOSK-050',
            issueSummary: 'Team meetup',
            date: day.date,
            minutes: 30,
          ),
        );
      }
    }

    final summaries = gitLabData.metrics.dailySummaries;
    final start = summaries.first.date;
    final end = summaries.last.date;

    return YouTrackTrackedTimeData(
      entries: entries,
      dailySummaries: _aggregate(entries, start, end),
      fetchedAt: DateTime.now(),
      isDemo: true,
    );
  }

  static List<DailyTrackedSummary> _aggregate(
    List<TrackedWorkEntry> entries,
    DateTime start,
    DateTime end,
  ) {
    final buckets = <DateTime, DailyTrackedSummary>{};
    var current = DateUtils.dateOnly(start);
    final last = DateUtils.dateOnly(end);
    while (!current.isAfter(last)) {
      buckets[current] = DailyTrackedSummary(date: current);
      current = current.add(const Duration(days: 1));
    }

    for (final e in entries) {
      final day = DateUtils.dateOnly(e.date);
      if (!buckets.containsKey(day)) continue;
      final prev = buckets[day]!;
      final tasks = [...prev.taskIds];
      if (!tasks.contains(e.taskId)) tasks.add(e.taskId);
      buckets[day] = DailyTrackedSummary(
        date: day,
        totalMinutes: prev.totalMinutes + e.minutes,
        taskIds: tasks,
        entries: [...prev.entries, e],
      );
    }

    return buckets.values.toList();
  }
}
