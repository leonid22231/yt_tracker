import 'package:test/test.dart';
import 'package:youtrack_timer/logging/log_sanitizer.dart';

void main() {
  test('маскирует perm-токен', () {
    final s = LogSanitizer.sanitize('token=perm:secret123abc');
    expect(s, isNot(contains('secret123')));
    expect(s, contains('***'));
  });
}
