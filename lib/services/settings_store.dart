import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtrack_timer/config/env_loader.dart';
import 'package:youtrack_timer/gitlab/gitlab_credentials.dart';
import 'package:youtrack_timer/youtrack/youtrack_credentials.dart';

/// Локальные настройки приложения (без токенов в логах).
class SettingsStore {
  static const _keyBaseUrl = 'youtrack_url';
  static const _keyYoutrackToken = 'youtrack_token';
  static const _keyCursorKey = 'cursor_api_key';
  static const _keyUseAi = 'use_ai';
  static const _keyDryRun = 'dry_run';
  static const _keyEnvSynced = 'env_synced_v1';
  static const _keyGitLabUrl = 'gitlab_url';
  static const _keyGitLabToken = 'gitlab_token';
  static const _keyGitLabDemo = 'gitlab_demo_mode';

  Future<AppSettings> load() async {
    EnvLoader.loadOnce();
    final prefs = await SharedPreferences.getInstance();

    var url = prefs.getString(_keyBaseUrl) ?? '';
    var ytToken = prefs.getString(_keyYoutrackToken) ?? '';
    var cursorKey = prefs.getString(_keyCursorKey) ?? '';

    // Подтянуть .env, если в UI ещё пусто или после обновления
    if (url.isEmpty) url = EnvLoader.get('YOUTRACK_URL') ?? '';
    if (ytToken.isEmpty) ytToken = EnvLoader.get('YOUTRACK_TOKEN') ?? '';
    if (cursorKey.isEmpty) cursorKey = EnvLoader.get('CURSOR_API_KEY') ?? '';

    final settings = AppSettings(
      youTrackUrl: url,
      youTrackToken: ytToken,
      cursorApiKey: cursorKey,
      useAi: prefs.getBool(_keyUseAi) ?? true,
      dryRun: prefs.getBool(_keyDryRun) ?? true,
      gitLabUrl: prefs.getString(_keyGitLabUrl) ?? 'https://gitlab.com',
      gitLabToken: prefs.getString(_keyGitLabToken) ?? '',
      gitLabDemoMode: prefs.getBool(_keyGitLabDemo) ?? false,
    );

    // Один раз сохранить .env в prefs для GUI
    if (!(prefs.getBool(_keyEnvSynced) ?? false) && settings.hasYouTrack) {
      await save(settings);
      await prefs.setBool(_keyEnvSynced, true);
    }

    return settings.normalized();
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final n = settings.normalized();
    await prefs.setString(_keyBaseUrl, n.youTrackUrl);
    await prefs.setString(_keyYoutrackToken, n.youTrackToken);
    await prefs.setString(_keyCursorKey, n.cursorApiKey);
    await prefs.setBool(_keyUseAi, n.useAi);
    await prefs.setBool(_keyDryRun, n.dryRun);
    await prefs.setString(_keyGitLabUrl, n.gitLabUrl);
    await prefs.setString(_keyGitLabToken, n.gitLabToken);
    await prefs.setBool(_keyGitLabDemo, n.gitLabDemoMode);
  }
}

class AppSettings {
  AppSettings({
    required this.youTrackUrl,
    required this.youTrackToken,
    required this.cursorApiKey,
    this.useAi = true,
    this.dryRun = true,
    this.gitLabUrl = 'https://gitlab.com',
    this.gitLabToken = '',
    this.gitLabDemoMode = false,
  });

  final String youTrackUrl;
  final String youTrackToken;
  final String cursorApiKey;
  final bool useAi;
  final bool dryRun;
  final String gitLabUrl;
  final String gitLabToken;
  final bool gitLabDemoMode;

  bool get hasYouTrack =>
      youTrackUrl.isNotEmpty && youTrackToken.isNotEmpty;

  bool get hasCursor => cursorApiKey.isNotEmpty;

  bool get hasGitLab => gitLabToken.isNotEmpty || gitLabDemoMode;

  AppSettings normalized() {
    try {
      var normalizedGitLabUrl = gitLabUrl;
      if (normalizedGitLabUrl.isNotEmpty) {
        normalizedGitLabUrl =
            GitLabCredentials.normalizeBaseUrl(normalizedGitLabUrl);
      }
      return AppSettings(
        youTrackUrl: youTrackUrl.isEmpty
            ? ''
            : YouTrackCredentials.normalizeBaseUrl(youTrackUrl),
        youTrackToken: youTrackToken.isEmpty
            ? ''
            : YouTrackCredentials.normalizeToken(youTrackToken),
        cursorApiKey: cursorApiKey.trim(),
        useAi: useAi,
        dryRun: dryRun,
        gitLabUrl: normalizedGitLabUrl,
        gitLabToken: gitLabToken.isEmpty
            ? ''
            : GitLabCredentials.normalizeToken(gitLabToken),
        gitLabDemoMode: gitLabDemoMode,
      );
    } on ArgumentError {
      return this;
    }
  }

  AppSettings copyWith({
    String? youTrackUrl,
    String? youTrackToken,
    String? cursorApiKey,
    bool? useAi,
    bool? dryRun,
    String? gitLabUrl,
    String? gitLabToken,
    bool? gitLabDemoMode,
  }) =>
      AppSettings(
        youTrackUrl: youTrackUrl ?? this.youTrackUrl,
        youTrackToken: youTrackToken ?? this.youTrackToken,
        cursorApiKey: cursorApiKey ?? this.cursorApiKey,
        useAi: useAi ?? this.useAi,
        dryRun: dryRun ?? this.dryRun,
        gitLabUrl: gitLabUrl ?? this.gitLabUrl,
        gitLabToken: gitLabToken ?? this.gitLabToken,
        gitLabDemoMode: gitLabDemoMode ?? this.gitLabDemoMode,
      );
}
