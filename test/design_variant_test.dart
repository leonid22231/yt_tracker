import 'package:flutter_test/flutter_test.dart';
import 'package:youtrack_timer/ui/theme/design_tokens.dart';
import 'package:youtrack_timer/ui/theme/design_variant.dart';

void main() {
  group('DesignVariantContext', () {
    test('auto selects large at >= 1400px', () {
      expect(
        DesignVariantContext.resolveVariant(
          preference: DesignModePreference.auto,
          width: 1400,
        ),
        DesignVariant.large,
      );
      expect(
        DesignVariantContext.resolveVariant(
          preference: DesignModePreference.auto,
          width: 1399,
        ),
        DesignVariant.current,
      );
    });

    test('manual preference overrides auto threshold', () {
      expect(
        DesignVariantContext.resolveVariant(
          preference: DesignModePreference.large,
          width: 800,
        ),
        DesignVariant.large,
      );
      expect(
        DesignVariantContext.resolveVariant(
          preference: DesignModePreference.current,
          width: 2000,
        ),
        DesignVariant.current,
      );
    });

    test('large tokens use compact table row height', () {
      final ctx = DesignVariantContext.fromWidth(
        preference: DesignModePreference.large,
        width: 1600,
      );
      expect(ctx.tokens.tableCompactMode, isTrue);
      expect(ctx.tokens.tableRowHeight, 40);
    });
  });

  group('ShellLayoutState', () {
    test('roundtrips through json', () {
      const original = ShellLayoutState(
        leftNavExpanded: false,
        leftNavWidth: 200,
        detailsPanelWidth: 400,
        activeTabIndex: 1,
        selectedIssueId: 'PROJ-42',
        expandedIssueIds: {'PROJ-42'},
      );
      final restored =
          ShellLayoutState.fromJson(original.toJson());
      expect(restored.leftNavExpanded, false);
      expect(restored.leftNavWidth, 200);
      expect(restored.selectedIssueId, 'PROJ-42');
      expect(restored.expandedIssueIds, {'PROJ-42'});
    });
  });

  group('breakpoints', () {
    test('small threshold is 800', () {
      expect(DesignTokens.breakpointSmall, 800);
    });
  });
}
