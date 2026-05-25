import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/models/issue_activity.dart';
import 'package:youtrack_timer/models/work_item.dart';
import 'package:youtrack_timer/models/youtrack_user.dart';
import 'package:youtrack_timer/utils/date_utils.dart';
import 'package:youtrack_timer/youtrack/youtrack_credentials.dart';
import 'package:youtrack_timer/logging/app_log.dart';
import 'package:youtrack_timer/youtrack/issue_assignee_parser.dart';
import 'package:youtrack_timer/youtrack/issue_estimate_parser.dart';
import 'package:youtrack_timer/youtrack/youtrack_query.dart';

/// HTTP-клиент для YouTrack REST API.
class YouTrackClient {
  YouTrackClient(this._config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _baseUrl = YouTrackCredentials.normalizeBaseUrl(_config.baseUrl);

  final AppConfig _config;
  final http.Client _http;
  final String _baseUrl;
  YouTrackUser? _cachedCurrentUser;

  Map<String, String> get _headers => {
        'Authorization':
            YouTrackCredentials.authorizationHeader(_config.token),
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Uri _apiUri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$normalizedPath').replace(
      queryParameters: query,
    );
  }

  /// Текущий пользователь по токену (кэшируется).
  Future<YouTrackUser> currentUser() async {
    if (_cachedCurrentUser != null) return _cachedCurrentUser!;

    final uri = _apiUri('/api/users/me', {'fields': 'id,login,name'});
    final response = await _http.get(uri, headers: _headers);
    _ensureSuccess(response, 'получение текущего пользователя', uri);

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final user = YouTrackUser(
      id: map['id'] as String,
      login: map['login'] as String? ?? '',
      name: map['name'] as String?,
    );
    _cachedCurrentUser = user;
    AppLog.instance.info(
      LogCategory.youtrack,
      'Пользователь YouTrack: ${user.login} (${user.id})',
    );
    return user;
  }

  /// Проверка подключения: лёгкий запрос к API.
  Future<void> ping() async {
    final uri = _apiUri('/api/issues', {
      'query': 'assignee: me',
      'fields': 'id',
      r'$top': '1',
    });
    AppLog.instance.debug(LogCategory.youtrack, 'Ping → ${uri.path}');
    final response = await _http.get(uri, headers: _headers);
    _ensureSuccess(response, 'проверка подключения', uri);
    _decodeJsonList(response.body, 'проверка подключения');
    AppLog.instance.http(
      LogCategory.youtrack,
      method: 'GET',
      path: uri.path,
      status: response.statusCode,
    );
  }

  static final _issueFields = [
    'id',
    'idReadable',
    'summary',
    'created',
    'updated',
    'tags(name)',
    'assignee(id,login,name)',
    r'customFields(name,value(id,login,name,fullName,minutes,presentation),$type)',
  ].join(',');

