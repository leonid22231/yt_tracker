import 'package:youtrack_timer/models/meetup_settings.dart';

/// Достаёт митап из свободного текста подсказки AI.
///
/// Примеры:
/// - `МИТАП 1Ч KIOSK-114`
/// - `митап 1 ч на KIOSK-114`
/// - `KIOSK-114 meetup 60м`
/// - `митапы по 2ч PROJ-1`
class UserHintMeetupParser {
  static final _meetupWord = RegExp(
    r'митап(?:ы|а|ов)?|meetup',
    caseSensitive: false,
  );
  static final _issueId = RegExp(
    r'\b([A-Z][A-Z0-9]+-\d+)\b',
    caseSensitive: false,
  );
  // В Dart `\b` — только ASCII word-boundary; после «ч»/«м» он не срабатывает.
  static final _hours = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:ч(?:ас(?:а|ов)?)?|h)(?!\w)',
    caseSensitive: false,
  );
  static final _minutes = RegExp(
    r'(\d+)\s*(?:мин(?:ут(?:ы|а|у)?)?|[мm])(?![a-zA-Zа-яА-Я])',
    caseSensitive: false,
  );

  /// Возвращает [MeetupSettings], если в тексте есть слово «митап/meetup»,
  /// id задачи и длительность. Иначе `null`.
  static MeetupSettings? parse(String? hint) {
    final text = hint?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!_meetupWord.hasMatch(text)) return null;

    final issueMatch = _issueId.firstMatch(text);
    if (issueMatch == null) return null;

    final minutes = _parseMinutes(text);
    if (minutes == null || minutes <= 0) return null;

    return MeetupSettings(
      enabled: true,
      issueIdReadable: issueMatch.group(1)!.toUpperCase(),
      minutesPerDay: minutes,
    );
  }

  static int? _parseMinutes(String text) {
    final hoursMatch = _hours.firstMatch(text);
    if (hoursMatch != null) {
      final raw = hoursMatch.group(1)!.replaceAll(',', '.');
      final hours = double.tryParse(raw);
      if (hours != null && hours > 0) {
        return (hours * 60).round();
      }
    }

    final minsMatch = _minutes.firstMatch(text);
    if (minsMatch != null) {
      final mins = int.tryParse(minsMatch.group(1)!);
      if (mins != null && mins > 0) return mins;
    }
    return null;
  }
}
