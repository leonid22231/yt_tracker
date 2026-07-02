import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';

/// Сгруппированные записи плана по задачам.
class PlanIssueGroup {
  PlanIssueGroup({
    required this.issueId,
    required this.issue,
    required this.entries,
  });

  final String issueId;
  final YouTrackIssue issue;
  final List<PlannedEntry> entries;

  int get totalMinutes => entries.fold(0, (s, e) => s + e.minutes);

  String get projectName {
    final parts = issue.idReadable.split('-');
    return parts.length > 1 ? parts.first : '—';
  }
}

List<PlanIssueGroup> groupPlanEntries(PlanBuildResult plan) {
  final grouped = <String, List<PlannedEntry>>{};
  final order = <String>[];

  for (final e in plan.entries) {
    if (!grouped.containsKey(e.issue.id)) {
      order.add(e.issue.id);
      grouped[e.issue.id] = [];
    }
    grouped[e.issue.id]!.add(e);
  }

  for (final list in grouped.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }

  return order
      .map(
        (id) => PlanIssueGroup(
          issueId: id,
          issue: grouped[id]!.first.issue,
          entries: grouped[id]!,
        ),
      )
      .toList();
}

String dayCountLabel(int n) {
  if (n % 10 == 1 && n % 100 != 11) return '$n день';
  if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
    return '$n дня';
  }
  return '$n дней';
}

bool issueMatchesQuery(YouTrackIssue issue, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return issue.idReadable.toLowerCase().contains(q) ||
      issue.summary.toLowerCase().contains(q);
}
