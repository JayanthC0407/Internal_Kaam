import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';

/// A faithful slice of the real `moduleComponents.json`, chosen to cover
/// every shape the file actually contains:
///  - full entries with explicit `isVisible`/`isWidget`
///  - "short form" entries with neither flag (10 corporate-eligible
///    entries are like this, `currency-exposure` among them)
///  - a `common` segment entry
///  - an explicitly hidden entry
///  - an entry carrying `input.values` variants
Map<String, dynamic> _catalogSlice() => {
      'components': [
        {
          'componentName': 'account-financial-summary',
          'module': 'corporateDashboard',
          'segment': ['corporateuser'],
          'width': {'large': '8', 'medium': '12'},
          'height': '516',
          'isVisible': true,
          'isWidget': true,
        },
        {
          'componentName': 'account-quick-links',
          'module': 'corporateDashboard',
          'segment': ['corporateuser'],
          'width': {'large': '4', 'medium': '6'},
          'height': '251',
          'isVisible': true,
          'isWidget': true,
        },
        {
          // No isVisible / isWidget keys at all.
          'componentName': 'currency-exposure',
          'module': 'corporateDashboard',
          'segment': ['common'],
          'width': {'large': '4', 'medium': '6', 'small': '12'},
        },
        {
          'componentName': 'work-snapshot',
          'module': 'corporateDashboard',
          'segment': ['corporateuser'],
          'width': {'large': '4', 'medium': '6'},
          'height': '149',
          'isVisible': true,
          'isWidget': true,
        },
        {
          'componentName': 'trade-finance-links',
          'module': 'corporateDashboard',
          'segment': ['corporateuser'],
          'width': {'large': '', 'medium': ''},
          'isVisible': false,
          'isWidget': false,
        },
        {
          'componentName': 'bank-promotional-offers',
          'module': 'dashboard',
          'segment': ['retailuser', 'corporateuser'],
          'width': {'large': '4', 'medium': '12'},
          'isVisible': false,
          'isWidget': true,
        },
        {
          'componentName': 'net-worth-graph',
          'module': 'dashboard',
          'segment': ['retailuser'],
          'width': {'large': '4', 'medium': '12'},
          'isVisible': true,
          'isWidget': true,
        },
        {
          'componentName': 'dashboard-quick-links',
          'module': 'dashboard',
          'segment': ['corporateuser', 'retailuser', 'administrator'],
          'width': {'large': '4', 'medium': '6'},
          'input': {
            'options': ['type'],
            'values': {
              'type': [
                'payments-quick-links',
                'quick-access',
                'mutual-funds',
                'liquidity-management',
              ],
            },
          },
          'isVisible': true,
          'isWidget': true,
        },
      ],
    };

/// Everything in the slice is authorized for the captured corporate user
/// except `work-snapshot` — which is the real situation: it sits on their
/// saved dashboard yet is absent from `authorizedUIComponents`.
const _authorized = {
  'account-financial-summary',
  'account-quick-links',
  'currency-exposure',
  'trade-finance-links',
  'bank-promotional-offers',
  'net-worth-graph',
  'dashboard-quick-links',
};

