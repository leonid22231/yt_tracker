import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';

/// Предпочитаемый режим оформления (сохраняется в настройках).
enum DesignModePreference {
  auto('auto', 'Авто', 'По ширине окна'),
  current('current', 'Планшетный', 'Текущий компактный интерфейс'),
  large('large', 'Desktop Large', 'Интерфейс 1С для больших экранов');

  const DesignModePreference(this.storageKey, this.label, this.description);

  final String storageKey;
  final String label;
  final String description;

  static DesignModePreference fromKey(String? key) {
    return DesignModePreference.values.firstWhere(
      (v) => v.storageKey == key,
      orElse: () => DesignModePreference.auto,
    );
  }
}

/// Активный вариант оформления после разрешения auto.
enum DesignVariant {
  current,
  large,
}

/// Полный контекст варианта: токены + breakpoint + источник выбора.
class DesignVariantContext {
  const DesignVariantContext({
    required this.variant,
    required this.preference,
    required this.tokens,
    required this.palette,
    required this.windowWidth,
    required this.isAutoResolved,
  });

  final DesignVariant variant;
  final DesignModePreference preference;
  final VariantTokens tokens;
  final VariantPalette palette;
  final double windowWidth;
  final bool isAutoResolved;

  bool get isLarge => variant == DesignVariant.large;

  /// Размер сетки (колонки / gutter / margin).
  ({int columns, double gutter, double margin}) get grid => isLarge
      ? (
          columns: DesignTokens.gridColumnsLarge,
          gutter: DesignTokens.gutterLarge,
          margin: DesignTokens.marginLarge,
        )
      : (
          columns: DesignTokens.gridColumnsCompact,
          gutter: DesignTokens.gutterCompact,
          margin: DesignTokens.marginCompact,
        );

  static DesignVariant resolveVariant({
    required DesignModePreference preference,
    required double width,
  }) {
    switch (preference) {
      case DesignModePreference.current:
        return DesignVariant.current;
      case DesignModePreference.large:
        return DesignVariant.large;
      case DesignModePreference.auto:
        return width >= DesignTokens.breakpointLarge
            ? DesignVariant.large
            : DesignVariant.current;
    }
  }

  static DesignVariantContext fromWidth({
    required DesignModePreference preference,
    required double width,
  }) {
    final variant = resolveVariant(preference: preference, width: width);
    return DesignVariantContext(
      variant: variant,
      preference: preference,
      tokens: variant == DesignVariant.large
          ? VariantTokens.large
          : VariantTokens.current,
      palette: variant == DesignVariant.large
          ? VariantPalette.oneC
          : VariantPalette.dark,
      windowWidth: width,
      isAutoResolved: preference == DesignModePreference.auto,
    );
  }
}

/// Сохраняемое состояние панелей (не сбрасывается при смене variant).
class ShellLayoutState {
  const ShellLayoutState({
    this.leftNavExpanded = true,
    this.leftNavWidth = 240,
    this.detailsPanelWidth = 360,
    this.detailsPanelOpen = true,
    this.logExpanded = true,
    this.logPanelHeight = 180,
    this.activeTabIndex = 0,
    this.selectedIssueId,
    this.expandedIssueIds = const {},
    this.visibleTableColumns = const {
      'id',
      'summary',
      'project',
      'days',
      'total',
      'ai',
      'status',
    },
  });

  static const logPanelHeightMin = 72.0;
  static const logPanelHeightDefault = 180.0;
  static const logPanelHeightMax = 520.0;

  final bool leftNavExpanded;
  final double leftNavWidth;
  final double detailsPanelWidth;
  final bool detailsPanelOpen;
  final bool logExpanded;
  final double logPanelHeight;
  final int activeTabIndex;
  final String? selectedIssueId;
  final Set<String> expandedIssueIds;
  final Set<String> visibleTableColumns;

  ShellLayoutState copyWith({
    bool? leftNavExpanded,
    double? leftNavWidth,
    double? detailsPanelWidth,
    bool? detailsPanelOpen,
    bool? logExpanded,
    double? logPanelHeight,
    int? activeTabIndex,
    String? selectedIssueId,
    Set<String>? expandedIssueIds,
    Set<String>? visibleTableColumns,
  }) =>
      ShellLayoutState(
        leftNavExpanded: leftNavExpanded ?? this.leftNavExpanded,
        leftNavWidth: leftNavWidth ?? this.leftNavWidth,
        detailsPanelWidth: detailsPanelWidth ?? this.detailsPanelWidth,
        detailsPanelOpen: detailsPanelOpen ?? this.detailsPanelOpen,
        logExpanded: logExpanded ?? this.logExpanded,
        logPanelHeight: logPanelHeight ?? this.logPanelHeight,
        activeTabIndex: activeTabIndex ?? this.activeTabIndex,
        selectedIssueId: selectedIssueId ?? this.selectedIssueId,
        expandedIssueIds: expandedIssueIds ?? this.expandedIssueIds,
        visibleTableColumns: visibleTableColumns ?? this.visibleTableColumns,
      );

  Map<String, dynamic> toJson() => {
        'leftNavExpanded': leftNavExpanded,
        'leftNavWidth': leftNavWidth,
        'detailsPanelWidth': detailsPanelWidth,
        'detailsPanelOpen': detailsPanelOpen,
        'logExpanded': logExpanded,
        'logPanelHeight': logPanelHeight,
        'activeTabIndex': activeTabIndex,
        'selectedIssueId': selectedIssueId,
        'expandedIssueIds': expandedIssueIds.toList(),
        'visibleTableColumns': visibleTableColumns.toList(),
      };

  factory ShellLayoutState.fromJson(Map<String, dynamic> json) =>
      ShellLayoutState(
        leftNavExpanded: json['leftNavExpanded'] as bool? ?? true,
        leftNavWidth: (json['leftNavWidth'] as num?)?.toDouble() ?? 240,
        detailsPanelWidth:
            (json['detailsPanelWidth'] as num?)?.toDouble() ?? 360,
        detailsPanelOpen: json['detailsPanelOpen'] as bool? ?? true,
        logExpanded: json['logExpanded'] as bool? ?? true,
        logPanelHeight: (json['logPanelHeight'] as num?)?.toDouble() ??
            ShellLayoutState.logPanelHeightDefault,
        activeTabIndex: json['activeTabIndex'] as int? ?? 0,
        selectedIssueId: json['selectedIssueId'] as String?,
        expandedIssueIds: (json['expandedIssueIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toSet() ??
            {},
        visibleTableColumns: (json['visibleTableColumns'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toSet() ??
            const {
              'id',
              'summary',
              'project',
              'days',
              'total',
              'ai',
              'status',
            },
      );
}
