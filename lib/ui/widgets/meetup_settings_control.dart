import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/meetup_settings.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/utils/app_date_picker.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/utils/date_utils.dart' as yt_date;

/// Настройки ежедневного митапа: задача и минуты в день.
class MeetupSettingsControl extends ConsumerStatefulWidget {
  const MeetupSettingsControl({super.key});

  @override
  ConsumerState<MeetupSettingsControl> createState() =>
      _MeetupSettingsControlState();
}

class _MeetupSettingsControlState extends ConsumerState<MeetupSettingsControl> {
  late final TextEditingController _issueCtrl;
  double? _localHours;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _issueCtrl = TextEditingController(
      text: ref.read(homeProvider).meetupSettings.issueIdReadable,
    );
  }

  @override
  void dispose() {
    _issueCtrl.dispose();
    super.dispose();
  }

  void _apply(MeetupSettings settings, {bool scheduleRecalc = false}) {
    ref
        .read(homeProvider.notifier)
        .setMeetupSettings(settings, scheduleRecalc: scheduleRecalc);
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final meetup = home.meetupSettings;
    final notifier = ref.read(homeProvider.notifier);
    final hours = meetup.minutesPerDay / 60;
    final display = _dragging ? _localHours! : hours;
    final fmt = DateFormat('d MMM', 'ru');
    final excluded = meetup.excludedDates.toList()..sort((a, b) => a.compareTo(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_outlined,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Митап',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Switch(
              value: meetup.enabled,
              onChanged: home.isLoading
                  ? null
                  : (v) => _apply(meetup.copyWith(enabled: v)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        if (meetup.enabled) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _issueCtrl,
            enabled: !home.isLoading,
            style: const TextStyle(fontSize: 12),
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) =>
                _apply(meetup.copyWith(issueIdReadable: v.trim())),
            decoration: const InputDecoration(
              hintText: 'Задача митапа (PROJ-123)',
              isDense: true,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  TimeFormat.hours(display),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                'в день',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
          Slider(
            value: display.clamp(0.5, 4.0),
            min: 0.5,
            max: 4,
            divisions: 7,
            label: TimeFormat.hours(display),
            onChanged: home.isLoading
                ? null
                : (v) {
                    setState(() {
                      _dragging = true;
                      _localHours = v;
                    });
                    _apply(
                      meetup.copyWith(minutesPerDay: (v * 60).round()),
                      scheduleRecalc: false,
                    );
                  },
            onChangeEnd: home.isLoading
                ? null
                : (v) {
                    setState(() {
                      _dragging = false;
                      _localHours = null;
                    });
                    _apply(
                      meetup.copyWith(minutesPerDay: (v * 60).round()),
                      scheduleRecalc: true,
                    );
                  },
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Без митапа',
                  style: TextStyle(
                    fontSize: 11,
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
                    : () => _pickExcludedDate(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Добавить'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          if (excluded.isEmpty)
            const Text(
              'Напр. отпуск на митап, но работа по задачам остаётся',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in excluded)
                  InputChip(
                    label: Text(fmt.format(d)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: home.isLoading
                        ? null
                        : () => notifier.removeMeetupExcludedDate(d),
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          const SizedBox(height: 4),
          const Text(
            'Целевое время в день (с учётом уже списанного в YT)',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  Future<void> _pickExcludedDate(BuildContext context) async {
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
    ref.read(homeProvider.notifier).addMeetupExcludedDate(picked);
  }
}