void main() {
  group('DashboardWidgetDefinition', () {
    test('parses a full catalog entry', () {
      final catalog = DashboardWidgetCatalog.fromPayload(_catalogSlice());
      final definition = catalog.byName('account-financial-summary')!;

      expect(definition.module, 'corporateDashboard');
      expect(definition.segments, ['corporateuser']);
      expect(definition.widthFor('large'), '8');
      expect(definition.widthFor('small'), isNull);
      expect(definition.height, '516');
      expect(definition.isSelectable, isTrue);
    });

    test('treats absent isVisible/isWidget as no opinion, not exclusion', () {
      // The regression this guards: 10 corporate-eligible catalog entries
      // omit both flags, and `currency-exposure` is one of them — reading a
      // missing flag as false would drop a widget users really have.
      final catalog = DashboardWidgetCatalog.fromPayload(_catalogSlice());
      final definition = catalog.byName('currency-exposure')!;

      expect(definition.isVisible, isNull);
      expect(definition.isWidget, isNull);
      expect(definition.isSelectable, isTrue);
    });

    test('excludes entries either flag explicitly turns off', () {
      final catalog = DashboardWidgetCatalog.fromPayload(_catalogSlice());

      expect(catalog.byName('trade-finance-links')!.isSelectable, isFalse);
      // isWidget true but isVisible false — still not offered.
      expect(catalog.byName('bank-promotional-offers')!.isSelectable, isFalse);
    });

    test('segment matching honours the common wildcard', () {
      final catalog = DashboardWidgetCatalog.fromPayload(_catalogSlice());

      expect(
        catalog.byName('currency-exposure')!.appliesToSegment('corporateuser'),
        isTrue,
      );
      expect(
        catalog.byName('currency-exposure')!.appliesToSegment('retailuser'),
        isTrue,
      );
      expect(
        catalog.byName('net-worth-graph')!.appliesToSegment('corporateuser'),
        isFalse,
      );
    });

    test('keeps input variants so one component can serve several', () {
      final catalog = DashboardWidgetCatalog.fromPayload(_catalogSlice());
      expect(
        catalog.byName('dashboard-quick-links')!.inputOptions['type'],
        contains('payments-quick-links'),
      );
    });
  });

  group('DashboardWidgetCatalog.availableFor', () {
    test('applies segment AND authorization AND the catalog flags', () {
      final available = DashboardWidgetCatalog.fromPayload(_catalogSlice())
          .availableFor(
            userSegment: 'corporateuser',
            authorizedComponents: _authorized,
          )
          .map((definition) => definition.componentName)
          .toList();

      expect(
        available,
        [
          'account-financial-summary',
          'account-quick-links',
          'currency-exposure',
          'dashboard-quick-links',
        ],
      );

      // Wrong segment.
      expect(available, isNot(contains('net-worth-graph')));
      // Catalog says not selectable, even though authorized.
      expect(available, isNot(contains('trade-finance-links')));
      expect(available, isNot(contains('bank-promotional-offers')));
      // In the catalog and in the right segment, but not authorized.
      expect(available, isNot(contains('work-snapshot')));
    });

    test('a retail segment gets a different set from the same catalog', () {
      // Proves the rule is configuration-driven rather than role-hardcoded.
      final available = DashboardWidgetCatalog.fromPayload(_catalogSlice())
          .availableFor(
            userSegment: 'retailuser',
            authorizedComponents: _authorized,
          )
          .map((definition) => definition.componentName)
          .toList();

      expect(available, contains('net-worth-graph'));
      expect(available, contains('currency-exposure')); // common
      expect(available, isNot(contains('account-financial-summary')));
    });

    test('returns nothing when the authorization set is empty', () {
      final available = DashboardWidgetCatalog.fromPayload(_catalogSlice())
          .availableFor(
            userSegment: 'corporateuser',
            authorizedComponents: const <String>{},
          );
      expect(available, isEmpty);
    });

    test('a component the catalog has never heard of resolves to null', () {
      // Documents the version skew: 5 of the 10 components on the captured
      // user's saved dashboard (approval-transactions-widget,
      // cash-flow-summary, notification-widget, pickup-point-collections,
      // view-cash-flow-widget) are absent from this catalog yet authorized
      // in that environment. Rendering must not depend on a catalog hit.
      final catalog = DashboardWidgetCatalog.fromPayload(_catalogSlice());
      expect(catalog.byName('pickup-point-collections'), isNull);
    });
  });

  group('DashboardAuthorizedComponents', () {
    test('parses the me/components response', () {
      final parsed = DashboardAuthorizedComponents.fromPayload({
        'statusCode': 200,
        'body': {
          'status': {'result': 'SUCCESSFUL'},
          'authorizedUIComponents': [
            'account-financial-summary',
            'creditcard-transactions',
            '',
          ],
          'defaultDashboards': ['cash-management-overview', 'credit-card'],
        },
      });

      expect(parsed.authorized, hasLength(2));
      expect(parsed.contains('account-financial-summary'), isTrue);
      expect(parsed.contains('work-snapshot'), isFalse);
      expect(parsed.defaultDashboards, ['cash-management-overview', 'credit-card']);
    });

    test('degrades to empty rather than throwing on a bad payload', () {
      expect(DashboardAuthorizedComponents.fromPayload(null).isEmpty, isTrue);
      expect(DashboardAuthorizedComponents.fromPayload({'body': {}}).isEmpty, isTrue);
    });
  });
}
