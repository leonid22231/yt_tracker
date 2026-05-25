/// Текущий пользователь YouTrack (из /api/users/me).
class YouTrackUser {
  YouTrackUser({
    required this.id,
    required this.login,
    this.name,
  });

  final String id;
  final String login;
  final String? name;
}
