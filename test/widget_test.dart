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
}
