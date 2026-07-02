import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtrack_timer/providers/app_state.dart';
import 'package:youtrack_timer/providers/design_variant_provider.dart';
import 'package:youtrack_timer/services/settings_store.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';
import 'package:youtrack_timer/ui/theme/design_variant.dart';

/// Нижняя строка состояния для large-режима.
class HomeStatusBar extends ConsumerWidget {
  const HomeStatusBar({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final preference = ref.watch(designModePreferenceProvider);
    final resolved = ref.watch(designVariantProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _Dot(ok: settings.hasYouTrack, label: 'YouTrack'),
          const SizedBox(width: 12),
          _Dot(
            ok: settings.hasCursor && settings.useAi,
            label: 'AI',
          ),
          const SizedBox(width: 12),
          _Dot(ok: settings.hasGitLab, label: 'GitLab'),
          if (settings.dryRun) ...[
            const SizedBox(width: 12),
            _Dot(ok: true, label: 'Dry-run', warn: true),
          ],
          const Spacer(),
          if (home.isLoading && home.loadingProgress != null)
            Text(
              '${home.loadingProgress!.percent}% · ${home.statusMessage}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            )
          else if (home.statusMessage.isNotEmpty)
            Text(
              home.statusMessage,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          const SizedBox(width: 16),
          Text(
            preference == DesignModePreference.auto
                ? 'Auto → ${resolved.variant.name}'
                : preference.label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.ok, required this.label, this.warn = false});

  final bool ok;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? AppColors.warning
        : ok
            ? AppColors.success
            : AppColors.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
