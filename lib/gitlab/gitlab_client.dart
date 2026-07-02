import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:youtrack_timer/gitlab/gitlab_commit_author.dart';
import 'package:youtrack_timer/gitlab/gitlab_credentials.dart';
import 'package:youtrack_timer/gitlab/gitlab_links.dart';
import 'package:youtrack_timer/models/gitlab/branch_record.dart';
import 'package:youtrack_timer/models/gitlab/commit_record.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_user_info.dart';
import 'package:youtrack_timer/models/gitlab/merge_request_record.dart';
import 'package:youtrack_timer/services/gitlab/task_id_extractor.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

class GitLabApiException implements Exception {
  GitLabApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// HTTP-клиент GitLab API v4.
class GitLabClient {
  GitLabClient({
    required String baseUrl,
    required String token,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl.isEmpty
            ? ''
            : GitLabCredentials.normalizeBaseUrl(baseUrl),
        _token = GitLabCredentials.normalizeToken(token),
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final String _token;
  final http.Client _http;

  bool get isConfigured => _baseUrl.isNotEmpty && _token.isNotEmpty;

  String get baseUrl => _baseUrl;

  String get _host => Uri.tryParse(_baseUrl)?.host ?? '';

  Map<String, String> get _headers => GitLabCredentials.headers(_token);

  Uri _apiUri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl/api/v4$normalized').replace(queryParameters: query);
  }

  void close() => _http.close();

  Future<GitLabUserInfo> getCurrentUser() async {
    final data = await _getJson(
      '/user',
      {
        'fields':
            'id,username,name,email,public_email,commit_email,avatar_url',
      },
    );
    return GitLabUserInfo(
      id: data['id'] as int,
      username: data['username'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      publicEmail: data['public_email'] as String? ?? '',
      commitEmail: data['commit_email'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String? ?? '',
    );
  }

  Future<void> ping() async {
    await getCurrentUser();
  }

  Future<List<GitLabProject>> listMemberProjects({int perPage = 50}) async {
    final items = await _getJsonList(
      '/projects',
      {
        'membership': 'true',
        'min_access_level': '10',
        'order_by': 'last_activity_at',
        'sort': 'desc',
        'per_page': '$perPage',
      },
    );
    return items
        .map(
          (e) => GitLabProject(
            id: e['id'] as int,
            name: e['name'] as String? ?? '',
            pathWithNamespace: e['path_with_namespace'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<List<CommitRecord>> fetchUserCommits({
    required GitLabUserInfo user,
    required DateTime since,
    required DateTime until,
    int maxProjects = 50,
    int commitsPerProject = 100,
    void Function(String detail, double fraction)? onProgress,
  }) async {
    if (!_canIdentifyAuthor(user)) {
      throw GitLabApiException(
        'Не удалось определить автора коммитов (пустые email и username в профиле GitLab).',
      );
    }

    final projects = await listMemberProjects(perPage: maxProjects);
    final projectById = {for (final p in projects) p.id: p};
    final seen = <String>{};
    final commits = <CommitRecord>[];

    void add(CommitRecord c) {
      if (!_isInRange(c.committedAt, since, until)) return;
      if (seen.add(c.id)) commits.add(c);
    }

    onProgress?.call('merge requests', 0.05);
    for (final c in await _fetchCommitsFromMergeRequests(
      user: user,
      since: since,
      until: until,
      projectById: projectById,
    )) {
      add(c);
    }

    onProgress?.call('push events', 0.25);
    for (final c in await _fetchCommitsFromPushShas(
      user: user,
      since: since,
      until: until,
      projectById: projectById,
    )) {
      add(c);
    }

    for (var i = 0; i < projects.length; i++) {
      final project = projects[i];
      onProgress?.call(
        project.pathWithNamespace,
        0.35 + 0.65 * (i + 1) / projects.length,
      );
      final pageCommits = await _fetchProjectCommits(
        project: project,
        since: since,
        until: until,
        user: user,
        perPage: commitsPerProject,
      );
      for (final c in pageCommits) {
        add(c);
      }
    }

    commits.sort((a, b) => b.committedAt.compareTo(a.committedAt));
    return commits;
  }

  Future<List<MergeRequestRecord>> fetchUserMergeRequests({
    required GitLabUserInfo user,
    required DateTime since,
    required DateTime until,
  }) async {
    final raw = await _listUserMergeRequests(user, since, until);
    final result = <MergeRequestRecord>[];

    for (final mr in raw) {
      final projectId = mr['project_id'] as int? ?? 0;
      final iid = mr['iid'] as int? ?? 0;
      if (projectId <= 0 || iid <= 0) continue;

      final projectPath = _projectPathFromMr(mr);
      final title = (mr['title'] as String? ?? '').trim();
      final sourceBranch = mr['source_branch'] as String? ?? '';
      final targetBranch = mr['target_branch'] as String? ?? '';
      final state = mr['state'] as String? ?? '';
      final createdAt =
          DateTime.parse(mr['created_at'] as String).toLocal();
      final updatedAt =
          DateTime.parse(mr['updated_at'] as String).toLocal();
      DateTime? mergedAt;
      final mergedRaw = mr['merged_at'];
      if (mergedRaw is String && mergedRaw.isNotEmpty) {
        mergedAt = DateTime.parse(mergedRaw).toLocal();
      }

      final webUrl = (mr['web_url'] as String? ?? '').trim();
      final taskIds = TaskIdExtractor.extractFromTexts([
        title,
        sourceBranch,
      ]);

      result.add(
        MergeRequestRecord(
          projectId: projectId,
          projectPath: projectPath,
          iid: iid,
          title: title,
          sourceBranch: sourceBranch,
          targetBranch: targetBranch,
          state: state,
          createdAt: createdAt,
          updatedAt: updatedAt,
          mergedAt: mergedAt,
          taskIds: taskIds,
          webUrl: webUrl.isNotEmpty
              ? webUrl
              : GitLabLinks.mergeRequestUrl(_baseUrl, projectPath, iid),
        ),
      );
    }

    return result;
  }

  Future<List<BranchRecord>> fetchBranchActivity({
    required GitLabUserInfo user,
    required DateTime since,
    required DateTime until,
    int perPage = 100,
    int maxPages = 10,
  }) async {
    final events = await _fetchUserPushEvents(
      user: user,
      since: since,
      until: until,
      perPage: perPage,
      maxPages: maxPages,
    );

    final branches = <String, BranchRecord>{};
    final projectNames = await _projectNamesById(events);

    for (final event in events) {
      final action = event['action_name'] as String? ?? '';
      if (!action.contains('pushed')) continue;

      final pushData = event['push_data'];
      if (pushData is! Map<String, dynamic>) continue;
      if (pushData['ref_type'] != 'branch') continue;

      final ref = pushData['ref'] as String? ?? '';
      if (ref.isEmpty || ref == 'HEAD') continue;

      final createdAt = DateTime.parse(event['created_at'] as String).toLocal();
      final day = DateUtils.dateOnly(createdAt);
      if (day.isBefore(DateUtils.dateOnly(since)) ||
          day.isAfter(DateUtils.dateOnly(until))) {
        continue;
      }

      final projectId = event['project_id'] as int? ?? 0;
      final key = '$projectId::$ref';
      final isNew = pushData['action'] == 'created' ||
          (pushData['commit_count'] as int? ?? 0) == 0;

      final existing = branches[key];
      if (existing == null || createdAt.isAfter(existing.lastActivityAt)) {
        branches[key] = BranchRecord(
          name: ref,
          projectId: projectId,
          projectName: projectNames[projectId] ?? '',
          lastActivityAt: createdAt,
          isNew: isNew || (existing?.isNew ?? false),
        );
      }
    }

    return branches.values.toList()
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
  }

  Future<List<CommitRecord>> _fetchCommitsFromMergeRequests({
    required GitLabUserInfo user,
    required DateTime since,
    required DateTime until,
    required Map<int, GitLabProject> projectById,
  }) async {
    final mergeRequests = await _listUserMergeRequests(user, since, until);
    final result = <CommitRecord>[];

    for (final mr in mergeRequests) {
      final projectId = mr['project_id'] as int? ?? 0;
      final iid = mr['iid'];
      if (projectId <= 0 || iid == null) continue;

      final project = projectById[projectId] ??
          GitLabProject(
            id: projectId,
            name: '',
            pathWithNamespace: _projectPathFromMr(mr),
          );

      final mrTitle = (mr['title'] as String? ?? '').trim();
      final sourceBranch = mr['source_branch'] as String? ?? '';
      final isUserMr = _mrAuthorId(mr) == user.id;
      final mrIid = iid is int ? iid : int.tryParse('$iid') ?? 0;

      List<Map<String, dynamic>> mrCommits;
      try {
        mrCommits = await _getJsonList(
          '/projects/$projectId/merge_requests/$iid/commits',
          {'per_page': '100'},
        );
      } on GitLabApiException {
        continue;
      }

      for (final raw in mrCommits) {
        if (!GitLabCommitAuthor.matches(
          user,
          raw,
          gitlabHost: _host,
          fromUserMergeRequest: isUserMr,
        )) {
          continue;
        }

        var record = await _parseCommitWithStats(
          raw,
          project,
          fallbackTitle: mrTitle,
          branchName: sourceBranch,
          mergeRequestIid: mrIid > 0 ? mrIid : null,
          mergeRequestTitle: mrTitle,
        );
        result.add(record);
      }
    }

    return result;
  }

  Future<List<CommitRecord>> _fetchCommitsFromPushShas({
    required GitLabUserInfo user,
    required DateTime since,
    required DateTime until,
    required Map<int, GitLabProject> projectById,
  }) async {
    final events = await _fetchUserPushEvents(
      user: user,
      since: since,
      until: until,
    );
    final result = <CommitRecord>[];

    for (final event in events) {
      final pushData = event['push_data'];
      if (pushData is! Map<String, dynamic>) continue;

      final projectId = event['project_id'] as int? ?? 0;
      final sha = pushData['commit_to'] as String? ?? '';
      if (projectId <= 0 || sha.isEmpty) continue;

      final project = projectById[projectId];
      if (project == null) continue;

      try {
        final raw = await _getJson(
          '/projects/$projectId/repository/commits/$sha',
          {'stats': 'true'},
        );
        if (raw is! Map<String, dynamic>) continue;
        if (!GitLabCommitAuthor.matches(user, raw, gitlabHost: _host)) continue;

        final branch = pushData['ref'] as String? ?? '';
        result.add(
          await _parseCommitWithStats(
            raw,
            project,
            branchName: branch,
          ),
        );
      } on GitLabApiException {
        continue;
      }
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> _listUserMergeRequests(
    GitLabUserInfo user,
    DateTime since,
    DateTime until,
  ) async {
    final result = <Map<String, dynamic>>[];
    var page = 1;

    while (page <= 5) {
      final items = await _getJsonList(
        '/merge_requests',
        {
          'author_id': '${user.id}',
          'scope': 'all',
          'state': 'all',
          'updated_after': since.toUtc().toIso8601String(),
          'per_page': '50',
          'page': '$page',
          'order_by': 'updated_at',
          'sort': 'desc',
        },
      );
      if (items.isEmpty) break;

      for (final mr in items) {
        if (_mrTouchesPeriod(mr, since, until)) result.add(mr);
      }

      if (items.length < 50) break;
      page++;
    }

    return result;
  }

  bool _mrTouchesPeriod(
    Map<String, dynamic> mr,
    DateTime since,
    DateTime until,
  ) {
    final candidates = [
      mr['updated_at'],
      mr['created_at'],
      mr['merged_at'],
    ];
    for (final raw in candidates) {
      if (raw is! String) continue;
      final dt = DateTime.parse(raw).toLocal();
      final day = DateUtils.dateOnly(dt);
      if (!day.isBefore(DateUtils.dateOnly(since)) &&
          !day.isAfter(DateUtils.dateOnly(until))) {
        return true;
      }
    }
    return false;
  }

  int? _mrAuthorId(Map<String, dynamic> mr) {
    final author = mr['author'];
    if (author is Map<String, dynamic>) {
      final id = author['id'];
      if (id is int) return id;
    }
    final authorId = mr['author_id'];
    if (authorId is int) return authorId;
    return null;
  }

  String _projectPathFromMr(Map<String, dynamic> mr) {
    final refs = mr['references'];
    if (refs is Map<String, dynamic>) {
      final full = refs['full'] as String? ?? '';
      if (full.contains('!')) {
        return full.split('!').first;
      }
    }
    return '';
  }

  Future<List<Map<String, dynamic>>> _fetchUserPushEvents({
    required GitLabUserInfo user,
    required DateTime since,
    required DateTime until,
    int perPage = 100,
    int maxPages = 10,
  }) async {
    final result = <Map<String, dynamic>>[];
    var page = 1;

    while (page <= maxPages) {
      List<Map<String, dynamic>> events;
      try {
        events = await _getJsonList(
          '/users/${user.id}/events',
          {
            'action': 'pushed',
            'after': DateUtils.formatForQuery(since),
            'before': DateUtils.formatForQuery(
              until.add(const Duration(days: 1)),
            ),
            'per_page': '$perPage',
            'page': '$page',
            'sort': 'desc',
          },
        );
      } on GitLabApiException {
        if (page == 1) {
          events = await _getJsonList(
            '/events',
            {
              'action': 'pushed',
              'after': DateUtils.formatForQuery(since),
              'before': DateUtils.formatForQuery(
                until.add(const Duration(days: 1)),
              ),
              'per_page': '$perPage',
              'page': '$page',
              'sort': 'desc',
            },
          );
        } else {
          rethrow;
        }
      }

      if (events.isEmpty) break;

      for (final event in events) {
        if (_isUserEvent(event, user)) result.add(event);
      }

      if (events.length < perPage) break;
      page++;
    }

    return result;
  }

  bool _isUserEvent(Map<String, dynamic> event, GitLabUserInfo user) {
    final authorId = event['author_id'];
    if (authorId is int && authorId != user.id) return false;

    final authorUsername = (event['author_username'] as String? ?? '')
        .trim()
        .toLowerCase();
    if (authorUsername.isNotEmpty &&
        user.username.isNotEmpty &&
        authorUsername != user.username.toLowerCase()) {
      return false;
    }

    return true;
  }

  Future<Map<int, String>> _projectNamesById(
    List<Map<String, dynamic>> events,
  ) async {
    final ids = events
        .map((e) => e['project_id'] as int? ?? 0)
        .where((id) => id > 0)
        .toSet();
    if (ids.isEmpty) return {};

    final projects = await listMemberProjects(perPage: 100);
    return {
      for (final p in projects.where((p) => ids.contains(p.id)))
        p.id: p.pathWithNamespace.isNotEmpty ? p.pathWithNamespace : p.name,
    };
  }

  Future<List<CommitRecord>> _fetchProjectCommits({
    required GitLabProject project,
    required DateTime since,
    required DateTime until,
    required GitLabUserInfo user,
    required int perPage,
  }) async {
    final authorQueries = <String>{
      if (user.username.isNotEmpty) user.username,
      if (user.email.isNotEmpty) user.email,
      if (user.commitEmail.isNotEmpty) user.commitEmail,
      if (user.name.isNotEmpty) user.name,
    };

    final merged = <String, Map<String, dynamic>>{};
    for (final author in authorQueries) {
      final items = await _getJsonList(
        '/projects/${project.id}/repository/commits',
        {
          'since': since.toUtc().toIso8601String(),
          'until': until.add(const Duration(days: 1)).toUtc().toIso8601String(),
          'per_page': '$perPage',
          'with_stats': 'true',
          'author': author,
        },
      );
      for (final item in items) {
        final id = item['id'] as String? ?? '';
        if (id.isNotEmpty) merged[id] = item;
      }
    }

    final result = <CommitRecord>[];
    for (final raw in merged.values) {
      if (!GitLabCommitAuthor.matches(user, raw, gitlabHost: _host)) continue;
      result.add(await _parseCommitWithStats(raw, project));
    }
    return result;
  }

  Future<CommitRecord> _parseCommitWithStats(
    Map<String, dynamic> e,
    GitLabProject project, {
    String fallbackTitle = '',
    String branchName = '',
    int? mergeRequestIid,
    String mergeRequestTitle = '',
  }) async {
    var stats = e['stats'];
    var additions = 0;
    var deletions = 0;
    if (stats is Map<String, dynamic>) {
      additions = stats['additions'] as int? ?? 0;
      deletions = stats['deletions'] as int? ?? 0;
    }

    final sha = e['id'] as String? ?? '';
    if (sha.isNotEmpty && additions == 0 && deletions == 0) {
      try {
        final detail = await _getJson(
          '/projects/${project.id}/repository/commits/$sha',
          {'stats': 'true'},
        );
        if (detail is Map<String, dynamic>) {
          final detailStats = detail['stats'];
          if (detailStats is Map<String, dynamic>) {
            additions = detailStats['additions'] as int? ?? additions;
            deletions = detailStats['deletions'] as int? ?? deletions;
          }
        }
      } on GitLabApiException {
        // Оставляем нули, если детальный запрос недоступен.
      }
    }

    final title = (e['title'] as String? ?? '').trim();
    final message = (e['message'] as String? ?? '').trim();
    var combined = title.isNotEmpty ? title : message;
    if (fallbackTitle.isNotEmpty &&
        !combined.toUpperCase().contains(fallbackTitle.toUpperCase())) {
      combined = combined.isEmpty
          ? fallbackTitle
          : '$combined\n$fallbackTitle';
    }

    final committed = DateTime.parse(
      (e['committed_date'] ?? e['created_at']) as String,
    ).toLocal();

    final projectPath = project.pathWithNamespace.isNotEmpty
        ? project.pathWithNamespace
        : project.name;
    final webUrl = sha.isNotEmpty
        ? GitLabLinks.commitUrl(_baseUrl, projectPath, sha)
        : '';

    return CommitRecord(
      id: sha,
      shortId: e['short_id'] as String? ?? '',
      message: combined,
      committedAt: committed,
      projectId: project.id,
      projectName: projectPath,
      branchName: branchName,
      additions: additions,
      deletions: deletions,
      mergeRequestIid: mergeRequestIid,
      mergeRequestTitle: mergeRequestTitle,
      webUrl: webUrl,
    );
  }

  bool _isInRange(DateTime date, DateTime since, DateTime until) {
    final day = DateUtils.dateOnly(date);
    return !day.isBefore(DateUtils.dateOnly(since)) &&
        !day.isAfter(DateUtils.dateOnly(until));
  }

  bool _canIdentifyAuthor(GitLabUserInfo user) =>
      user.username.isNotEmpty || user.knownEmails.isNotEmpty;

  Future<dynamic> _getJson(String path, [Map<String, String>? query]) async {
    final response = await _http.get(_apiUri(path, query), headers: _headers);
    _ensureSuccess(response);
    return jsonDecode(response.body);
  }

  Future<List<Map<String, dynamic>>> _getJsonList(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _http.get(_apiUri(path, query), headers: _headers);
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    var message = 'GitLab API: HTTP ${response.statusCode}';
    if (response.statusCode == 401) {
      message = 'Недействительный GitLab token. Проверьте Personal Access Token.';
    } else if (response.statusCode == 403) {
      message = 'Недостаточно прав у token. Нужны read_api и read_repository.';
    } else {
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          message = '${body['message']}';
        }
      } catch (_) {}
    }
    throw GitLabApiException(message, statusCode: response.statusCode);
  }
}

class GitLabProject {
  const GitLabProject({
    required this.id,
    required this.name,
    required this.pathWithNamespace,
  });

  final int id;
  final String name;
  final String pathWithNamespace;
}
