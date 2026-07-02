import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/config/app_config.dart';
import 'package:youtrack_timer/models/loading_progress.dart';
import 'package:youtrack_timer/models/plan_preview_entry.dart';
import 'package:youtrack_timer/models/time_estimate.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/services/plan_preview_builder.dart';
import 'package:youtrack_timer/services/submit_service.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/loading_progress_view.dart';
import 'package:youtrack_timer/ui/widgets/preview/plan_preview_day_list.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';
import 'package:youtrack_timer/youtrack/youtrack_client.dart';

/// Окно проверки плана перед записью в YouTrack.
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
  LoadingProgress? _progress;
  String? _error;
  SubmitResult? _result;
  List<PlanPreviewDay> _days = [];

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    final tracker = LoadingProgressTracker(
      operation: 'Проверка плана',
      totalSteps: 1,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    tracker.start(
      'Проверка дубликатов в YouTrack',
      detail: '${widget.entries.length} записей',
    );

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
        progress: tracker,
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
        _loading = false;
        _progress = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _progress = null;
        _days = PlanPreviewBuilder.buildDays(
          plan: widget.plan,
          entriesToCheck: widget.entries,
        );
      });
    }
  }

  void _showIssueDetails(PlanPreviewRow row, PlanPreviewDay day) {
    final fmt = DateFormat('d MMMM yyyy', 'ru');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              YouTrackIssueLink(
                issueIdReadable: row.issueIdReadable,
                baseUrl: widget.baseUrl,
                showIcon: true,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                row.summary,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _detailLine('День', fmt.format(day.day)),
              if (row.existingMinutes > 0)
                _detailLine(
                  'Уже в YouTrack',
                  TimeFormat.minutes(row.existingMinutes),
                ),
              if (row.plannedMinutes > 0) ...[
                _detailLine(
                  'Новый план',
                  TimeFormat.minutes(row.plannedMinutes),
                ),
                _detailLine('При записи', _statusLabel(row.plannedStatus)),
              ],
              _detailLine('Итого за день', TimeFormat.minutes(row.totalMinutes)),
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

  @override
  Widget build(BuildContext context) {
    final period =
        '${DateFormat('d MMM yyyy', 'ru').format(widget.startDate)} — '
        '${DateFormat('d MMM yyyy', 'ru').format(widget.endDate)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
        actions: [
          if (!_loading)
            IconButton(
              tooltip: 'Обновить проверку',
              onPressed: _runCheck,
              icon: const Icon(Icons.refresh, size: 20),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderPanel(
            period: period,
            loading: _loading,
            error: _error,
            result: _result,
            entryCount: widget.entries.length,
            dayCount: _days.length,
          ),
          if (_loading && _progress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: LoadingProgressView(
                progress: _progress,
                layout: LoadingProgressLayout.strip,
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                _LegendDot(color: AppColors.accent, label: 'Запишется'),
                SizedBox(width: 16),
                _LegendDot(color: AppColors.textMuted, label: 'Пропуск'),
                SizedBox(width: 16),
                _LegendDot(color: AppColors.existing, label: 'Уже в YT'),
              ],
            ),
          ),
          Expanded(
            child: PlanPreviewDayList(
              days: _days,
              baseUrl: widget.baseUrl,
              onIssueTap: _showIssueDetails,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    required this.period,
    required this.loading,
    required this.error,
    required this.result,
    required this.entryCount,
    required this.dayCount,
  });

  final String period;
  final bool loading;
  final String? error;
  final SubmitResult? result;
  final int entryCount;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            period,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Text(
              'Проверка дубликатов…',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )
          else if (error != null)
            Text(error!, style: const TextStyle(color: AppColors.warning))
          else if (result != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatTile(
                  label: 'Записей в плане',
                  value: '$entryCount',
                  color: AppColors.primary,
                ),
                _StatTile(
                  label: 'Запишется',
                  value: '${result!.created}',
                  color: AppColors.accent,
                ),
                _StatTile(
                  label: 'Пропуск',
                  value: '${result!.skipped}',
                  color: AppColors.textMuted,
                ),
                _StatTile(
                  label: 'Рабочих дней',
                  value: '$dayCount',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

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
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
