import 'package:flutter/material.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';

/// Индикатор статуса подключения.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = ok ? p.success : p.warning;

    if (p.isOneC) {
      return DecoratedBox(
        decoration: OneCDecorations.raised(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: p.textPrimary),
                ),
              ),
              Icon(
                ok ? Icons.check_box : Icons.indeterminate_check_box,
                size: 14,
                color: color,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 16,
            color: color,
          ),
        ],
      ),
    );
  }
}
