import 'dart:convert';

import 'package:youtrack_timer/agent/cursor_agent_client.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/merge_request_record.dart';
import 'package:youtrack_timer/models/gitlab/daily_activity_summary.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_activity_data.dart';
import 'package:youtrack_timer/models/gitlab/youtrack_gitlab_comparison.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_day_analyzer.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

/// AI-сводка GitLab-активности через Cursor Agent.
class GitLabAiSummarizer {
  const GitLabAiSummarizer(this._agent);

  final CursorAgentClient _agent;

  static const _systemPrompt = '''
Ты аналитик разработческой активности. По данным GitLab (и при наличии — YouTrack) 
составь понятную сводку на русском языке в формате Markdown.

Структура ответа:
## Краткий вывод
2–4 предложения: главное за период/день.

## Активность
- коммиты, ветки, MR, проекты, задачи (PROJ-123)
- оценка времени и изменения кода

## Детали
- что именно делалось (по сообщениям коммитов и MR)
- пики и провалы активности

## Сверка с YouTrack
(только если в данных есть youTrackComparison)
- совпадения и расхождения списаний
- дни только с GitLab / только с YouTrack
- рекомендации по трекингу

## Наблюдения
- аномалии, риски, что улучшить

Правила:
- Пиши конкретно, со ссылками на task id из данных.
- Не выдумывай коммиты и задачи, которых нет в JSON.
- Если активности нет — честно скажи об этом.
- Ответ — только Markdown, без JSON и без обёртки ```markdown.
''';

  Future<String> summarizePeriod({
    required GitLabActivityData activity,
    required DateTime start,
    required DateTime end,
    YouTrackGitLabComparison? comparison,
    String? userHint,
  }) async {
    final payload = _buildPeriodPayload(
      activity: activity,
      start: start,
      end: end,
      comparison: comparison,
      userHint: userHint,
    );
    return _agent.completePrompt('$_systemPrompt\n\nДанные:\n$payload');
  }

  Future<String> summarizeDay({
    required GitLabActivityData activity,
    required DateTime day,
    DailyTimeComparison? dayComparison,
    YouTrackGitLabComparison? periodComparison,
    String? userHint,
  }) async {
    final payload = _buildDayPayload(
      activity: activity,
      day: day,
      dayComparison: dayComparison,
      periodComparison: periodComparison,
      userHint: userHint,
    );
    return _agent.completePrompt('$_systemPrompt\n\nДанные:\n$payload');
  }

