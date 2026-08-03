import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/theme/design_variant.dart';
import 'package:youtrack_timer/ui/utils/time_format.dart';

/// Строка состояния 1С (desktop large).
class HomeStatusBar extends ConsumerWidget {
  const HomeStatusBar({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final preference = ref.watch(designModePreferenceProvider);
    final resolved = ref.watch(designVariantProvider);
    final p = resolved.palette;

    final periodLabel = home.startDate != null && home.endDate != null
        ? '${DateFormat('dd.MM.yyyy').format(home.startDate!)} — '
            '${DateFormat('dd.MM.yyyy').format(home.endDate!)}'
        : 'Период не выбран';

    final recordCount = home.plan?.entries.length ?? 0;
    final totalMinutes =
        home.activeEntries.fold(0, (s, e) => s + e.minutes);

    return Container(
      decoration: BoxDecoration(
        color: p.toolbar,
        border: Border(top: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _StatusItem(palette: p, ok: settings.hasYouTrack, label: 'YouTrack'),
          _sep(p),
          _StatusItem(
            palette: p,
            ok: settings.hasCursor && settings.useAi,
            label: 'AI',
          ),
          _sep(p),
          _StatusItem(palette: p, ok: settings.hasGitLab, label: 'GitLab'),
          if (settings.dryRun) ...[
            _sep(p),
            _StatusItem(palette: p, ok: true, label: 'Без записи', warn: true),
          ],
          _sep(p),
          Text(
            periodLabel,
            style: TextStyle(fontSize: 11, color: p.textSecondary),
          ),
          if (home.plan != null) ...[
            _sep(p),
            Text(
              '$recordCount записей · ${TimeFormat.minutes(totalMinutes)}',
              style: TextStyle(fontSize: 11, color: p.textSecondary),
            ),
          ],
          const Spacer(),
          if (home.isLoading && home.loadingProgress != null)
            Text(
              '${home.loadingProgress!.percent}% · ${home.statusMessage}',
              style: TextStyle(fontSize: 11, color: p.textSecondary),
            )
          else if (home.statusMessage.isNotEmpty)
            Text(
              home.statusMessage,
              style: TextStyle(fontSize: 11, color: p.textSecondary),
            ),
          const SizedBox(width: 12),
          Text(
            preference == DesignModePreference.auto
                ? 'Авто → ${resolved.isLarge ? '1С' : 'Планшетный'}'
                : preference.label,
            style: TextStyle(fontSize: 10, color: p.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _sep(VariantPalette p) => Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: p.border,
      );
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.palette,
    required this.ok,
    required this.label,
    this.warn = false,
  });

  final VariantPalette palette;
  final bool ok;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? palette.warning
        : ok
            ? palette.success
            : palette.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: palette.border),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: palette.textSecondary),
        ),
      ],
    );
  }
}
