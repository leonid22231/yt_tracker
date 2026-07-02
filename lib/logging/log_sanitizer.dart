/// Маскирует токены и ключи в тексте логов.
class LogSanitizer {
  static final _patterns = [
    RegExp(r'perm:[\w-]+', caseSensitive: false),
    RegExp(r'Bearer\s+[\w:.+-]+', caseSensitive: false),
    RegExp(r'cursor_[\w-]+', caseSensitive: false),
    RegExp(r'glpat-[\w-]+', caseSensitive: false),
    RegExp(r'PRIVATE-TOKEN\s+[\w-]+', caseSensitive: false),
    RegExp(
      r'(YOUTRACK_TOKEN|CURSOR_API_KEY|GITLAB_TOKEN|token|apiKey|api_key)\s*[=:]\s*\S+',
      caseSensitive: false,
    ),
  ];

  static String sanitize(String input) {
    var result = input;
    for (final pattern in _patterns) {
      result = result.replaceAllMapped(pattern, (m) {
        final value = m.group(0)!;
        if (value.contains('=') || value.contains(':')) {
          final sep = value.contains('=') ? '=' : ':';
          final parts = value.split(sep);
          return '${parts.first}$sep***';
        }
        return '***';
      });
    }
    return result;
  }
}
