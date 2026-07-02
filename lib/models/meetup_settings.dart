/// Настройки ежедневного митапа: [minutesPerDay] — целевой итог в день
/// (уже в YouTrack + новый план), не «добавить сверху».
class MeetupSettings {
  const MeetupSettings({
    this.enabled = false,
    this.issueIdReadable = '',
    this.minutesPerDay = 60,
    this.startDate,
    this.endDate,
  });

  final bool enabled;
  final String issueIdReadable;
  final int minutesPerDay;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isConfigured =>
      enabled && issueIdReadable.trim().isNotEmpty && minutesPerDay > 0;

  MeetupSettings copyWith({
    bool? enabled,
    String? issueIdReadable,
    int? minutesPerDay,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) =>
      MeetupSettings(
        enabled: enabled ?? this.enabled,
        issueIdReadable: issueIdReadable ?? this.issueIdReadable,
        minutesPerDay: minutesPerDay ?? this.minutesPerDay,
        startDate: clearStartDate ? null : (startDate ?? this.startDate),
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'issueIdReadable': issueIdReadable.trim(),
        'minutesPerDay': minutesPerDay,
        if (startDate != null) 'startDate': _fmt(startDate!),
        if (endDate != null) 'endDate': _fmt(endDate!),
      };

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
