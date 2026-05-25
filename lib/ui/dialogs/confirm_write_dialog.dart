import 'package:flutter/material.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/utils/date_utils.dart' as yt_date;

/// Диалог подтверждения записи в YouTrack.
class ConfirmWriteDialog extends StatefulWidget {
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
  State<ConfirmWriteDialog> createState() => _ConfirmWriteDialogState();
}

class _ConfirmWriteDialogState extends State<ConfirmWriteDialog> {
  var _confirmed = false;

  int get _totalMinutes =>
      widget.plan.entries.fold(0, (s, e) => s + e.minutes);

  @override
  Widget build(BuildContext context) {
    final period =
        '${yt_date.DateUtils.formatForQuery(widget.startDate)} — '
        '${yt_date.DateUtils.formatForQuery(widget.endDate)}';

    return AlertDialog(
      icon: const Icon(Icons.warning_amber, color: Colors.orangeAccent),
      title: const Text('Записать в YouTrack?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Будут созданы work items в вашем инстансе YouTrack. '
              'Отменить автоматически нельзя.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            _row('Период', period),
            _row('Записей', '${widget.plan.entries.length}'),
            _row('Суммарно', '${_totalMinutes ~/ 60} ч ${_totalMinutes % 60} м'),
            _row('Задач', '${widget.plan.issues.length}'),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Я понимаю, данные будут записаны в YouTrack',
                style: TextStyle(fontSize: 13),
              ),
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
          ),
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: const Text('Записать'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
