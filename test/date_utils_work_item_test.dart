import 'package:test/test.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

void main() {
  test('parseWorkItemDate не сдвигает день при UTC midnight', () {
    // 2024-05-04 00:00:00 UTC
    final ms = DateTime.utc(2024, 5, 4).millisecondsSinceEpoch;
    final d = DateUtils.parseWorkItemDate(ms);
    expect(d.year, 2024);
    expect(d.month, 5);
    expect(d.day, 4);
  });
}
