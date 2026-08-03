import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/app_date_picker.dart';

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
    final p = context.palette;
    final fmt = DateFormat('d MMM yyyy', 'ru');

    return Row(
      children: [
        Expanded(
          child: _DateChip(
            palette: p,
            label: 'Начало',
            value: start != null ? fmt.format(start!) : '—',
            onTap: enabled ? () => _pick(context, isStart: true) : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.arrow_forward,
            size: p.isOneC ? 14 : 16,
            color: p.textMuted,
          ),
        ),
        Expanded(
          child: _DateChip(
            palette: p,
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
    final picked = await showAppDatePicker(
      context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    required this.palette,
    required this.label,
    required this.value,
    this.onTap,
  });

  final VariantPalette palette;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (palette.isOneC) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: OneCDecorations.sunken(palette),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: onTap != null
                              ? palette.textPrimary
                              : palette.textMuted,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.event,
                      size: 14,
                      color: onTap != null ? palette.link : palette.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.event,
                    size: 14,
                    color: onTap != null ? AppColors.primary : AppColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
