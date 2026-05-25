import 'package:test/test.dart';
import 'package:youtrack_timer/youtrack/youtrack_credentials.dart';

void main() {
  group('YouTrackCredentials', () {
    test('убирает /api из URL', () {
      expect(
        YouTrackCredentials.normalizeBaseUrl(
          'https://company.youtrack.cloud/api/',
        ),
        'https://company.youtrack.cloud',
      );
    });

    test('добавляет perm: к токену', () {
      expect(
        YouTrackCredentials.normalizeToken('abc123'),
        'perm:abc123',
      );
    });

    test('добавляет https если нет схемы', () {
      expect(
        YouTrackCredentials.normalizeBaseUrl('company.youtrack.cloud'),
        'https://company.youtrack.cloud',
      );
    });
  });
}
