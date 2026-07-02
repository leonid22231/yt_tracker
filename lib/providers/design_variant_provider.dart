import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtrack_timer/ui/theme/design_variant.dart';

const _keyDesignMode = 'design_mode_preference';
const _keyShellLayout = 'shell_layout_state_v1';

/// Текущая ширина окна (обновляется из [AppShell] через LayoutBuilder).
final windowWidthProvider = StateProvider<double>((_) => 1200);

final designVariantProvider = Provider<DesignVariantContext>((ref) {
  final preference = ref.watch(designModePreferenceProvider);
  final width = ref.watch(windowWidthProvider);
  return DesignVariantContext.fromWidth(preference: preference, width: width);
});

final designModePreferenceProvider =
    StateNotifierProvider<DesignModeNotifier, DesignModePreference>(
  (_) => DesignModeNotifier(),
);

final shellLayoutProvider =
    StateNotifierProvider<ShellLayoutNotifier, ShellLayoutState>(
  (_) => ShellLayoutNotifier(),
);

class DesignModeNotifier extends StateNotifier<DesignModePreference> {
  DesignModeNotifier() : super(DesignModePreference.auto) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = DesignModePreference.fromKey(prefs.getString(_keyDesignMode));
  }

  Future<void> setPreference(DesignModePreference preference) async {
    state = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDesignMode, preference.storageKey);
  }
}

class ShellLayoutNotifier extends StateNotifier<ShellLayoutState> {
  ShellLayoutNotifier() : super(const ShellLayoutState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyShellLayout);
    if (raw == null) return;
    try {
      state = ShellLayoutState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // ignore corrupt state
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyShellLayout, jsonEncode(state.toJson()));
  }

  void update(ShellLayoutState Function(ShellLayoutState current) fn) {
    state = fn(state);
    _persist();
  }

  void setLeftNavWidth(double width) =>
      update((s) => s.copyWith(leftNavWidth: width));

  void toggleLeftNavExpanded() =>
      update((s) => s.copyWith(leftNavExpanded: !s.leftNavExpanded));

  void setDetailsPanelWidth(double width) =>
      update((s) => s.copyWith(detailsPanelWidth: width));

  void toggleDetailsPanel() =>
      update((s) => s.copyWith(detailsPanelOpen: !s.detailsPanelOpen));

  void setActiveTab(int index) =>
      update((s) => s.copyWith(activeTabIndex: index));

  void selectIssue(String? issueId) =>
      update((s) => s.copyWith(selectedIssueId: issueId));

  void toggleLogExpanded() =>
      update((s) => s.copyWith(logExpanded: !s.logExpanded));
}

/// Быстрый переключатель режима в TopBar.
class DesignModeToggle extends ConsumerWidget {
  const DesignModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(designModePreferenceProvider);
    final resolved = ref.watch(designVariantProvider);

    return PopupMenuButton<DesignModePreference>(
      tooltip: 'Режим интерфейса: ${preference.label}',
      icon: Icon(
        resolved.isLarge ? Icons.dashboard_outlined : Icons.tablet_outlined,
        size: 20,
      ),
      onSelected: ref.read(designModePreferenceProvider.notifier).setPreference,
      itemBuilder: (context) => DesignModePreference.values
          .map(
            (mode) => PopupMenuItem(
              value: mode,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (mode) {
                    DesignModePreference.auto => Icons.auto_mode,
                    DesignModePreference.current => Icons.tablet,
                    DesignModePreference.large => Icons.desktop_windows_outlined,
                  },
                  size: 20,
                ),
                title: Text(mode.label),
                subtitle: Text(
                  mode.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: preference == mode
                    ? const Icon(Icons.check, size: 18)
                    : null,
              ),
            ),
          )
          .toList(),
    );
  }
}