  /// Задачи для плана и AI: только **assignee: me**.
  Future<List<YouTrackIssue>> fetchAssignedIssues({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final me = await currentUser();
    final queries = YouTrackQuery.assignedInPeriodWithFallbacks(
      startDate: startDate,
      endDate: endDate,
    );

    final byId = <String, YouTrackIssue>{};
    var failedQueries = 0;
    var rawFromApi = 0;
    final errors = <String>[];
    Object? lastError;

    for (final query in queries) {
      try {
        final issues = await _searchIssues(
          query: query,
          startDate: startDate,
          endDate: endDate,
        );
        rawFromApi += issues.length;
        final trustAssignee = YouTrackQuery.queryTrustsAssigneeMe(query);

        for (final issue in issues) {
          if (trustAssignee || issue.isAssignedTo(me)) {
            byId[issue.id] = issue;
          }
        }
      } on YouTrackApiException catch (e) {
        failedQueries++;
        lastError = e;
        final short = e.message.split('\n').first;
        errors.add('$query → $short');
        AppLog.instance.warn(LogCategory.youtrack, 'Запрос не подошёл: $short');
        if (!e.message.contains('invalid_query') &&
            !e.message.contains('400')) {
          rethrow;
        }
      }
    }

    if (byId.isEmpty) {
      if (rawFromApi > 0) {
        throw YouTrackApiException(
          'YouTrack вернул $rawFromApi задач, но ни одна не прошла проверку '
          'assignee (login: ${me.login}). Проверьте поле Assignee в API.',
        );
      }
      if (failedQueries == queries.length && lastError != null) {
        throw YouTrackApiException(
          'Все запросы поиска задач отклонены YouTrack:\n${errors.join('\n')}',
        );
      }
      AppLog.instance.warn(
        LogCategory.youtrack,
        'Нет задач assignee: me за период (проверьте даты в UI)',
      );
      return [];
    }

    if (failedQueries > 0) {
      AppLog.instance.info(
        LogCategory.youtrack,
        'Часть запросов не поддерживается инстансом ($failedQueries)',
      );
    }

    AppLog.instance.info(
      LogCategory.youtrack,
      'В плане (assignee: me): ${byId.length} задач',
    );

    return byId.values.toList();
  }

  /// Одна задача по ключу (KIOSK-114).
  Future<YouTrackIssue?> tryFetchIssueByReadable(String idReadable) async {
    try {
      final uri = _apiUri('/api/issues/$idReadable', {'fields': _issueFields});
      final response = await _http.get(uri, headers: _headers);
      _ensureSuccess(response, 'получение $idReadable', uri);
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseIssue(map);
    } on YouTrackApiException {
      return null;
    }
  }

  /// Задачи, где вы списывали время, но **не** assignee — для «По дням» и учёта дня.
  Future<List<YouTrackIssue>> fetchMyWorkTimelineIssues({
    required DateTime startDate,
    required DateTime endDate,
    required Set<String> excludeIssueIds,
  }) async {
    final me = await currentUser();
    final byId = <String, YouTrackIssue>{};

    for (final query in YouTrackQuery.myWorkTimelineQueries(
      startDate: startDate,
      endDate: endDate,
    )) {
      try {
        final issues = await _searchIssues(
          query: query,
          startDate: startDate,
          endDate: endDate,
        );
        for (final issue in issues) {
          if (excludeIssueIds.contains(issue.id)) continue;
          if (issue.isAssignedTo(me)) continue;
          byId[issue.id] = issue;
        }
      } on YouTrackApiException catch (e) {
        if (!e.message.contains('invalid_query') &&
            !e.message.contains('400')) {
          rethrow;
        }
      }
    }

    if (byId.isNotEmpty) {
      AppLog.instance.info(
        LogCategory.youtrack,
        'По дням (моё время, не assignee): ${byId.length} задач',
      );
    }

    return byId.values.toList();
  }

  Future<List<YouTrackIssue>> _searchIssues({
    required String query,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    AppLog.instance.debug(LogCategory.youtrack, 'Поиск задач: $query');
    final uri = _apiUri('/api/issues', {
      'query': query,
      'fields': _issueFields,
      r'$top': '500',
    });

    final response = await _http.get(uri, headers: _headers);
    _ensureSuccess(response, 'получение задач', uri);

    final body = _decodeJsonList(response.body, 'получение задач');
    var issues = body.map(_parseIssue).toList();

    if (query == YouTrackQuery.assignedToMe()) {
      issues = _filterIssuesByPeriod(issues, startDate, endDate);
    }

    AppLog.instance.http(
      LogCategory.youtrack,
      method: 'GET',
      path: uri.path,
      status: response.statusCode,
      detail: '${issues.length} задач',
    );

    return issues;
  }

  /// Оставляет задачи, пересекающиеся с периодом (по created/updated).
  List<YouTrackIssue> _filterIssuesByPeriod(
    List<YouTrackIssue> issues,
    DateTime start,
    DateTime end,
  ) {
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day, 23, 59, 59);

    return issues.where((issue) {
      final issueStart = issue.created;
      final issueEnd = issue.updated;
      return !issueEnd.isBefore(startOnly) && !issueStart.isAfter(endOnly);
    }).toList();
  }

  YouTrackIssue _parseIssue(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final tags = <String>[];
    final tagsRaw = map['tags'];
    if (tagsRaw is List) {
      for (final tag in tagsRaw) {
        if (tag is Map && tag['name'] is String) {
          tags.add(tag['name'] as String);
        }
      }
    }

    final summary = (map['summary'] as String?) ?? '';
    final isDaily = _isDailyIssue(summary: summary, tags: tags);
    final estimate = IssueEstimateParser.parse(
      map['customFields'] as List<dynamic>?,
    );

    final assigneeParsed = IssueAssigneeParser.parse(map);
    final assigneeId = assigneeParsed.id;
    final assigneeLogin = assigneeParsed.login;
    final assigneeName = assigneeParsed.name;

    return YouTrackIssue(
      id: map['id'] as String,
      idReadable: map['idReadable'] as String,
      summary: summary,
      created: _parseTimestamp(map['created']),
      updated: _parseTimestamp(map['updated']),
      isDaily: isDaily,
      tags: tags,
      estimateMinutes: estimate.minutes,
      estimatePresentation: estimate.presentation,
      estimateFieldName: estimate.fieldName,
      assigneeId: assigneeId,
      assigneeLogin: assigneeLogin,
      assigneeName: assigneeName,
    );
  }

  bool _isDailyIssue({required String summary, required List<String> tags}) {
    final summaryLower = summary.toLowerCase();
    if (summaryLower.contains('daily')) return true;
    return tags.any((t) => t.toLowerCase() == 'daily');
  }

  Future<List<IssueActivity>> fetchActivities(
    String issueId, {
    DateTime? start,
    DateTime? end,
  }) async {
    final categories = [
      'CommentsCategory',
      'CustomFieldCategory',
      'WorkItemCategory',
      'IssueCreatedCategory',
      'SummaryCategory',
    ].join(',');

    final fields =
        r'id,timestamp,$type,author(name),added(name),removed(name),target(text)';

    final query = <String, String>{
      'fields': fields,
      'categories': categories,
      r'$top': '100',
    };
    if (start != null) {
      query['start'] = start.millisecondsSinceEpoch.toString();
    }
    if (end != null) {
      query['end'] = end.millisecondsSinceEpoch.toString();
    }

    final uri = _apiUri('/api/issues/$issueId/activities', query);
    final response = await _http.get(uri, headers: _headers);
    _ensureSuccess(response, 'получение истории $issueId', uri);

    final body = _decodeJsonList(response.body, 'получение истории');
    return body.map(_parseActivity).whereType<IssueActivity>().toList();
  }

  IssueActivity? _parseActivity(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final type = map[r'$type'] as String? ?? 'Unknown';

    final added = <String>[];
    final removed = <String>[];
    for (final listName in ['added', 'removed']) {
      final list = map[listName];
      if (list is List) {
        for (final item in list) {
          if (item is Map && item['name'] is String) {
            (listName == 'added' ? added : removed).add(item['name'] as String);
          }
        }
      }
    }

    String? commentText;
    final target = map['target'];
    if (target is Map && target['text'] is String) {
      commentText = target['text'] as String;
    }

    final authorMap = map['author'];
    final author = authorMap is Map ? authorMap['name'] as String? : null;

    return IssueActivity(
      timestamp: _parseTimestamp(map['timestamp']),
      type: type,
      author: author,
      added: added,
      removed: removed,
      commentText: commentText,
    );
  }

  static const _workItemsPageSize = 100;

  /// Work items задачи. По умолчанию только записи текущего пользователя.
  /// YouTrack отдаёт максимум [_workItemsPageSize] за запрос — читаем все страницы.
  Future<List<YouTrackWorkItem>> fetchWorkItems(
    String issueId, {
    bool onlyMine = true,
  }) async {
    final fields =
        'id,date,duration(minutes,presentation),text,'
        'author(id,login,name,fullName),creator(id,login,name,fullName)';

    final all = <YouTrackWorkItem>[];
    var skip = 0;

    while (true) {
      final uri = _apiUri(
        '/api/issues/$issueId/timeTracking/workItems',
        {
          'fields': fields,
          r'$top': '$_workItemsPageSize',
          r'$skip': '$skip',
        },
      );

      final response = await _http.get(uri, headers: _headers);
      _ensureSuccess(response, 'получение work items для $issueId', uri);

      final body = _decodeJsonList(response.body, 'получение work items');
      final page = body.map(_parseWorkItem).toList();
      if (page.isEmpty) break;

      all.addAll(page);
      if (page.length < _workItemsPageSize) break;
      skip += _workItemsPageSize;
      if (skip > 10000) {
        AppLog.instance.warn(
          LogCategory.youtrack,
          'Work items $issueId: остановка на $skip (лимит)',
        );
        break;
      }
    }

    if (skip > 0) {
      AppLog.instance.debug(
        LogCategory.youtrack,
        'Work items $issueId: загружено ${all.length} (страниц: ${skip ~/ _workItemsPageSize + 1})',
      );
    }

    if (!onlyMine) return all;

    final me = await currentUser();
    return all.where((w) => w.isAuthoredBy(me)).toList();
  }

  YouTrackWorkItem _parseWorkItem(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final duration = map['duration'] as Map<String, dynamic>?;
    var minutes = (duration?['minutes'] as num?)?.toInt() ?? 0;
    if (minutes <= 0) {
      minutes = _minutesFromPresentation(
        duration?['presentation'] as String?,
      );
    }

    final author = _parseUserRef(map['author']);
    final creator = _parseUserRef(map['creator']);

    return YouTrackWorkItem(
      id: map['id'] as String,
      date: DateUtils.parseWorkItemDate(map['date']),
      minutes: minutes,
      text: map['text'] as String?,
      authorId: author?.id,
      authorLogin: author?.login,
      authorName: author?.name,
      creatorId: creator?.id,
      creatorLogin: creator?.login,
      creatorName: creator?.name,
    );
  }

  ({String? id, String? login, String? name})? _parseUserRef(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    return (
      id: raw['id'] as String?,
      login: raw['login'] as String?,
      name: raw['name'] as String?,
    );
  }

  Future<bool> createWorkItem({
    required String issueId,
    required int minutes,
    required DateTime date,
    String? comment,
    bool allowWrite = false,
  }) async {
    if (!allowWrite) {
      throw YouTrackApiException(
        'POST workItems заблокирован. Используйте SubmitService.write() '
        'после подтверждения пользователя.',
      );
    }

    AppLog.instance.warn(
      LogCategory.youtrack,
      'POST workItem $issueId $minutes мин',
    );

    final uri = _apiUri(
      '/api/issues/$issueId/timeTracking/workItems',
      {'fields': 'id,date,duration(minutes,presentation),text'},
    );

    final payload = <String, dynamic>{
      'duration': {'minutes': minutes},
      'date': DateUtils.toYouTrackDateMillis(date),
      if (comment != null && comment.isNotEmpty) 'text': comment,
    };

    final response = await _http.post(
      uri,
      headers: _headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    }

    throw YouTrackApiException(
      _formatHttpError(response.statusCode, response.body, uri),
    );
  }

  /// Убирает текст (комментарий) у существующего work item.
  Future<void> clearWorkItemText({
    required String issueId,
    required String workItemId,
    bool allowWrite = false,
  }) async {
    if (!allowWrite) {
      throw YouTrackApiException(
        'Изменение workItems заблокировано. Запустите скрипт с --write.',
      );
    }

    final uri = _apiUri(
      '/api/issues/$issueId/timeTracking/workItems/$workItemId',
      {'fields': 'id,text'},
    );

    final response = await _http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'text': ''}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw YouTrackApiException(
      _formatHttpError(response.statusCode, response.body, uri),
    );
  }

