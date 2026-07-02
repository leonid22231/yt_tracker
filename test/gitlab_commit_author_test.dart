import 'package:test/test.dart';
import 'package:youtrack_timer/gitlab/gitlab_commit_author.dart';
import 'package:youtrack_timer/models/gitlab/gitlab_user_info.dart';

void main() {
  const user = GitLabUserInfo(
    id: 42,
    username: 'ivanov',
    name: 'Ivan Ivanov',
    email: 'ivan@company.com',
    commitEmail: 'ivan@company.com',
  );

  test('принимает коммит с совпадающим author_email', () {
    expect(
      GitLabCommitAuthor.matches(user, {
        'author_email': 'ivan@company.com',
        'committer_email': 'other@company.com',
        'author_name': 'Someone',
      }),
      isTrue,
    );
  });

  test('принимает noreply-email self-hosted GitLab', () {
    expect(
      GitLabCommitAuthor.matches(
        user,
        {
          'author_email': '42+ivanov@users.noreply.gitlab.evosoft.xyz',
          'committer_email': '',
          'author_name': 'ivanov',
        },
        gitlabHost: 'gitlab.evosoft.xyz',
      ),
      isTrue,
    );
  });

  test('принимает коммиты из MR пользователя без совпадения email', () {
    expect(
      GitLabCommitAuthor.matches(
        user,
        {
          'author_email': 'other@unknown.com',
          'author_name': 'Other',
        },
        fromUserMergeRequest: true,
      ),
      isTrue,
    );
  });

  test('отклоняет чужой коммит', () {
    expect(
      GitLabCommitAuthor.matches(user, {
        'author_email': 'petrov@company.com',
        'committer_email': 'petrov@company.com',
        'author_name': 'Petrov',
        'committer_name': 'Petrov',
      }),
      isFalse,
    );
  });

  test('не принимает совпадение только по task id в сообщении без автора', () {
    expect(
      GitLabCommitAuthor.matches(user, {
        'author_email': 'colleague@company.com',
        'committer_email': 'colleague@company.com',
        'author_name': 'Colleague',
        'message': 'KIOSK-100 fix',
      }),
      isFalse,
    );
  });
}
