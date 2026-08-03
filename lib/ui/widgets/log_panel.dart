import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/logging/log_entry.dart';
import 'package:youtrack_timer/logging/log_level.dart';
import 'package:youtrack_timer/providers/log_provider.dart';
import 'package:youtrack_timer/ui/dialogs/paste_cursor_json_dialog.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';

/// Панель журнала сообщений.
class LogPanel extends ConsumerStatefulWidget {
  const LogPanel({super.key});

  @override
  ConsumerState<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends ConsumerState<LogPanel> {
  final _scrollController = ScrollController();
  int _prevCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final entries = ref.watch(visibleLogEntriesProvider);
    final allEntries = ref.watch(logEntriesProvider);
    final minLevel = ref.watch(logMinLevelProvider);

    if (entries.length > _prevCount) {
      _prevCount = entries.length;
      _scrollToEnd();
    } else if (entries.length < _prevCount) {
      _prevCount = entries.length;
    }

    return Container(
      decoration: BoxDecoration(
        color: p.isOneC ? p.formBackground : AppColors.background,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LogToolbar(
            palette: p,
            total: allEntries.length,
            visible: entries.length,
            minLevel: minLevel,
            onLevelChanged: (l) =>
                ref.read(logMinLevelProvider.notifier).state = l,
            onClear: () {
              ref.read(logEntriesProvider.notifier).clear();
              setState(() => _prevCount = 0);
            },
            onCopy: () => _copyAll(entries),
            onSecretPasteJson: () => PasteCursorJsonDialog.show(context),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'Сообщения появятся при работе',
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  )
                : DecoratedBox(
                    decoration: p.isOneC
                        ? OneCDecorations.sunken(p)
                        : const BoxDecoration(),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (_, i) =>
                          _LogLine(entry: entries[i], palette: p),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _copyAll(List<LogEntry> entries) {
    final text = entries.map((e) => e.line).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Скопировано ${entries.length} строк')),
    );
  }
}

class _LogToolbar extends StatelessWidget {
  const _LogToolbar({
    required this.palette,
    required this.total,
    required this.visible,
    required this.minLevel,
    required this.onLevelChanged,
    required this.onClear,
    required this.onCopy,
    required this.onSecretPasteJson,
  });

  final VariantPalette palette;
  final int total;
  final int visible;
  final LogLevel minLevel;
  final ValueChanged<LogLevel> onLevelChanged;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  final VoidCallback onSecretPasteJson;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onLongPress: onSecretPasteJson,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.article_outlined, size: 14, color: palette.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Журнал ($visible/$total)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<LogLevel>(
              value: minLevel,
              isDense: true,
              style: TextStyle(fontSize: 10, color: palette.textSecondary),
              dropdownColor: palette.panel,
              items: LogLevel.values
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onLevelChanged(v);
              },
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.copy, size: 16, color: palette.textSecondary),
            tooltip: 'Копировать',
            onPressed: onCopy,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: palette.textSecondary),
            tooltip: 'Очистить',
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry, required this.palette});

  final LogEntry entry;
  final VariantPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      LogLevel.debug => palette.textMuted,
      LogLevel.info => palette.textSecondary,
      LogLevel.success => palette.success,
      LogLevel.warn => palette.warning,
      LogLevel.error => palette.danger,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${entry.timeLabel} ',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                color: palette.textMuted,
              ),
            ),
            TextSpan(
              text: '[${entry.level.label}] ',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: '[${entry.category}] ',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                color: palette.accent,
              ),
            ),
            TextSpan(
              text: entry.message,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 10,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
