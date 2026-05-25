import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Полоски по дням: сколько минут из 480 запланировано.
class DaySummaryBar extends StatelessWidget {
  const DaySummaryBar({
    super.key,
    required this.dayTotals,
    required this.targetMinutes,
  });

  final Map<DateTime, int> dayTotals;
  final int targetMinutes;

  @override
  Widget build(BuildContext context) {
    final sorted = dayTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Часы по дням (цель: ${targetMinutes ~/ 60}ч)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            ...sorted.map((e) {
              final ratio = (e.value / targetMinutes).clamp(0.0, 1.0);
              final ok = e.value == targetMinutes;
              final fmt = DateFormat('EEE dd.MM', 'ru');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        fmt.format(e.key),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: Colors.white10,
                          color: ok
                              ? Colors.greenAccent
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${e.value}м',
                        style: TextStyle(
                          fontSize: 11,
                          color: ok ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
