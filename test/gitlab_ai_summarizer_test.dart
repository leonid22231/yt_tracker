import 'package:test/test.dart';
import 'package:youtrack_timer/agent/cursor_agent_client.dart';
import 'package:youtrack_timer/gitlab/gitlab_mock_data.dart';
import 'package:youtrack_timer/services/gitlab/gitlab_ai_summarizer.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

class _RecordingAgent extends CursorAgentClient {
  _RecordingAgent() : super(apiKey: 'test-key');

  String? lastPrompt;

  @override
  Future<String> completePrompt(String promptText) async {
    lastPrompt = promptText;
    return '## Краткий вывод\nТест';
  }
}

void main() {
  test('period payload содержит метрики и daily summaries', () async {
    final end = DateTime(2024, 6, 20);
    final data = GitLabMockData.build(endDate: end, days: 5);
    final start = end.subtract(const Duration(days: 4));
    final agent = _RecordingAgent();

    await GitLabAiSummarizer(agent).summarizePeriod(
      activity: data,
      start: start,
      end: end,
    );

    expect(agent.lastPrompt, isNotNull);
    expect(agent.lastPrompt, contains('"scope": "period"'));
    expect(agent.lastPrompt, contains('"totalCommits"'));
    expect(agent.lastPrompt, contains('dailySummaries'));
  });

  test('day payload содержит коммиты дня', () async {
    final end = DateTime(2024, 6, 20);
    final data = GitLabMockData.build(endDate: end, days: 5);
    final day = DateUtils.dateOnly(data.commits.first.committedAt);
    final agent = _RecordingAgent();

    await GitLabAiSummarizer(agent).summarizeDay(
      activity: data,
      day: day,
    );

    expect(agent.lastPrompt, contains('"scope": "day"'));
    expect(agent.lastPrompt, contains('"commits"'));
    expect(agent.lastPrompt, contains(DateUtils.formatForQuery(day)));
  });
}
