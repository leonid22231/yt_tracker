/// Нормализация URL и токена YouTrack REST API.
class YouTrackCredentials {
  /// Базовый URL без `/api` и без завершающего слэша.
  static String normalizeBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;

    if (!url.contains('://')) {
      url = 'https://$url';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw ArgumentError('Некорректный URL YouTrack: $raw');
    }

    var path = uri.path;
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    // Частая ошибка: .../api или .../api/
    if (path.endsWith('/api')) {
      path = path.substring(0, path.length - 4);
    }

    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path.isEmpty ? null : path,
    ).toString().replaceAll(RegExp(r'/+$'), '');
  }

  /// Permanent token всегда с префиксом perm: для Bearer.
  static String normalizeToken(String raw) {
    var token = raw.trim();
    if (token.isEmpty) return token;

    // Убираем случайный префикс Bearer
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }

    if (!token.startsWith('perm:')) {
      token = 'perm:$token';
    }
    return token;
  }

  /// Значение заголовка Authorization (токен не логировать).
  static String authorizationHeader(String token) =>
      'Bearer ${normalizeToken(token)}';
}
