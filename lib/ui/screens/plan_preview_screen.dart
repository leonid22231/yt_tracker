import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/models/plan_preview_entry.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/services/plan_preview_builder.dart';
import 'package:youtrack_timer/services/submit_service.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/preview/youtrack_calendar_cell.dart';
import 'package:youtrack_timer/ui/widgets/preview/youtrack_calendar_grid.dart';
import 'package:youtrack_timer/utils/open_external_url.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';
import 'package:youtrack_timer/youtrack/youtrack_links.dart';

/// Окно проверки плана — календарь как в YouTrack.
class PlanPreviewScreen extends ConsumerStatefulWidget {
  const PlanPreviewScreen({
    super.key,
    required this.plan,
    required this.entries,
    required this.startDate,
    required this.endDate,
    required this.baseUrl,
  });

  final PlanBuildResult plan;
  final List<PlannedEntry> entries;
  final DateTime startDate;
  final DateTime endDate;
  final String baseUrl;

  @override
  ConsumerState<PlanPreviewScreen> createState() => _PlanPreviewScreenState();
}

class _PlanPreviewScreenState extends ConsumerState<PlanPreviewScreen> {
  var _loading = true;
  String? _error;
  SubmitResult? _result;
  List<PlanPreviewDay> _days = [];
  List<List<PlanPreviewDay?>> _weekRows = [];

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final settings = ref.read(settingsProvider).valueOrNull;
      if (settings == null || !settings.hasYouTrack) {
        throw StateError('Нет настроек YouTrack');
      }

      final normalized = settings.normalized();
      final config = AppConfig(
        baseUrl: normalized.youTrackUrl,
        token: normalized.youTrackToken,
        startDate: widget.startDate,
        endDate: widget.endDate,
        dryRun: true,
      );

      final client = YouTrackClient(config);
      final detailed = await SubmitService(client).previewDetailed(
        entries: widget.entries,
      );
      client.close();

      if (!mounted) return;

      final statusMap = PlanPreviewBuilder.statusMapFromPreview(
        entries: widget.entries,
        skipKeys: detailed.skipKeys,
      );
      final days = PlanPreviewBuilder.buildDays(
        plan: widget.plan,
        entriesToCheck: widget.entries,
        plannedStatusByKey: statusMap,
      );

      setState(() {
        _result = detailed.result;
        _days = days;
        _weekRows = PlanPreviewBuilder.buildWeekRows(days);
        _loading = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _days = PlanPreviewBuilder.buildDays(
          plan: widget.plan,
          entriesToCheck: widget.entries,
        );
        _weekRows = PlanPreviewBuilder.buildWeekRows(_days);
      });
    }
  }

  void _onIssueTap(PlanPreviewRow row, PlanPreviewDay day) {
    final url = YouTrackLinks.issueUrl(widget.baseUrl, row.issueIdReadable);
    final fmt = DateFormat('d MMMM yyyy', 'ru');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                row.issueIdReadable,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                row.summary,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _detailLine('День', fmt.format(day.day)),
              if (row.existingMinutes > 0)
                _detailLine('Уже в YouTrack', TimeFormat.minutes(row.existingMinutes)),
              if (row.plannedMinutes > 0) ...[
                _detailLine(
                  'Новый план',
                  TimeFormat.minutes(row.plannedMinutes),
                ),
                _detailLine(
                  'При записи',
                  _statusLabel(row.plannedStatus),
                ),
              ],
              _detailLine('Итого за день', TimeFormat.minutes(row.totalMinutes)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _openIssue(url),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Открыть в YouTrack'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ссылка скопирована')),
                  );
                },
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Копировать ссылку'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(PreviewWriteStatus? status) => switch (status) {
        PreviewWriteStatus.willCreate => 'Будет записано',
        PreviewWriteStatus.willSkip => 'Пропуск (уже есть запись)',
        PreviewWriteStatus.pending => 'Проверка…',
        null => '—',
      };

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openIssue(String url) async {
    final ok = await openExternalUrl(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось открыть браузер. Ссылка скопирована в буфер.'),
        ),
      );
      await Clipboard.setData(ClipboardData(text: url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final period =
        '${DateFormat('d MMM yyyy', 'ru').format(widget.startDate)} — '
        '${DateFormat('d MMM yyyy', 'ru').format(widget.endDate)}';

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1D23),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF23262D),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Проверка плана', style: TextStyle(fontSize: 16)),
              Text(
                'Без записи в YouTrack',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: 'Обновить проверку',
                onPressed: _runCheck,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryBar(
              period: period,
              loading: _loading,
              error: _error,
              result: _result,
              entryCount: widget.entries.length,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _LegendItem(color: YtCalendarColors.link, label: 'Задача'),
                  SizedBox(width: 16),
                  _LegendItem(
                    color: YtCalendarColors.newPlanned,
                    label: 'Будет записано',
                  ),
                  SizedBox(width: 16),
                  _LegendItem(
                    color: YtCalendarColors.skipped,
                    label: 'Пропуск',
                  ),
                ],
              ),
            ),
            Expanded(
              child: _weekRows.isEmpty
                  ? const Center(
                      child: Text(
                        'Нет рабочих дней в периоде',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: YoutrackCalendarGrid(
                        weekRows: _weekRows,
                        onIssueTap: _onIssueTap,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.period,
    required this.loading,
    required this.error,
    required this.result,
    required this.entryCount,
  });

  final String period;
  final bool loading;
  final String? error;
  final SubmitResult? result;
  final int entryCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF23262D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          if (loading)
            const Text('Проверка дубликатов в YouTrack…')
          else if (error != null)
            Text(error!, style: const TextStyle(color: AppColors.warning))
          else if (result != null)
            Text(
              'Записей в плане: $entryCount · '
              'запишется: ${result!.created} · '
              'пропуск: ${result!.skipped}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}