  int _minutesFromPresentation(String? presentation) {
    if (presentation == null || presentation.isEmpty) return 0;
    var total = 0;
    final weeks = RegExp(r'(\d+)\s*w').firstMatch(presentation);
    final days = RegExp(r'(\d+)\s*d').firstMatch(presentation);
    final hours = RegExp(r'(\d+)\s*h').firstMatch(presentation);
    final mins = RegExp(r'(\d+)\s*m').firstMatch(presentation);
    if (weeks != null) total += int.parse(weeks.group(1)!) * 5 * 8 * 60;
    if (days != null) total += int.parse(days.group(1)!) * 8 * 60;
    if (hours != null) total += int.parse(hours.group(1)!) * 60;
    if (mins != null) total += int.parse(mins.group(1)!);
    return total;
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
    }
    if (value is String) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }

  void _ensureSuccess(http.Response response, String action, Uri uri) {
    final body = response.body.trimLeft();
    final isHtml = body.startsWith('<!') ||
        body.startsWith('<html') ||
        response.headers['content-type']?.contains('text/html') == true;

    if (isHtml) {
      throw YouTrackApiException(_htmlErrorHint(response.statusCode, uri));
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw YouTrackApiException(
      _formatHttpError(response.statusCode, response.body, uri),
    );
  }

  List<dynamic> _decodeJsonList(String body, String action) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return [];

    if (trimmed.startsWith('<!') || trimmed.startsWith('<html')) {
      throw YouTrackApiException(
        '$action: сервер вернул HTML вместо JSON. '
        'Проверьте URL (без /api в конце) и permanent token perm:…',
      );
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['error'] != null) {
        throw YouTrackApiException('$action: ${decoded['error']}');
      }
      throw YouTrackApiException(
        '$action: ожидался JSON-массив, получен ${decoded.runtimeType}',
      );
    } on FormatException {
      throw YouTrackApiException(
        '$action: ответ не является JSON. '
        'Проверьте YOUTRACK_URL и токен в настройках.',
      );
    }
  }

  String _formatHttpError(int status, String body, Uri uri) {
    final preview = body.length > 200 ? '${body.substring(0, 200)}…' : body;
    return 'HTTP $status для ${uri.path}\n$preview';
  }

  String _htmlErrorHint(int status, Uri uri) {
    return '''
Сервер вернул HTML-страницу (HTTP $status), а не JSON API.
Запрос: ${uri.origin}${uri.path}

Что проверить:
1. URL — корень инстанса, БЕЗ /api: https://company.youtrack.cloud
   Для on-premise часто: https://server.company.com/youtrack
2. Токен — permanent token с префиксом perm: (YouTrack → Профиль → Безопасность)
3. Откройте в браузере: ${uri.origin}/api/issues?fields=id — должна быть JSON-ошибка auth, не страница входа
''';
  }

  void close() => _http.close();
}

class YouTrackApiException implements Exception {
  YouTrackApiException(this.message);
  final String message;

  @override
  String toString() => 'YouTrackApiException: $message';
}
