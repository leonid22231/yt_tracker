import 'package:flutter_test/flutter_test.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

void main() {
  test('рабочие дни исключают выходные', () {
    final days = DateUtils.workingDays(
      DateTime(2024, 1, 1),
      DateTime(2024, 1, 7),
    );
    expect(days.length, 5);
  });

  test('activeWorkingDays исключает заданные даты', () {
    final excluded = {DateTime(2024, 1, 3), DateTime(2024, 1, 5)};
    final days = DateUtils.activeWorkingDays(
      DateTime(2024, 1, 1),
      DateTime(2024, 1, 7),
      excludedDates: excluded,
    );
    expect(days.length, 3);
    expect(days.any((d) => d.day == 3), isFalse);
    expect(days.any((d) => d.day == 5), isFalse);
  });
}
