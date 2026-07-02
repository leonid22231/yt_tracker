import 'package:flutter/material.dart';
import 'package:youtrack_timer/ui/theme/app_colors.dart';

/// Базовые design tokens, общие для всех вариантов оформления.
abstract final class DesignTokens {
  // --- Spacing (шкала 4 px) ---
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;

  // --- Radii ---
  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 12.0;

  // --- Animation ---
  static const durationFast = Duration(milliseconds: 120);
  static const durationNormal = Duration(milliseconds: 180);
  static const curveStandard = Curves.easeOutCubic;

  // --- Breakpoints ---
  static const breakpointSmall = 800.0;
  static const breakpointLarge = 1400.0;
  static const breakpointUltrawide = 2400.0;

  /// Максимальная ширина центрального контента на ultrawide.
  static const contentMaxWidth = 1600.0;

  // --- Grid ---
  static const gridColumnsCompact = 8;
  static const gridColumnsLarge = 12;
  static const gutterCompact = 12.0;
  static const gutterLarge = 16.0;
  static const marginCompact = 16.0;
  static const marginLarge = 24.0;

  // --- Colors (WCAG AA на тёмном фоне) ---
  static const background = AppColors.background;
  static const surface = AppColors.surface;
  static const surfaceHigh = AppColors.surfaceHigh;
  static const border = AppColors.border;
  static const borderSubtle = Color(0xFF252D3D);
  static const accent = AppColors.primary;
  static const accentHover = Color(0xFF8B7DF5);
  static const accentMuted = AppColors.primarySoft;
  static const textPrimary = AppColors.textPrimary;
  static const textSecondary = AppColors.textSecondary;
  static const textMuted = AppColors.textMuted;
  static const focusRing = Color(0xFF7C6CF0);

  // --- Shadows (минимальные) ---
  static const shadowSm = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 4,
    offset: Offset(0, 1),
  );
}

/// Токены, специфичные для варианта оформления.
class VariantTokens {
  const VariantTokens({
    required this.sidebarWidth,
    required this.sidebarCompactWidth,
    required this.detailsPanelWidth,
    required this.detailsPanelMinWidth,
    required this.topBarHeight,
    required this.statusBarHeight,
    required this.panelPadding,
    required this.listItemPadding,
    required this.h1,
    required this.h2,
    required this.body,
    required this.caption,
    required this.lineHeight,
    required this.buttonRadius,
    required this.useGradients,
    required this.tableRowHeight,
    required this.tableCompactMode,
  });

  final double sidebarWidth;
  final double sidebarCompactWidth;
  final double detailsPanelWidth;
  final double detailsPanelMinWidth;
  final double topBarHeight;
  final double statusBarHeight;
  final EdgeInsets panelPadding;
  final EdgeInsets listItemPadding;
  final double h1;
  final double h2;
  final double body;
  final double caption;
  final double lineHeight;
  final double buttonRadius;
  final bool useGradients;
  final double tableRowHeight;
  final bool tableCompactMode;

  TextStyle get h1Style => TextStyle(
        fontSize: h1,
        fontWeight: FontWeight.w700,
        height: lineHeight,
        color: DesignTokens.textPrimary,
        letterSpacing: -0.2,
      );

  TextStyle get h2Style => TextStyle(
        fontSize: h2,
        fontWeight: FontWeight.w600,
        height: lineHeight,
        color: DesignTokens.textPrimary,
      );

  TextStyle get bodyStyle => TextStyle(
        fontSize: body,
        fontWeight: FontWeight.w400,
        height: lineHeight,
        color: DesignTokens.textPrimary,
      );

  TextStyle get captionStyle => TextStyle(
        fontSize: caption,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: DesignTokens.textSecondary,
      );

  static const current = VariantTokens(
    sidebarWidth: 300,
    sidebarCompactWidth: 300,
    detailsPanelWidth: 0,
    detailsPanelMinWidth: 0,
    topBarHeight: 96,
    statusBarHeight: 0,
    panelPadding: EdgeInsets.all(DesignTokens.space5),
    listItemPadding: EdgeInsets.symmetric(
      horizontal: DesignTokens.space5,
      vertical: DesignTokens.space3,
    ),
    h1: 20,
    h2: 16,
    body: 13,
    caption: 11,
    lineHeight: 1.45,
    buttonRadius: DesignTokens.radiusLg,
    useGradients: true,
    tableRowHeight: 72,
    tableCompactMode: false,
  );

  static const large = VariantTokens(
    sidebarWidth: 240,
    sidebarCompactWidth: 56,
    detailsPanelWidth: 360,
    detailsPanelMinWidth: 280,
    topBarHeight: 48,
    statusBarHeight: 28,
    panelPadding: EdgeInsets.all(DesignTokens.space4),
    listItemPadding: EdgeInsets.symmetric(
      horizontal: DesignTokens.space4,
      vertical: DesignTokens.space2,
    ),
    h1: 22,
    h2: 17,
    body: 14,
    caption: 12,
    lineHeight: 1.5,
    buttonRadius: DesignTokens.radiusSm,
    useGradients: false,
    tableRowHeight: 40,
    tableCompactMode: true,
  );
}
