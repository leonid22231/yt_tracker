/// Разбор оценки задачи из customFields YouTrack (поле типа Period).
class IssueEstimateParser {
  /// Имена полей «потрачено» — не путать с оценкой.
  static final _spentNamePatterns = [
    RegExp(r'spent', caseSensitive: false),
    RegExp(r'потрач', caseSensitive: false),
    RegExp(r'затрачен', caseSensitive: false),
  ];

  /// Имена полей оценки (приоритет — точное совпадение в [_exactEstimateNames]).
  static final _estimateNamePatterns = [
    RegExp(r'estimat', caseSensitive: false),
    RegExp(r'оценк', caseSensitive: false),
    RegExp(r'estimate', caseSensitive: false),
  ];

  static const _exactEstimateNames = {
    'estimation',
    'estimate',
    'оценка',
    'оценка времени',
    'time estimate',
  };

  /// Из списка customFields API возвращает минуты оценки и подпись, если найдено.
  static ({int? minutes, String? presentation, String? fieldName}) parse(
    List<dynamic>? customFieldsRaw,
  ) {
    if (customFieldsRaw == null || customFieldsRaw.isEmpty) {
      return (minutes: null, presentation: null, fieldName: null);
    }

    final candidates = <_PeriodField>[];
    for (final raw in customFieldsRaw) {
      if (raw is! Map<String, dynamic>) continue;
      final field = _PeriodField.tryParse(raw);
      if (field != null) candidates.add(field);
    }

    if (candidates.isEmpty) {
      return (minutes: null, presentation: null, fieldName: null);
    }

    final estimateFields =
        candidates.where((f) => !_isSpentField(f.name)).toList();
    if (estimateFields.isEmpty) {
      return (minutes: null, presentation: null, fieldName: null);
    }

    final exact = estimateFields.where(
      (f) => _exactEstimateNames.contains(f.name.toLowerCase().trim()),
    );
    final chosen = exact.isNotEmpty
        ? exact.first
        : estimateFields.firstWhere(
            (f) => _estimateNamePatterns.any((p) => p.hasMatch(f.name)),
            orElse: () => estimateFields.first,
          );

    return (
      minutes: chosen.minutes,
      presentation: chosen.presentation,
      fieldName: chosen.name,
    );
  }

  static bool _isSpentField(String name) {
    final lower = name.toLowerCase();
    return _spentNamePatterns.any((p) => p.hasMatch(lower));
  }
}

class _PeriodField {
  _PeriodField({
    required this.name,
    required this.minutes,
    this.presentation,
  });

  final String name;
  final int minutes;
  final String? presentation;

  static _PeriodField? tryParse(Map<String, dynamic> map) {
    final type = map[r'$type'] as String? ?? '';
    if (!type.contains('Period')) return null;

    final name = map['name'] as String?;
    if (name == null || name.isEmpty) return null;

    final value = map['value'];
    if (value is! Map<String, dynamic>) return null;

    final minutes = value['minutes'];
    if (minutes is! int || minutes <= 0) return null;

    return _PeriodField(
      name: name,
      minutes: minutes,
      presentation: value['presentation'] as String?,
    );
  }
}
