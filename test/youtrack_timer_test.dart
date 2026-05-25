import 'package:test/test.dart';
import 'package:youtrack_timer/utils/date_utils.dart';

void main() {
  test('parseDate корректно разбирает yyyy-MM-dd', () {
    final date = DateUtils.parseDate('2024-06-15');
    expect(date.year, 2024);
    expect(date.month, 6);
    expect(date.day, 15);
  });
}
