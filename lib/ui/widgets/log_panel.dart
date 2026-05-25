import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/logging/log_entry.dart';
import 'package:youtrack_timer/logging/log_level.dart';
import 'package:youtrack_timer/providers/log_provider.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';

/// Панель журнала с фильтрами, цветами и копированием.
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
      height: 200,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LogToolbar(
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
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text(
                      'Логи появятся при построении плана',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _LogLine(entry: entries[i]),
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
    required this.total,
    required this.visible,
    required this.minLevel,
    required this.onLevelChanged,
    required this.onClear,
    required this.onCopy,
  });

  final int total;
  final int visible;
  final LogLevel minLevel;
  final ValueChanged<LogLevel> onLevelChanged;
  final VoidCallback onClear;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            'Лог ($visible/$total)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          DropdownButtonHideUnderline(
            child: DropdownButton<LogLevel>(
              value: minLevel,
              isDense: true,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              dropdownColor: const Color(0xFF2D3344),
              items: LogLevel.values
                  .map(
                    (l) => DropdownMenuItem(
                      value: l,
                      child: Text(l.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onLevelChanged(v);
              },
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Копировать',
            onPressed: onCopy,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
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
  const _LogLine({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      LogLevel.debug => Colors.white38,
      LogLevel.info => Colors.white70,
      LogLevel.success => const Color(0xFF81C784),
      LogLevel.warn => const Color(0xFFFFB74D),
      LogLevel.error => const Color(0xFFE57373),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${entry.timeLabel} ',
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: Colors.white30,
              ),
            ),
            TextSpan(
              text: '[${entry.level.label}] ',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: '[${entry.category}] ',
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: Color(0xFF7B5CFF),
              ),
            ),
            TextSpan(
              text: entry.message,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
