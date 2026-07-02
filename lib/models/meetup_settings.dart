/// Настройки ежедневного митапа: [minutesPerDay] — целевой итог в день
/// (уже в YouTrack + новый план), не «добавить сверху».
class MeetupSettings {
  const MeetupSettings({
    this.enabled = false,
    this.issueIdReadable = '',
    this.minutesPerDay = 60,
    this.excludedDates = const {},
  });

  final bool enabled;
  final String issueIdReadable;
  final int minutesPerDay;

  /// Дни без митапа (план по остальным задачам в эти дни остаётся).
  final Set<DateTime> excludedDates;

  bool get isConfigured =>
      enabled && issueIdReadable.trim().isNotEmpty && minutesPerDay > 0;

  Set<DateTime> get normalizedExcludedDates =>
      excludedDates.map(_dateOnly).toSet();

  bool isDayExcluded(DateTime day) =>
      normalizedExcludedDates.contains(_dateOnly(day));

  MeetupSettings copyWith({
    bool? enabled,
    String? issueIdReadable,
    int? minutesPerDay,
    Set<DateTime>? excludedDates,
  }) =>
      MeetupSettings(
        enabled: enabled ?? this.enabled,
        issueIdReadable: issueIdReadable ?? this.issueIdReadable,
        minutesPerDay: minutesPerDay ?? this.minutesPerDay,
        excludedDates: excludedDates ?? this.excludedDates,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'issueIdReadable': issueIdReadable.trim(),
        'minutesPerDay': minutesPerDay,
        if (normalizedExcludedDates.isNotEmpty)
          'excludedDates': (normalizedExcludedDates.map(_fmt).toList()
            ..sort()),
      };

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
