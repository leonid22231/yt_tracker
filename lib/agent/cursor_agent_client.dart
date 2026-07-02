import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:youtrack_timer/logging/app_log.dart';

/// Клиент Cursor Cloud Agents API для AI-оценки времени.
///
/// Документация: https://cursor.com/docs/cloud-agent/api/endpoints
class CursorAgentClient {
  CursorAgentClient({
    required this.apiKey,
    http.Client? httpClient,
    this.baseUrl = 'https://api.cursor.com',
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final http.Client _http;

  static const _pollInterval = Duration(seconds: 3);
  static const _maxWait = Duration(minutes: 5);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Отправляет промпт агенту без репозитория и ждёт JSON-ответ.
  Future<String> completePrompt(String promptText) async {
    AppLog.instance.info(LogCategory.cursor, 'Создание cloud agent…');
    final createUri = Uri.parse('$baseUrl/v1/agents');
    final body = jsonEncode({
      'prompt': {'text': promptText},
      'model': {'id': 'auto'},
      // Без repos — агент только анализирует переданный контекст
    });

    final createResp = await _http.post(
      createUri,
      headers: _headers,
      body: body,
    );

    if (createResp.statusCode < 200 || createResp.statusCode >= 300) {
      throw CursorAgentException(
        'Создание агента: HTTP ${createResp.statusCode}',
      );
    }

    final createJson = jsonDecode(createResp.body) as Map<String, dynamic>;
    final agent = createJson['agent'] as Map<String, dynamic>?;
    final run = createJson['run'] as Map<String, dynamic>?;
    final agentId = agent?['id'] as String?;
    final runId = run?['id'] as String? ?? agent?['latestRunId'] as String?;

    if (agentId == null || runId == null) {
      throw CursorAgentException('Некорректный ответ API: нет agent/run id');
    }

    AppLog.instance.info(
      LogCategory.cursor,
      'Ожидание ответа агента (run: $runId)…',
    );

    final deadline = DateTime.now().add(_maxWait);
    var lastStatus = '';
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollInterval);

      final runUri = Uri.parse('$baseUrl/v1/agents/$agentId/runs/$runId');
      final runResp = await _http.get(runUri, headers: _headers);

      if (runResp.statusCode < 200 || runResp.statusCode >= 300) {
        continue;
      }

      final runJson = jsonDecode(runResp.body) as Map<String, dynamic>;
      final status = runJson['status'] as String? ?? '';

      if (status != lastStatus) {
        lastStatus = status;
        AppLog.instance.debug(LogCategory.cursor, 'Статус run: $status');
      }

      if (status == 'FINISHED') {
        AppLog.instance.success(LogCategory.cursor, 'Ответ агента получен');
        return runJson['result'] as String? ?? '';
      }
      if (status == 'ERROR' ||
          status == 'CANCELLED' ||
          status == 'EXPIRED') {
        throw CursorAgentException('Запуск агента завершился: $status');
      }
    }

    throw CursorAgentException('Таймаут ожидания ответа Cursor Agent');
  }

  void close() => _http.close();
}

class CursorAgentException implements Exception {
  CursorAgentException(this.message);
  final String message;

  @override
  String toString() => 'CursorAgentException: $message';
}
