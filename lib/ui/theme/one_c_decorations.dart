import 'package:flutter/material.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';

/// Декорации в стиле 1С: выпуклые/вдавленные рамки Windows Classic.
abstract final class OneCDecorations {
  static BoxDecoration raised(VariantPalette p, {Color? color}) => BoxDecoration(
        color: color ?? p.buttonFace,
        border: Border(
          top: BorderSide(color: p.borderHighlight),
          left: BorderSide(color: p.borderHighlight),
          bottom: BorderSide(color: p.borderShadow),
          right: BorderSide(color: p.borderShadow),
        ),
      );

  static BoxDecoration sunken(VariantPalette p) => BoxDecoration(
        color: p.inputBackground,
        border: Border(
          top: BorderSide(color: p.borderShadow),
          left: BorderSide(color: p.borderShadow),
          bottom: BorderSide(color: p.borderHighlight),
          right: BorderSide(color: p.borderHighlight),
        ),
      );

  static BoxDecoration flatPanel(VariantPalette p) => BoxDecoration(
        color: p.formBackground,
        border: Border.all(color: p.border),
      );

  static BoxDecoration groupHeader(VariantPalette p) => BoxDecoration(
        color: p.panelHeader,
        border: Border(
          bottom: BorderSide(color: p.border),
        ),
      );
}
