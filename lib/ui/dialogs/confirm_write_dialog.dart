import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/widgets/business/one_c_dialog.dart';
import 'package:youtrack_timer/utils/date_utils.dart' as yt_date;

/// Диалог подтверждения записи в YouTrack.
class ConfirmWriteDialog extends ConsumerStatefulWidget {
  const ConfirmWriteDialog({
    super.key,
    required this.plan,
    required this.startDate,
    required this.endDate,
  });

  final PlanBuildResult plan;
  final DateTime startDate;
  final DateTime endDate;

  static Future<bool> show(
    BuildContext context, {
    required PlanBuildResult plan,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmWriteDialog(
        plan: plan,
        startDate: startDate,
        endDate: endDate,
      ),
    );
    return result == true;
  }

  @override
  ConsumerState<ConfirmWriteDialog> createState() => _ConfirmWriteDialogState();
}

class _ConfirmWriteDialogState extends ConsumerState<ConfirmWriteDialog> {
  var _confirmed = false;

  int get _totalMinutes =>
      widget.plan.entries.fold(0, (s, e) => s + e.minutes);

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(designVariantProvider).palette;
    final period =
        '${yt_date.DateUtils.formatForQuery(widget.startDate)} — '
        '${yt_date.DateUtils.formatForQuery(widget.endDate)}';

    return OneCAwareDialog(
      icon: Icons.warning_amber,
      title: 'Записать в YouTrack?',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Будут созданы work items в вашем инстансе YouTrack. '
            'Отменить автоматически нельзя.',
            style: TextStyle(fontSize: 12, color: p.textSecondary),
          ),
          const SizedBox(height: 12),
          _row(p, 'Период', period),
          _row(p, 'Записей', '${widget.plan.entries.length}'),
          _row(p, 'Суммарно', '${_totalMinutes ~/ 60} ч ${_totalMinutes % 60} м'),
          _row(p, 'Задач', '${widget.plan.issues.length}'),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Я понимаю, данные будут записаны в YouTrack',
              style: TextStyle(fontSize: 11, color: p.textPrimary),
            ),
            value: _confirmed,
            onChanged: (v) => setState(() => _confirmed = v ?? false),
          ),
        ],
      ),
      actions: [
        VariantDialogButton(
          label: 'Отмена',
          onPressed: () => Navigator.pop(context, false),
        ),
        const SizedBox(width: 6),
        VariantDialogButton(
          label: 'Записать',
          primary: true,
          danger: true,
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
        ),
      ],
    );
  }

  Widget _row(VariantPalette p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: p.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
