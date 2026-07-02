/// Информация о подключённом пользователе GitLab.
class GitLabUserInfo {
  const GitLabUserInfo({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.publicEmail = '',
    this.commitEmail = '',
    this.avatarUrl = '',
  });

  final int id;
  final String username;
  final String name;
  final String email;
  final String publicEmail;
  final String commitEmail;
  final String avatarUrl;

  String get displayName => name.isNotEmpty ? name : username;

  /// Все email, которыми пользователь может подписывать коммиты.
  Iterable<String> get knownEmails sync* {
    for (final raw in [email, publicEmail, commitEmail]) {
      final v = raw.trim().toLowerCase();
      if (v.isNotEmpty) yield v;
    }
    if (username.isNotEmpty) {
      yield '$id+$username@users.noreply.gitlab.com';
      yield '$username@users.noreply.gitlab.com';
    }
  }

  /// С учётом noreply-домена self-hosted GitLab (например gitlab.evosoft.xyz).
  Iterable<String> knownEmailsForHost(String? host) sync* {
    yield* knownEmails;
    final h = host?.trim().toLowerCase();
    if (username.isNotEmpty && h != null && h.isNotEmpty) {
      yield '$id+$username@users.noreply.$h';
      yield '$username@users.noreply.$h';
    }
  }
}
