import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/models/issue.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/plan_builder_service.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
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
    final p = ref.watch(designVariantProvider).palette;
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
          palette: p,
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
              ? Center(
                  child: Text(
                    'Нет задач по запросу',
                    style: TextStyle(color: p.textMuted),
                  ),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.workArea,
                    border: Border(top: BorderSide(color: p.border)),
                  ),
                  child: Focus(
                    focusNode: _focusNode,
                    autofocus: true,
                    onKeyEvent: (node, event) =>
                        _handleKey(event, active, layout.selectedIssueId),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _TableHeader(columns: columns, palette: p),
                        for (var i = 0; i < active.length; i++)
                          _TableRow(
                            palette: p,
                            group: active[i],
                            columns: columns,
                            columnKeys: visible.toList(),
                            selected: layout.selectedIssueId == active[i].issueId,
                            zebra: i.isOdd,
                            budgetMinutes:
                                home.issueBudgetMinutes[active[i].issueId],
                            youTrackBaseUrl: youTrackBaseUrl,
                            onTap: () => ref
                                .read(shellLayoutProvider.notifier)
                                .selectIssue(active[i].issueId),
                          ),
                        if (excludedIssues.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            child: Text(
                              'Исключены из плана',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: p.textMuted,
                              ),
                            ),
                          ),
                          ...excludedIssues.map(
                            (issue) => _ExcludedRow(
                              palette: p,
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
    required this.palette,
    required this.query,
    required this.taskCount,
    required this.totalMinutes,
    required this.excludedCount,
    required this.visibleColumns,
    required this.onQueryChanged,
    required this.onToggleColumn,
  });

  final VariantPalette palette;
  final String query;
  final int taskCount;
  final int totalMinutes;
  final int excludedCount;
  final Set<String> visibleColumns;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onToggleColumn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.toolbar,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            height: 24,
            child: TextField(
              onChanged: onQueryChanged,
              style: TextStyle(fontSize: 11, color: palette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Поиск…',
                hintStyle: TextStyle(color: palette.textMuted, fontSize: 11),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                prefixIcon: Icon(Icons.search, size: 14, color: palette.textMuted),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 12, color: palette.textMuted),
                        onPressed: () => onQueryChanged(''),
                      )
                    : null,
                filled: true,
                fillColor: palette.inputBackground,
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: palette.borderShadow),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Chip(palette: palette, label: '$taskCount задач'),
          const SizedBox(width: 4),
          _Chip(palette: palette, label: TimeFormat.minutes(totalMinutes)),
          if (excludedCount > 0) ...[
            const SizedBox(width: 4),
            _Chip(palette: palette, label: '$excludedCount исключ.'),
          ],
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Колонки',
            icon: Icon(Icons.view_column_outlined, size: 16, color: palette.textPrimary),
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
  const _Chip({required this.palette, required this.label});

  final VariantPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: OneCDecorations.raised(palette),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: palette.textSecondary),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns, required this.palette});

  final List<_ColumnDef> columns;
  final VariantPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: palette.tableHeader,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          for (final col in columns)
            Expanded(
              flex: col.width is FlexColumnWidth
                  ? (col.width as FlexColumnWidth).value.toInt()
                  : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  col.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
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
    required this.palette,
    required this.group,
    required this.columns,
    required this.columnKeys,
    required this.selected,
    required this.zebra,
    required this.budgetMinutes,
    required this.youTrackBaseUrl,
    required this.onTap,
  });

  final VariantPalette palette;
  final PlanIssueGroup group;
  final List<_ColumnDef> columns;
  final List<String> columnKeys;
  final bool selected;
  final bool zebra;
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
    final p = widget.palette;
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
            height: 24,
            decoration: BoxDecoration(
              color: widget.selected
                  ? p.tableSelected
                  : _hovered
                      ? p.tableZebra
                      : widget.zebra
                          ? p.tableZebra
                          : p.tableRow,
              border: Border(
                bottom: BorderSide(color: p.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                for (final key in widget.columnKeys)
                  Expanded(
                    flex: _flexFor(key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _cellFor(
                        key,
                        issue,
                        aiEst,
                        widget.youTrackBaseUrl,
                        p,
                      ),
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
    VariantPalette p,
  ) {
    final textColor =
        widget.selected ? p.tableSelectedText : p.textPrimary;
    return switch (key) {
      'id' => YouTrackIssueLink(
          issueIdReadable: issue.idReadable,
          baseUrl: youTrackBaseUrl,
          showIcon: true,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.selected ? p.tableSelectedText : p.link,
            decoration: TextDecoration.underline,
          ),
        ),
      'summary' => Text(
          issue.summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: textColor),
        ),
      'project' => Text(
          widget.group.projectName,
          style: TextStyle(fontSize: 11, color: textColor),
        ),
      'days' => Text(
          '${widget.group.entries.length}',
          style: TextStyle(fontSize: 11, color: textColor),
        ),
      'total' => Text(
          TimeFormat.minutes(widget.group.totalMinutes),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      'ai' => Text(
          aiEst,
          style: TextStyle(fontSize: 10, color: textColor),
        ),
      'status' => _StatusBadge(
          palette: p,
          hasBudget: widget.budgetMinutes != null,
          isDaily: issue.isDaily,
          selected: widget.selected,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.palette,
    required this.hasBudget,
    required this.isDaily,
    required this.selected,
  });

  final VariantPalette palette;
  final bool hasBudget;
  final bool isDaily;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (label, color) = hasBudget
        ? ('лимит', palette.warning)
        : isDaily
            ? ('daily', palette.planned)
            : ('план', palette.accent);

    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: selected ? palette.tableSelectedText : color,
      ),
    );
  }
}

class _ExcludedRow extends StatelessWidget {
  const _ExcludedRow({
    required this.palette,
    required this.issue,
    required this.isRecalculating,
    required this.youTrackBaseUrl,
    required this.onRestore,
  });

  final VariantPalette palette;
  final YouTrackIssue issue;
  final bool isRecalculating;
  final String? youTrackBaseUrl;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: palette.tableZebra,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Icon(Icons.block, size: 12, color: palette.textMuted),
          const SizedBox(width: 6),
          YouTrackIssueLink(
            issueIdReadable: issue.idReadable,
            baseUrl: youTrackBaseUrl,
            style: TextStyle(
              fontSize: 11,
              color: palette.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              issue.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: palette.textMuted),
            ),
          ),
          TextButton(
            onPressed: isRecalculating ? null : onRestore,
            style: TextButton.styleFrom(
              foregroundColor: palette.link,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Вернуть', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}
