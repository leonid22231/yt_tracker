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
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/ui/layout/variant_scaffold.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/business/one_c_title_bar.dart';
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
    final p = ref.read(designVariantProvider).palette;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.isOneC ? p.formBackground : AppColors.surface,
      shape: p.isOneC
          ? null
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(p.isOneC ? 12 : 20, 12, p.isOneC ? 12 : 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!p.isOneC)
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (!p.isOneC) const SizedBox(height: 16),
              YouTrackIssueLink(
                issueIdReadable: row.issueIdReadable,
                baseUrl: widget.baseUrl,
                showIcon: true,
                style: TextStyle(
                  fontSize: p.isOneC ? 14 : 18,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                row.summary,
                style: TextStyle(
                  fontSize: 13,
                  color: p.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _detailLine(p, 'День', fmt.format(day.day)),
              if (row.existingMinutes > 0)
                _detailLine(
                  p,
                  'Уже в YouTrack',
                  TimeFormat.minutes(row.existingMinutes),
                ),
              if (row.plannedMinutes > 0) ...[
                _detailLine(
                  p,
                  'Новый план',
                  TimeFormat.minutes(row.plannedMinutes),
                ),
                _detailLine(p, 'При записи', _statusLabel(row.plannedStatus)),
              ],
              _detailLine(p, 'Итого за день', TimeFormat.minutes(row.totalMinutes)),
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

  Widget _detailLine(VariantPalette p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: p.textPrimary,
              ),
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
    final isLarge = ref.watch(designVariantProvider).isLarge;
    final p = ref.watch(designVariantProvider).palette;

    return VariantScaffold(
      title: 'Проверка плана',
      subtitle: 'Без записи в YouTrack · $period',
      toolbarActions: isLarge && !_loading
          ? [
              OneCToolbarButton(
                palette: ref.watch(designVariantProvider).palette,
                label: 'Обновить',
                icon: Icons.refresh,
                onPressed: _runCheck,
              ),
            ]
          : null,
      actions: isLarge
          ? null
          : [
              if (!_loading)
                IconButton(
                  tooltip: 'Обновить проверку',
                  onPressed: _runCheck,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
            ],
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
          Padding(
            padding: EdgeInsets.fromLTRB(isLarge ? 8 : 16, 4, isLarge ? 8 : 16, 0),
            child: Row(
              children: [
                _LegendDot(color: p.planned, label: 'Запишется'),
                SizedBox(width: p.isOneC ? 12 : 16),
                _LegendDot(color: p.textMuted, label: 'Пропуск'),
                SizedBox(width: p.isOneC ? 12 : 16),
                _LegendDot(color: p.existing, label: 'Уже в YT'),
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

class _HeaderPanel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(designVariantProvider).palette;
    final isLarge = p.isOneC;

    return Container(
      margin: EdgeInsets.fromLTRB(isLarge ? 8 : 16, isLarge ? 4 : 12, isLarge ? 8 : 16, 8),
      padding: EdgeInsets.all(isLarge ? 10 : 16),
      decoration: isLarge
          ? OneCDecorations.flatPanel(p)
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isLarge)
            Text(
              period,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          if (!isLarge) const SizedBox(height: 12),
          if (loading)
            Text(
              'Проверка дубликатов…',
              style: TextStyle(fontSize: 12, color: p.textSecondary),
            )
          else if (error != null)
            Text(error!, style: TextStyle(color: p.warning))
          else if (result != null)
            Wrap(
              spacing: isLarge ? 4 : 8,
              runSpacing: isLarge ? 4 : 8,
              children: [
                _StatTile(palette: p, label: 'Записей в плане', value: '$entryCount'),
                _StatTile(palette: p, label: 'Запишется', value: '${result!.created}'),
                _StatTile(palette: p, label: 'Пропуск', value: '${result!.skipped}'),
                _StatTile(palette: p, label: 'Рабочих дней', value: '$dayCount'),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.palette,
    required this.label,
    required this.value,
  });

  final VariantPalette palette;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (palette.isOneC) {
      return DecoratedBox(
        decoration: OneCDecorations.raised(palette),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 9, color: palette.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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

class _LegendDot extends ConsumerWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(designVariantProvider).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            border: p.isOneC ? Border.all(color: p.border) : null,
            shape: p.isOneC ? BoxShape.rectangle : BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: p.textMuted),
        ),
      ],
    );
  }
}
