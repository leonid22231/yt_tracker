import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';

/// Подсказка пользователя для Cursor Agent при пересчёте.
class RecalcHintField extends ConsumerStatefulWidget {
  const RecalcHintField({super.key});

  @override
  ConsumerState<RecalcHintField> createState() => _RecalcHintFieldState();
}

class _RecalcHintFieldState extends ConsumerState<RecalcHintField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(homeProvider).recalcHint);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text(
              'Подсказка для AI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 12),
          onChanged: ref.read(homeProvider.notifier).setRecalcHint,
          decoration: const InputDecoration(
            hintText:
                'Напр.: 5 мая без PLG-2296, время на KIOSK-114 или любую старую задачу',
            isDense: true,
            contentPadding: EdgeInsets.all(12),
          ),
        ),
        const Text(
          'Учитывается при пересчёте и исключении задач',
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
