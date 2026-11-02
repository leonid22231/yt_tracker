import 'package:test/test.dart';
import 'package:youtrack_timer/services/user_hint_meetup_parser.dart';

void main() {
  group('UserHintMeetupParser', () {
    test('МИТАП 1Ч KIOSK-114', () {
      final m = UserHintMeetupParser.parse('МИТАП 1Ч KIOSK-114');
      expect(m, isNotNull);
      expect(m!.isConfigured, isTrue);
      expect(m.issueIdReadable, 'KIOSK-114');
      expect(m.minutesPerDay, 60);
    });

    test('митап 1 ч на KIOSK-114', () {
      final m = UserHintMeetupParser.parse('митап 1 ч на KIOSK-114');
      expect(m!.issueIdReadable, 'KIOSK-114');
      expect(m.minutesPerDay, 60);
    });

    test('KIOSK-114 meetup 90м', () {
      final m = UserHintMeetupParser.parse('KIOSK-114 meetup 90м');
      expect(m!.issueIdReadable, 'KIOSK-114');
      expect(m.minutesPerDay, 90);
    });

    test('митапы по 2ч PROJ-1', () {
      final m = UserHintMeetupParser.parse('митапы по 2ч PROJ-1');
      expect(m!.issueIdReadable, 'PROJ-1');
      expect(m.minutesPerDay, 120);
    });

    test('без слова митап → null', () {
      expect(UserHintMeetupParser.parse('KIOSK-114 1ч'), isNull);
    });

    test('без id → null', () {
      expect(UserHintMeetupParser.parse('митап 1ч'), isNull);
    });

    test('без длительности → null', () {
      expect(UserHintMeetupParser.parse('митап KIOSK-114'), isNull);
    });
  });
}
