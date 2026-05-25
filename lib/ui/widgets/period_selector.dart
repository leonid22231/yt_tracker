import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';

/// Выбор периода «с — по».
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.enabled = true,
  });

  final DateTime? start;
  final DateTime? end;
  final void Function(DateTime start, DateTime end) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy', 'ru');

    return Row(
      children: [
        Expanded(
          child: _DateChip(
            label: 'Начало',
            value: start != null ? fmt.format(start!) : '—',
            onTap: enabled ? () => _pick(context, isStart: true) : null,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
        ),
        Expanded(
          child: _DateChip(
            label: 'Конец',
            value: end != null ? fmt.format(end!) : '—',
            onTap: enabled ? () => _pick(context, isStart: false) : null,
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, {required bool isStart}) async {
    final initial = isStart
        ? (start ?? DateTime.now())
        : (end ?? start ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

    if (isStart) {
      final e = end ?? picked;
      onChanged(picked, picked.isAfter(e) ? picked : e);
    } else {
      final s = start ?? picked;
      onChanged(picked.isBefore(s) ? picked : s, picked);
    }
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
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
