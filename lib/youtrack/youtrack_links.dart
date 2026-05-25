import 'package:youtrack_timer/youtrack/youtrack_credentials.dart';

/// Ссылки на задачи в веб-интерфейсе YouTrack.
abstract final class YouTrackLinks {
  static String issueUrl(String baseUrl, String idReadable) {
    final root = YouTrackCredentials.normalizeBaseUrl(baseUrl);
    final encoded = Uri.encodeComponent(idReadable);
    return '$root/issue/$encoded';
  }
}
