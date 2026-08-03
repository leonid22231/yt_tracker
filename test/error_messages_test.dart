import 'package:test/test.dart';
import 'package:youtrack_timer/ui/utils/error_messages.dart';

void main() {
  test('timeout error is shortened with host', () {
    const raw =
        'ClientException with SocketException: The semaphore timeout period has expired '
        '(OS Error: The semaphore timeout period has expired, errno = 121), '
        'address = gitlab.evosoft.xyz, port = 9349, '
        'uri=https://gitlab.evosoft.xyz/api/v4/user?fields=id';

    final msg = UserErrorMessage.fromRaw(raw);
    expect(msg.title, contains('gitlab.evosoft.xyz'));
    expect(msg.title, contains('время ожидания'));
    expect(msg.title.length, lessThan(120));
    expect(msg.detail, isNotNull);
  });

  test('short API message is kept as-is', () {
    const raw = 'Укажите GitLab token в настройках';
    final msg = UserErrorMessage.fromRaw(raw);
    expect(msg.title, raw);
    expect(msg.detail, isNull);
  });
}
