import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/meetup_settings.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
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
    final hours = meetup.minutesPerDay / 60;
    final display = _dragging ? _localHours! : hours;
    final fmt = DateFormat('d MMM', 'ru');

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
              Expanded(
                child: _RangeChip(
                  label: 'С',
                  value: meetup.startDate != null
                      ? fmt.format(meetup.startDate!)
                      : 'начала',
                  onTap: home.isLoading
                      ? null
                      : () => _pickRangeDate(isStart: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RangeChip(
                  label: 'По',
                  value: meetup.endDate != null
                      ? fmt.format(meetup.endDate!)
                      : 'конца',
                  onTap: home.isLoading
                      ? null
                      : () => _pickRangeDate(isStart: false),
                ),
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

  Future<void> _pickRangeDate({required bool isStart}) async {
    final home = ref.read(homeProvider);
    if (home.startDate == null || home.endDate == null) return;
    final meetup = home.meetupSettings;

    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (meetup.startDate ?? home.startDate!)
          : (meetup.endDate ?? home.endDate!),
      firstDate: home.startDate!,
      lastDate: home.endDate!,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    final only = yt_date.DateUtils.dateOnly(picked);
    if (isStart) {
      _apply(
        meetup.copyWith(
          startDate: only,
          endDate: meetup.endDate != null && meetup.endDate!.isBefore(only)
              ? only
              : meetup.endDate,
        ),
      );
    } else {
      _apply(
        meetup.copyWith(
          endDate: only,
          startDate: meetup.startDate != null && meetup.startDate!.isAfter(only)
              ? only
              : meetup.startDate,
        ),
      );
    }
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
