/// Форматирование минут и часов для UI.
abstract final class TimeFormat {
  static String minutes(int minutes) {
    if (minutes <= 0) return '0м';
    if (minutes < 60) return '$minutesм';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$hч' : '$hч $mм';
  }

  static String hours(double hours, {bool compact = false}) {
    if (hours <= 0) return compact ? '0ч' : '0 ч';
    if (hours == hours.roundToDouble()) {
      return compact ? '${hours.round()}ч' : '${hours.round()} ч';
    }
    return compact ? '${hours.toStringAsFixed(1)}ч' : '${hours.toStringAsFixed(1)} ч';
  }

  static double minutesToSliderHours(int minutes) =>
      (minutes / 15).round() * 15 / 60.0;

  static int sliderHoursToMinutes(double hours) =>
      ((hours * 4).round() * 15).clamp(0, 12 * 60);
}