  String _buildPeriodPayload({
    required GitLabActivityData activity,
    required DateTime start,
    required DateTime end,
    YouTrackGitLabComparison? comparison,
    String? userHint,
  }) {
    final m = activity.metrics;
    final data = <String, dynamic>{
      'scope': 'period',
      'period': {
        'start': DateUtils.formatForQuery(start),
        'end': DateUtils.formatForQuery(end),
      },
      'developer': activity.user.username,
      'metrics': {
        'totalCommits': m.totalCommits,
        'totalTasks': m.totalTasks,
        'totalEstimatedMinutes': m.totalEstimatedMinutes,
        'totalAdditions': m.totalAdditions,
        'totalDeletions': m.totalDeletions,
        'activeDaysCount': m.activeDaysCount,
        'longestActiveStreak': m.longestActiveStreak,
        'averageProductivityScore': m.averageProductivityScore,
        'mergeRequestCount': m.mergeRequestCount,
        'topProject': m.topProject,
        'peakDay': m.peakDay != null
            ? DateUtils.formatForQuery(m.peakDay!)
            : null,
      },
      'dailySummaries': m.dailySummaries
          .where((d) => d.commitCount > 0 || d.branchesTouched > 0)
          .map(_dailyJson)
          .toList(),
      'mergeRequests': activity.mergeRequests
          .take(40)
          .map(_mergeRequestJson)
          .toList(),
    };

    if (comparison != null) {
      data['youTrackComparison'] = _comparisonJson(comparison);
    }
    if (userHint?.trim().isNotEmpty == true) {
      data['userHint'] = userHint!.trim();
    }

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String _buildDayPayload({
    required GitLabActivityData activity,
    required DateTime day,
    DailyTimeComparison? dayComparison,
    YouTrackGitLabComparison? periodComparison,
    String? userHint,
  }) {
    final detail = const GitLabDayAnalyzer().build(
      activity: activity,
      date: day,
    );

    final data = <String, dynamic>{
      'scope': 'day',
      'date': DateUtils.formatForQuery(detail.date),
      'developer': activity.user.username,
      'summary': _dailyJson(detail.summary),
      'commits': detail.commits.map(_commitJson).toList(),
      'branches': detail.branches
          .map((b) => {
                'name': b.name,
                'project': b.projectName,
                'taskIds': b.taskIds,
              })
          .toList(),
      'mergeRequests': detail.mergeRequests.map(_mergeRequestJson).toList(),
      'projects': detail.projects,
    };

    if (dayComparison != null) {
      data['youTrackDay'] = _dailyComparisonJson(dayComparison);
    }
    if (periodComparison != null) {
      data['youTrackPeriodContext'] = {
        'overallAlignmentScore': periodComparison.overallAlignmentScore,
        'totalYoutrackMinutes': periodComparison.totalYoutrackMinutes,
        'totalGitlabEstimatedMinutes':
            periodComparison.totalGitlabEstimatedMinutes,
        'insights': periodComparison.insights.take(5).toList(),
      };
    }
    if (userHint?.trim().isNotEmpty == true) {
      data['userHint'] = userHint!.trim();
    }

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Map<String, dynamic> _dailyJson(DailyActivitySummary d) => {
        'date': DateUtils.formatForQuery(d.date),
        'commitCount': d.commitCount,
        'branchesTouched': d.branchesTouched,
        'taskIds': d.taskIds,
        'estimatedMinutes': d.estimatedMinutes,
        'productivityScore': d.productivityScore,
        'totalAdditions': d.totalAdditions,
        'totalDeletions': d.totalDeletions,
        'mergeRequestCount': d.mergeRequestCount,
      };

  Map<String, dynamic> _commitJson(CommitRecord c) => {
        'shortId': c.shortId,
        'message': _firstLine(c.message),
        'project': c.projectName,
        'branch': c.branchName,
        'taskIds': c.taskIds,
        'additions': c.additions,
        'deletions': c.deletions,
        'mergeRequest': c.mergeRequestIid != null
            ? {
                'iid': c.mergeRequestIid,
                'title': c.mergeRequestTitle,
              }
            : null,
        'webUrl': c.webUrl,
      };

  Map<String, dynamic> _mergeRequestJson(MergeRequestRecord mr) => {
        'reference': mr.reference,
        'title': mr.title,
        'state': mr.state,
        'sourceBranch': mr.sourceBranch,
        'targetBranch': mr.targetBranch,
        'taskIds': mr.taskIds,
        'additions': mr.additions,
        'deletions': mr.deletions,
        'webUrl': mr.webUrl,
      };

  Map<String, dynamic> _comparisonJson(YouTrackGitLabComparison c) => {
        'overallAlignmentScore': c.overallAlignmentScore,
        'totalYoutrackMinutes': c.totalYoutrackMinutes,
        'totalGitlabEstimatedMinutes': c.totalGitlabEstimatedMinutes,
        'alignedDays': c.alignedDays,
        'mismatchDays': c.mismatchDays,
        'gitlabOnlyDays': c.gitlabOnlyDays,
        'youtrackOnlyDays': c.youtrackOnlyDays,
        'insights': c.insights,
        'dailyComparisons': c.dailyComparisons
            .where((d) => d.isActive)
            .map(_dailyComparisonJson)
            .toList(),
        'taskComparisons': c.taskComparisons
            .take(30)
            .map((t) => {
                  'taskId': t.taskId,
                  'status': t.status.name,
                  'youtrackMinutes': t.youtrackMinutes,
                  'gitlabCommitCount': t.gitlabCommitCount,
                  'gitlabEstimatedMinutes': t.gitlabEstimatedMinutes,
                  'note': t.note,
                })
            .toList(),
      };

  Map<String, dynamic> _dailyComparisonJson(DailyTimeComparison d) => {
        'date': DateUtils.formatForQuery(d.date),
        'status': d.status.name,
        'youtrackMinutes': d.youtrackMinutes,
        'gitlabEstimatedMinutes': d.gitlabEstimatedMinutes,
        'gitlabCommitCount': d.gitlabCommitCount,
        'alignmentScore': d.alignmentScore,
        'youtrackTaskIds': d.youtrackTaskIds,
        'gitlabTaskIds': d.gitlabTaskIds,
        'insight': d.insight,
        'deltaMinutes': d.deltaMinutes,
      };

  String _firstLine(String message) {
    final line = message.split('\n').first.trim();
    return line.length > 200 ? '${line.substring(0, 197)}…' : line;
  }
}
