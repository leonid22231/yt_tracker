import 'package:youtrack_timer/models/gitlab/gitlab_user_info.dart';

/// Сопоставление коммита GitLab с текущим пользователем.
abstract final class GitLabCommitAuthor {
  static bool matches(
    GitLabUserInfo user,
    Map<String, dynamic> commit, {
    String? gitlabHost,
    bool fromUserMergeRequest = false,
  }) {
    if (fromUserMergeRequest) return true;

    final authorEmail = _norm(commit['author_email']);
    final committerEmail = _norm(commit['committer_email']);

    for (final email in user.knownEmailsForHost(gitlabHost)) {
      if (email == authorEmail || email == committerEmail) return true;
    }

    final authorName = _norm(commit['author_name']);
    final committerName = _norm(commit['committer_name']);
    final userName = _norm(user.name);
    final username = _norm(user.username);

    if (username.isNotEmpty &&
        (authorName == username || committerName == username)) {
      return true;
    }
    if (userName.isNotEmpty &&
        (authorName == userName || committerName == userName)) {
      return true;
    }

    return false;
  }

  static String _norm(dynamic value) =>
      (value as String? ?? '').trim().toLowerCase();
}
