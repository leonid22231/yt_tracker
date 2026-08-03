import 'package:flutter/material.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';

/// Палитра интерфейса: тёмная (планшет) или 1С (desktop large).
@immutable
class VariantPalette {
  const VariantPalette({
    required this.isOneC,
    required this.window,
    required this.workArea,
    required this.formBackground,
    required this.panel,
    required this.panelHeader,
    required this.toolbar,
    required this.titleBar,
    required this.titleBarEnd,
    required this.border,
    required this.borderHighlight,
    required this.borderShadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnTitle,
    required this.tableHeader,
    required this.tableRow,
    required this.tableZebra,
    required this.tableSelected,
    required this.tableSelectedText,
    required this.buttonFace,
    required this.buttonHover,
    required this.buttonPrimary,
    required this.buttonPrimaryHover,
    required this.buttonDanger,
    required this.buttonDangerHover,
    required this.link,
    required this.linkHover,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.inputBackground,
    required this.resizeHandle,
    required this.resizeHandleHover,
    required this.existing,
    required this.planned,
  });

  final bool isOneC;
  final Color window;
  final Color workArea;
  final Color formBackground;
  final Color panel;
  final Color panelHeader;
  final Color toolbar;
  final Color titleBar;
  final Color titleBarEnd;
  final Color border;
  final Color borderHighlight;
  final Color borderShadow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnTitle;
  final Color tableHeader;
  final Color tableRow;
  final Color tableZebra;
  final Color tableSelected;
  final Color tableSelectedText;
  final Color buttonFace;
  final Color buttonHover;
  final Color buttonPrimary;
  final Color buttonPrimaryHover;
  final Color buttonDanger;
  final Color buttonDangerHover;
  final Color link;
  final Color linkHover;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color inputBackground;
  final Color resizeHandle;
  final Color resizeHandleHover;
  final Color existing;
  final Color planned;

  /// Тёмная палитра (планшетный режим).
  static const dark = VariantPalette(
    isOneC: false,
    window: AppColors.background,
    workArea: Color(0xFF10141C),
    formBackground: AppColors.surfaceHigh,
    panel: AppColors.surface,
    panelHeader: Color(0xFF181D28),
    toolbar: Color(0xFF181D28),
    titleBar: AppColors.surface,
    titleBarEnd: AppColors.surface,
    border: AppColors.border,
    borderHighlight: Color(0xFF3D4659),
    borderShadow: Color(0xFF1A1F2B),
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    textOnTitle: AppColors.textPrimary,
    tableHeader: Color(0xFF181D28),
    tableRow: Color(0xFF10141C),
    tableZebra: Color(0xFF141A24),
    tableSelected: Color(0xFF1E2A42),
    tableSelectedText: AppColors.textPrimary,
    buttonFace: AppColors.surfaceHigh,
    buttonHover: AppColors.surfaceHigh,
    buttonPrimary: AppColors.primary,
    buttonPrimaryHover: Color(0xFF8B7DF5),
    buttonDanger: Color(0xFFDC4C4C),
    buttonDangerHover: Color(0xFFE85D5D),
    link: AppColors.primary,
    linkHover: AppColors.accent,
    accent: AppColors.primary,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    inputBackground: AppColors.surfaceHigh,
    resizeHandle: Color(0xFF252D3D),
    resizeHandleHover: AppColors.primarySoft,
    existing: AppColors.existing,
    planned: AppColors.planned,
  );

  /// Классическая палитра 1С:Предприятие 8 — жёлтые формы, серая рамка.
  static const oneC = VariantPalette(
    isOneC: true,
    window: Color(0xFFD4D0C8),
    workArea: Color(0xFFFFFAD5),
    formBackground: Color(0xFFFFFAD5),
    panel: Color(0xFFECE9D8),
    panelHeader: Color(0xFFD4D0C8),
    toolbar: Color(0xFFECE9D8),
    titleBar: Color(0xFF0A246A),
    titleBarEnd: Color(0xFF3A6EA5),
    border: Color(0xFF808080),
    borderHighlight: Color(0xFFFFFFFF),
    borderShadow: Color(0xFF404040),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF333333),
    textMuted: Color(0xFF666666),
    textOnTitle: Color(0xFFFFFFFF),
    tableHeader: Color(0xFFE4DFC8),
    tableRow: Color(0xFFFFFFFF),
    tableZebra: Color(0xFFFFF6DC),
    tableSelected: Color(0xFF316AC5),
    tableSelectedText: Color(0xFFFFFFFF),
    buttonFace: Color(0xFFECE9D8),
    buttonHover: Color(0xFFF6F4EC),
    buttonPrimary: Color(0xFFECE9D8),
    buttonPrimaryHover: Color(0xFFF6F4EC),
    buttonDanger: Color(0xFFECE9D8),
    buttonDangerHover: Color(0xFFF6F4EC),
    link: Color(0xFF0000CC),
    linkHover: Color(0xFFFF0000),
    accent: Color(0xFF0A246A),
    success: Color(0xFF008000),
    warning: Color(0xFF804000),
    danger: Color(0xFFCC0000),
    inputBackground: Color(0xFFFFFFFF),
    resizeHandle: Color(0xFFC0C0C0),
    resizeHandleHover: Color(0xFF316AC5),
    existing: Color(0xFF808080),
    planned: Color(0xFF000080),
  );
}

/// ThemeExtension для доступа к палитре из [BuildContext].
@immutable
class VariantPaletteTheme extends ThemeExtension<VariantPaletteTheme> {
  const VariantPaletteTheme(this.palette);

  final VariantPalette palette;

  @override
  VariantPaletteTheme copyWith({VariantPalette? palette}) =>
      VariantPaletteTheme(palette ?? this.palette);

  @override
  VariantPaletteTheme lerp(ThemeExtension<VariantPaletteTheme>? other, double t) {
    if (other is! VariantPaletteTheme) return this;
    return t < 0.5 ? this : other;
  }
}

extension VariantPaletteContext on BuildContext {
  VariantPalette get palette =>
      Theme.of(this).extension<VariantPaletteTheme>()?.palette ??
      VariantPalette.dark;
}
