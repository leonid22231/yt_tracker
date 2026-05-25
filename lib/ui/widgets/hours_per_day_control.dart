import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/labeled_slider.dart';

/// Норма часов в рабочий день (пересчёт только после отпускания ползунка).
class HoursPerDayControl extends ConsumerStatefulWidget {
  const HoursPerDayControl({super.key});

  @override
  ConsumerState<HoursPerDayControl> createState() => _HoursPerDayControlState();
}

class _HoursPerDayControlState extends ConsumerState<HoursPerDayControl> {
  double? _localHours;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final display = _dragging ? _localHours! : home.hoursPerWorkDay;

    return LabeledSlider(
      label: 'Рабочий день',
      subtitle: 'Отпустите ползунок — тогда пересчёт плана',
      value: display,
      min: 1,
      max: 12,
      divisions: 22,
      valueLabel: TimeFormat.hours(display),
      enabled: !home.isLoading,
      accentColor: Theme.of(context).colorScheme.secondary,
      onChanged: (v) {
        setState(() {
          _dragging = true;
          _localHours = v;
        });
        ref.read(homeProvider.notifier).setHoursPerWorkDay(v);
      },
      onChangeEnd: (v) {
        setState(() {
          _dragging = false;
          _localHours = null;
        });
        ref
            .read(homeProvider.notifier)
            .setHoursPerWorkDay(v, scheduleRecalc: true);
      },
    );
  }
}
