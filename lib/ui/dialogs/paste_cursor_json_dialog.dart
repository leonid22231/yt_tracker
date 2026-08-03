import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/ui/widgets/business/one_c_dialog.dart';
import 'package:youtrack_timer/utils/date_utils.dart' as yt_date;

/// Скрытый диалог: период уже выбран → вставить JSON Cursor → быстрый план.
class PasteCursorJsonDialog extends ConsumerStatefulWidget {
  const PasteCursorJsonDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const PasteCursorJsonDialog(),
    );
  }

  @override
  ConsumerState<PasteCursorJsonDialog> createState() =>
      _PasteCursorJsonDialogState();
}

class _PasteCursorJsonDialogState extends ConsumerState<PasteCursorJsonDialog> {
  final _ctrl = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _ctrl.text = text;
      _error = null;
    });
  }

  Future<void> _apply() async {
    final home = ref.read(homeProvider);
    if (home.startDate == null || home.endDate == null) {
      setState(() => _error = 'Сначала выберите период слева');
      return;
    }
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Вставьте JSON с полем estimates');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    // Закрываем диалог сразу: прогресс идёт в журнале / статус-баре.
    if (mounted) Navigator.of(context).pop();

    try {
      await ref.read(homeProvider.notifier).buildPlanFromCursorJson(text);
    } catch (_) {
      // Ошибка уже в логах / statusMessage.
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final periodLabel = home.startDate != null && home.endDate != null
        ? '${yt_date.DateUtils.formatForQuery(home.startDate!)} — '
            '${yt_date.DateUtils.formatForQuery(home.endDate!)}'
        : 'период не выбран';

    return OneCAwareDialog(
      title: 'План из JSON Cursor',
      icon: Icons.data_object_outlined,
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Период: $periodLabel\n'
              'YouTrack загрузит задачи за период, план соберётся из вашего JSON '
              'без ожидания Cursor Agent.',
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              maxLines: 14,
              minLines: 8,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
              decoration: const InputDecoration(
                hintText: '{\n  "summary": "...",\n  "estimates": [ ... ]\n}',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        VariantDialogButton(
          label: 'Из буфера',
          onPressed: _busy ? null : _pasteFromClipboard,
        ),
        VariantDialogButton(
          label: 'Отмена',
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        VariantDialogButton(
          label: _busy ? '…' : 'Сформировать',
          primary: true,
          onPressed: _busy ? null : _apply,
        ),
      ],
    );
  }
}
