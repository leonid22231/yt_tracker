/// Нормализация URL и токена GitLab.
class GitLabCredentials {
  static String normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    trimmed = trimmed.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError('Некорректный URL GitLab: $url');
    }
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  static String normalizeToken(String token) => token.trim();

  static Map<String, String> headers(String token) => {
        'PRIVATE-TOKEN': normalizeToken(token),
        'Accept': 'application/json',
      };
}
