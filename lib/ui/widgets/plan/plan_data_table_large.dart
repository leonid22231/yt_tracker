import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';
import 'package:youtrack_timer/ui/widgets/plan/plan_utils.dart';
import 'package:youtrack_timer/ui/widgets/youtrack_issue_link.dart';

/// Табличный вид плана для large-режима.
class PlanDataTableLarge extends ConsumerStatefulWidget {
  const PlanDataTableLarge({super.key, required this.plan});

  final PlanBuildResult plan;

  @override
  ConsumerState<PlanDataTableLarge> createState() => _PlanDataTableLargeState();
}

class _PlanDataTableLargeState extends ConsumerState<PlanDataTableLarge> {
  String _query = '';
  final _focusNode = FocusNode();

  static const _allColumns = {
    'id': _ColumnDef('ID', 90, FlexColumnWidth(1)),
    'summary': _ColumnDef('Задача', 0, FlexColumnWidth(3)),
    'project': _ColumnDef('Проект', 80, FlexColumnWidth(1)),
    'days': _ColumnDef('Дни', 56, FixedColumnWidth(56)),
    'total': _ColumnDef('Итого', 72, FixedColumnWidth(72)),
    'ai': _ColumnDef('AI', 64, FixedColumnWidth(64)),
    'status': _ColumnDef('Статус', 80, FixedColumnWidth(80)),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelection());
  }

  @override
  void didUpdateWidget(PlanDataTableLarge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan != widget.plan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSelection());
    }
  }

  void _ensureSelection() {
    if (!mounted) return;
    final selected = ref.read(shellLayoutProvider).selectedIssueId;
    if (selected != null) return;
    final groups = groupPlanEntries(widget.plan);
    final home = ref.read(homeProvider);
    final active = groups
        .where((g) => !home.excludedIssueIds.contains(g.issueId))
        .toList();
    if (active.isEmpty) return;
    ref.read(shellLayoutProvider.notifier).selectIssue(active.first.issueId);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final layout = ref.watch(shellLayoutProvider);
    final youTrackBaseUrl = ref.watch(settingsProvider).valueOrNull?.youTrackUrl;
    final visible = layout.visibleTableColumns;
    final groups = groupPlanEntries(widget.plan);
    final excluded = home.excludedIssueIds;

    final active = groups
        .where((g) => !excluded.contains(g.issueId))
        .where((g) => issueMatchesQuery(g.issue, _query))
        .toList();

    final issueById = {for (final i in widget.plan.issues) i.id: i};
    final excludedIssues = excluded
        .map((id) => issueById[id])
        .whereType<YouTrackIssue>()
        .where((i) => issueMatchesQuery(i, _query))
        .toList();

    final columns = _allColumns.entries
        .where((e) => visible.contains(e.key))
        .map((e) => e.value)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          query: _query,
          taskCount: active.length,
          totalMinutes: home.activeEntries.fold(0, (s, e) => s + e.minutes),
          excludedCount: excludedIssues.length,
          visibleColumns: visible,
          onQueryChanged: (v) => setState(() => _query = v),
          onToggleColumn: (key) {
            ref.read(shellLayoutProvider.notifier).update((s) {
              final next = Set<String>.from(s.visibleTableColumns);
              if (next.contains(key)) {
                if (next.length > 2) next.remove(key);
              } else {
                next.add(key);
              }
              return s.copyWith(visibleTableColumns: next);
            });
          },
        ),
        Expanded(
          child: active.isEmpty && excludedIssues.isEmpty
              ? const Center(
                  child: Text(
                    'Нет задач по запросу',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : Focus(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKeyEvent: (node, event) =>
                      _handleKey(event, active, layout.selectedIssueId),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    children: [
                      _TableHeader(columns: columns),
                      ...active.map(
                        (g) => _TableRow(
                          group: g,
                          columns: columns,
                          columnKeys: visible.toList(),
                          selected: layout.selectedIssueId == g.issueId,
                          budgetMinutes: home.issueBudgetMinutes[g.issueId],
                          youTrackBaseUrl: youTrackBaseUrl,
                          onTap: () => ref
                              .read(shellLayoutProvider.notifier)
                              .selectIssue(g.issueId),
                        ),
                      ),
                      if (excludedIssues.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            'Исключены из плана',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...excludedIssues.map(
                          (issue) => _ExcludedRow(
                            issue: issue,
                            isRecalculating: home.isLoading,
                            youTrackBaseUrl: youTrackBaseUrl,
                            onRestore: () => ref
                                .read(homeProvider.notifier)
                                .includeIssueInPlan(issue.id),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  KeyEventResult _handleKey(
    KeyEvent event,
    List<PlanIssueGroup> rows,
    String? selectedId,
  ) {
    if (event is! KeyDownEvent || rows.isEmpty) return KeyEventResult.ignored;

    var index = rows.indexWhere((g) => g.issueId == selectedId);
    if (index < 0) index = 0;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      ref
          .read(shellLayoutProvider.notifier)
          .selectIssue(rows[(index + 1).clamp(0, rows.length - 1)].issueId);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      ref
          .read(shellLayoutProvider.notifier)
          .selectIssue(rows[(index - 1).clamp(0, rows.length - 1)].issueId);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _ColumnDef {
  const _ColumnDef(this.label, this.minWidth, this.width);

  final String label;
  final double minWidth;
  final TableColumnWidth width;
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.query,
    required this.taskCount,
    required this.totalMinutes,
    required this.excludedCount,
    required this.visibleColumns,
    required this.onQueryChanged,
    required this.onToggleColumn,
  });

  final String query;
  final int taskCount;
  final int totalMinutes;
  final int excludedCount;
  final Set<String> visibleColumns;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onToggleColumn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            height: 32,
            child: TextField(
              onChanged: onQueryChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Поиск…',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () => onQueryChanged(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _Chip('$taskCount задач'),
          const SizedBox(width: 6),
          _Chip(TimeFormat.minutes(totalMinutes)),
          if (excludedCount > 0) ...[
            const SizedBox(width: 6),
            _Chip('$excludedCount исключ.'),
          ],
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Колонки',
            icon: const Icon(Icons.view_column_outlined, size: 18),
            itemBuilder: (context) => [
              for (final key in _PlanDataTableLargeState._allColumns.keys)
                CheckedPopupMenuItem(
                  value: key,
                  checked: visibleColumns.contains(key),
                  child: Text(_PlanDataTableLargeState._allColumns[key]!.label),
                ),
            ],
            onSelected: onToggleColumn,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns});

  final List<_ColumnDef> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
        color: AppColors.surfaceHigh,
      ),
      child: Row(
        children: [
          for (final col in columns)
            Expanded(
              flex: col.width is FlexColumnWidth
                  ? (col.width as FlexColumnWidth).value.toInt()
                  : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  col.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.group,
    required this.columns,
    required this.columnKeys,
    required this.selected,
    required this.budgetMinutes,
    required this.youTrackBaseUrl,
    required this.onTap,
  });

  final PlanIssueGroup group;
  final List<_ColumnDef> columns;
  final List<String> columnKeys;
  final bool selected;
  final int? budgetMinutes;
  final String? youTrackBaseUrl;
  final VoidCallback onTap;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final issue = widget.group.issue;
    final aiEst = issue.estimatePresentation ?? '—';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        selected: widget.selected,
        button: true,
        label: '${issue.idReadable}: ${issue.summary}',
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: DesignTokens.durationFast,
            height: 40,
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.primarySoft
                  : _hovered
                      ? AppColors.surfaceHigh
                      : Colors.transparent,
              border: Border(
                bottom: const BorderSide(color: DesignTokens.borderSubtle),
                left: widget.selected
                    ? const BorderSide(color: AppColors.primary, width: 2)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                for (final key in widget.columnKeys)
                  Expanded(
                    flex: _flexFor(key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _cellFor(key, issue, aiEst, widget.youTrackBaseUrl),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _flexFor(String key) => switch (key) {
        'summary' => 3,
        _ => 1,
      };

  Widget _cellFor(
    String key,
    YouTrackIssue issue,
    String aiEst,
    String? youTrackBaseUrl,
  ) {
    return switch (key) {
      'id' => YouTrackIssueLink(
          issueIdReadable: issue.idReadable,
          baseUrl: youTrackBaseUrl,
          showIcon: true,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      'summary' => Text(
          issue.summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      'project' => Text(
          widget.group.projectName,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      'days' => Text(
          '${widget.group.entries.length}',
          style: const TextStyle(fontSize: 12),
        ),
      'total' => Text(
          TimeFormat.minutes(widget.group.totalMinutes),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
      'ai' => Text(
          aiEst,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      'status' => _StatusBadge(
          hasBudget: widget.budgetMinutes != null,
          isDaily: issue.isDaily,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.hasBudget, required this.isDaily});

  final bool hasBudget;
  final bool isDaily;

  @override
  Widget build(BuildContext context) {
    final (label, color) = hasBudget
        ? ('лимит', AppColors.warning)
        : isDaily
            ? ('daily', AppColors.accent)
            : ('план', AppColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _ExcludedRow extends StatelessWidget {
  const _ExcludedRow({
    required this.issue,
    required this.isRecalculating,
    required this.youTrackBaseUrl,
    required this.onRestore,
  });

  final YouTrackIssue issue;
  final bool isRecalculating;
  final String? youTrackBaseUrl;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.borderSubtle)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.block, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          YouTrackIssueLink(
            issueIdReadable: issue.idReadable,
            baseUrl: youTrackBaseUrl,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              issue.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: isRecalculating ? null : onRestore,
            child: const Text('Вернуть', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
