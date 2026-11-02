/// Нормализация HTTP-прокси для Cursor Cloud Agents API.
///
/// Принимает `host:port`, `http://host:port`, `https://host:port`.
/// Возвращает канонический `host:port` или `null`, если строка пустая.
class CursorProxy {
  CursorProxy._();

  /// Нормализует значение прокси. Пустая строка → `null`.
  ///
  /// Бросает [ArgumentError], если формат не `host:port`.
  static String? normalize(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    var hostPort = trimmed.replaceFirst(
      RegExp(r'^https?://', caseSensitive: false),
      '',
    );
    // отрезаем path / query, если вставили URL целиком
    hostPort = hostPort.split('/').first.split('?').first;
    if (hostPort.contains('@')) {
      hostPort = hostPort.split('@').last;
    }

    final match =
        RegExp(r'^(\[[^\]]+\]|[^:\s]+):(\d{1,5})$').firstMatch(hostPort);
    if (match == null) {
      throw ArgumentError(
        'Прокси Cursor: ожидается host:port '
        '(например 127.0.0.1:7890), получено "$raw"',
      );
    }

    final host = match.group(1)!;
    final port = int.parse(match.group(2)!);
    if (port < 1 || port > 65535) {
      throw ArgumentError(
        'Прокси Cursor: порт вне диапазона 1–65535 ($port)',
      );
    }
    if (host == '[]' || host == 'http' || host == 'https') {
      throw ArgumentError(
        'Прокси Cursor: некорректный host в "$raw"',
      );
    }

    return '$host:$port';
  }

  /// Директива для [HttpClient.findProxy]: `PROXY host:port`.
  static String findProxyDirective(String hostPort) => 'PROXY $hostPort';
}
