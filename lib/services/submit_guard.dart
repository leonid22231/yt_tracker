/// Защита от случайной записи в YouTrack.
class SubmitGuardException implements Exception {
  SubmitGuardException(this.message);
  final String message;

  @override
  String toString() => 'SubmitGuardException: $message';
}

class SubmitGuard {
  /// Проверка перед реальной записью work items.
  static void ensureWriteAllowed({
    required bool dryRunEnabled,
    required bool userConfirmed,
  }) {
    if (dryRunEnabled) {
      throw SubmitGuardException(
        'Запись заблокирована: в настройках включён Dry-run. '
        'Выключите Dry-run для записи в YouTrack.',
      );
    }
    if (!userConfirmed) {
      throw SubmitGuardException(
        'Запись заблокирована: нет подтверждения пользователя.',
      );
    }
  }

  /// Проверка, что вызов идёт только в режиме просмотра.
  static void ensurePreviewOnly({required bool previewMode}) {
    if (!previewMode) {
      throw SubmitGuardException('Внутренняя ошибка: ожидался режим preview.');
    }
  }
}
