import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/utils/app_date_picker.dart';
import 'package:youtrack_timer/utils/date_utils.dart' as yt_date;

/// Выбор рабочих дат, исключённых из расчёта плана.
class ExcludedDatesControl extends ConsumerWidget {
  const ExcludedDatesControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final notifier = ref.read(homeProvider.notifier);
    final fmt = DateFormat('d MMM', 'ru');
    final sorted = home.excludedDates.toList()
      ..sort((a, b) => a.compareTo(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.event_busy_outlined,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Исключить даты',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: home.isLoading ||
                      home.startDate == null ||
                      home.endDate == null
                  ? null
                  : () => _pickDate(context, ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Добавить'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        if (sorted.isEmpty)
          const Text(
            'Напр. 14 и 16 число — не трекать эти рабочие дни',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in sorted)
                InputChip(
                  label: Text(fmt.format(d)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: home.isLoading
                      ? null
                      : () => notifier.removeExcludedDate(d),
                  visualDensity: VisualDensity.compact,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final home = ref.read(homeProvider);
    final start = home.startDate!;
    final end = home.endDate!;

    final picked = await showAppDatePicker(
      context,
      initialDate: start,
      firstDate: start,
      lastDate: end,
      selectableDayPredicate: (day) {
        final only = yt_date.DateUtils.dateOnly(day);
        return !only.isBefore(yt_date.DateUtils.dateOnly(start)) &&
            !only.isAfter(yt_date.DateUtils.dateOnly(end)) &&
            day.weekday >= DateTime.monday &&
            day.weekday <= DateTime.friday;
      },
    );
    if (picked == null) return;
    ref.read(homeProvider.notifier).addExcludedDate(picked);
  }
}
