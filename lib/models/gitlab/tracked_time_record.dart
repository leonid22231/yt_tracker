/// Одна запись списанного времени в YouTrack.
class TrackedWorkEntry {
  const TrackedWorkEntry({
    required this.taskId,
    required this.issueSummary,
    required this.date,
    required this.minutes,
    this.workItemId = '',
  });

  final String taskId;
  final String issueSummary;
  final DateTime date;
  final int minutes;
  final String workItemId;
}

/// Сводка затреканного времени за день.
class DailyTrackedSummary {
  const DailyTrackedSummary({
    required this.date,
    this.totalMinutes = 0,
    this.taskIds = const [],
    this.entries = const [],
  });

  final DateTime date;
  final int totalMinutes;
  final List<String> taskIds;
  final List<TrackedWorkEntry> entries;
}

/// Загруженные данные о списанном времени из YouTrack.
class YouTrackTrackedTimeData {
  const YouTrackTrackedTimeData({
    required this.entries,
    required this.dailySummaries,
    required this.fetchedAt,
    this.isDemo = false,
  });

  final List<TrackedWorkEntry> entries;
  final List<DailyTrackedSummary> dailySummaries;
  final DateTime fetchedAt;
  final bool isDemo;

  int get totalMinutes =>
      entries.fold<int>(0, (sum, e) => sum + e.minutes);

  bool get isEmpty => entries.isEmpty;
}
