/// Краткое сообщение об ошибке для UI (полный текст — в журнал / «Подробнее»).
class UserErrorMessage {
  const UserErrorMessage({
    required this.title,
    this.detail,
  });

  final String title;
  final String? detail;

  factory UserErrorMessage.fromRaw(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const UserErrorMessage(title: 'Неизвестная ошибка');
    }

    final lower = text.toLowerCase();
    final host = _extractHost(text);

    if (lower.contains('semaphore timeout') ||
        lower.contains('connection timed out') ||
        lower.contains('timed out')) {
      return UserErrorMessage(
        title: host != null
            ? 'Не удалось подключиться к $host: истекло время ожидания'
            : 'Истекло время ожидания сетевого запроса',
        detail: _shortDetail(text),
      );
    }

    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused')) {
      return UserErrorMessage(
        title: host != null
            ? 'Нет связи с $host. Проверьте сеть и VPN'
            : 'Ошибка сетевого подключения',
        detail: _shortDetail(text),
      );
    }

    if (lower.contains('handshake') || lower.contains('certificate')) {
      return UserErrorMessage(
        title: 'Ошибка SSL/TLS при подключении',
        detail: _shortDetail(text),
      );
    }

    if (lower.contains('401') || lower.contains('unauthorized')) {
      return UserErrorMessage(
        title: 'Неверный токен или нет доступа',
        detail: _shortDetail(text),
      );
    }

    if (lower.contains('403') || lower.contains('forbidden')) {
      return UserErrorMessage(
        title: 'Доступ запрещён',
        detail: _shortDetail(text),
      );
    }

    if (lower.contains('404') || lower.contains('not found')) {
      return UserErrorMessage(
        title: 'Ресурс не найден',
        detail: _shortDetail(text),
      );
    }

    // Уже короткое сообщение от API — показываем как есть.
    if (!text.contains('\n') && text.length <= 120) {
      return UserErrorMessage(title: text);
    }

    final firstLine = text.split('\n').first.trim();
    if (firstLine.length <= 120) {
      return UserErrorMessage(title: firstLine, detail: text);
    }

    return UserErrorMessage(
      title: 'Произошла ошибка',
      detail: text,
    );
  }
}

String? _extractHost(String text) {
  final uriMatch = RegExp(r'uri=https?://([^/\s?]+)').firstMatch(text);
  if (uriMatch != null) return uriMatch.group(1);

  final addressMatch = RegExp(r'address = ([^,\s]+)').firstMatch(text);
  if (addressMatch != null) return addressMatch.group(1);

  return null;
}

String _shortDetail(String text) {
  if (text.length <= 280) return text;
  return '${text.substring(0, 277)}…';
}
