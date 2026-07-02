import 'package:flutter/material.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';

/// Календарь выбора даты с локалью приложения (ru).
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  bool Function(DateTime day)? selectableDayPredicate,
}) {
  return showDatePicker(
    context: context,
    locale: const Locale('ru'),
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    selectableDayPredicate: selectableDayPredicate,
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
      ),
      child: child!,
    ),
  );
}
