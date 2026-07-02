import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/models/gitlab/productivity_metric.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';

/// Сетка ключевых метрик периода.
class GitLabMetricsDashboard extends StatelessWidget {
  const GitLabMetricsDashboard({
    super.key,
    required this.metrics,
    this.onPeakDayTap,
  });

  final ProductivityMetric metrics;
  final void Function(DateTime day)? onPeakDayTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        label: 'Коммитов',
        value: '${metrics.totalCommits}',
        subtitle: '∅ ${metrics.averageCommitsPerDay.toStringAsFixed(1)}/день',
        icon: Icons.call_merge_rounded,
        gradient: const [Color(0xFF7C6CF0), Color(0xFF5B4FD6)],
      ),
      _MetricData(
        label: 'Задач',
        value: '${metrics.totalTasks}',
        subtitle: '∅ ${metrics.averageTasksPerDay.toStringAsFixed(1)}/день',
        icon: Icons.task_alt_rounded,
        gradient: const [Color(0xFF3DDBB5), Color(0xFF2BB896)],
      ),
      _MetricData(
        label: 'Оценка времени',
        value: TimeFormat.minutes(metrics.totalEstimatedMinutes),
        subtitle: '∅ ${metrics.averageEstimatedMinutes.round()} м/день',
        icon: Icons.schedule_rounded,
        gradient: const [Color(0xFFFBBF24), Color(0xFFE09B12)],
      ),
      _MetricData(
        label: 'Изменения',
        value: '+${metrics.totalAdditions}',
        subtitle: '−${metrics.totalDeletions} строк',
        icon: Icons.code_rounded,
        gradient: const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
      ),
      _MetricData(
        label: 'Активных дней',
        value: '${metrics.activeDaysCount}',
        subtitle: 'серия ${metrics.longestActiveStreak} дн.',
        icon: Icons.local_fire_department_rounded,
        gradient: const [Color(0xFFF87171), Color(0xFFDC2626)],
      ),
      _MetricData(
        label: 'Продуктивность',
        value: metrics.averageProductivityScore.toStringAsFixed(0),
        subtitle: metrics.peakDay != null
            ? 'пик ${DateFormat('dd.MM').format(metrics.peakDay!)}'
            : 'средняя',
        icon: Icons.bolt_rounded,
        gradient: const [Color(0xFFA78BFA), Color(0xFF7C3AED)],
        onTap: metrics.peakDay != null
            ? () => onPeakDayTap?.call(metrics.peakDay!)
            : null,
      ),
      if (metrics.mergeRequestCount > 0)
        _MetricData(
          label: 'Merge requests',
          value: '${metrics.mergeRequestCount}',
          subtitle: 'за период',
          icon: Icons.merge_type_rounded,
          gradient: const [Color(0xFF34D399), Color(0xFF059669)],
        ),
      if (metrics.topProject.isNotEmpty)
        _MetricData(
          label: 'Топ-проект',
          value: metrics.topProject.split('/').last,
          subtitle: metrics.topProject,
          icon: Icons.folder_special_outlined,
          gradient: const [Color(0xFF94A3B8), Color(0xFF64748B)],
          compactValue: true,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width > 900 ? 4 : width > 560 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: cols >= 4 ? 1.55 : 1.35,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _MetricCard(data: items[i]),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.onTap,
    this.compactValue = false,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final bool compactValue;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                data.gradient.first.withValues(alpha: 0.22),
                data.gradient.last.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(
              color: data.gradient.first.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: data.gradient.first.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(data.icon, size: 18, color: data.gradient.first),
                    ),
                    const Spacer(),
                    if (data.onTap != null)
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  data.value,
                  maxLines: data.compactValue ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: data.compactValue ? 15 : 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
