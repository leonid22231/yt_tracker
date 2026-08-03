import 'package:flutter/material.dart';
import 'package:youtrack_timer/ui/theme/one_c_decorations.dart';
import 'package:youtrack_timer/ui/theme/variant_palette.dart';
import 'package:youtrack_timer/ui/widgets/business/one_c_title_bar.dart';

/// Панель инструментов: 1С (desktop large) или компактная (fallback).
class BusinessToolbar extends StatelessWidget {
  const BusinessToolbar({
    super.key,
    required this.palette,
    required this.actions,
    this.trailing,
  });

  final VariantPalette palette;
  final List<Widget> actions;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: palette.toolbar,
        border: Border(
          bottom: BorderSide(color: palette.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          ...actions,
          const Spacer(),
          if (trailing != null) ...trailing!,
        ],
      ),
    );
  }
}

/// Вкладки формы 1С.
class BusinessTabStrip extends StatelessWidget {
  const BusinessTabStrip({
    super.key,
    required this.palette,
    required this.tabController,
    required this.tabs,
  });

  final VariantPalette palette;
  final TabController tabController;
  final List<({IconData icon, String label})> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: palette.formBackground,
        border: Border(
          bottom: BorderSide(color: palette.border),
        ),
      ),
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2,
        indicatorColor: palette.accent,
        labelColor: palette.textPrimary,
        unselectedLabelColor: palette.textMuted,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: [
          for (final t in tabs)
            Tab(
              height: 26,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon, size: 13),
                  const SizedBox(width: 4),
                  Text(t.label),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Обёртка верхней части large-режима: синяя полоса + toolbar + вкладки.
class BusinessTopChrome extends StatelessWidget {
  const BusinessTopChrome({
    super.key,
    required this.palette,
    required this.title,
    this.subtitle,
    required this.toolbar,
    required this.tabStrip,
  });

  final VariantPalette palette;
  final String title;
  final String? subtitle;
  final Widget toolbar;
  final Widget tabStrip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OneCTitleBar(
          palette: palette,
          title: title,
          subtitle: subtitle,
        ),
        toolbar,
        tabStrip,
      ],
    );
  }
}

/// Блок формы 1С с рамкой.
class BusinessFormSection extends StatelessWidget {
  const BusinessFormSection({
    super.key,
    required this.palette,
    required this.title,
    required this.child,
    this.trailing,
    this.dense = false,
  });

  final VariantPalette palette;
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: OneCDecorations.flatPanel(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: dense ? 4 : 6,
            ),
            decoration: OneCDecorations.groupHeader(palette),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(dense ? 8 : 10),
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 12, color: palette.textPrimary),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка реквизита формы 1С.
class BusinessFormField extends StatelessWidget {
  const BusinessFormField({
    super.key,
    required this.palette,
    required this.label,
    this.value,
    this.valueWidget,
  });

  final VariantPalette palette;
  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: palette.textSecondary),
            ),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value ?? '—',
                  style: TextStyle(fontSize: 11, color: palette.textPrimary),
                ),
          ),
        ],
      ),
    );
  }
}
