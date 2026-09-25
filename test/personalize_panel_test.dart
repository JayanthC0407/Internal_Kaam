import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_descriptor.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/retail/dashboard_widgets/retail_widget_registry.dart';

/// A registry with nothing in it, to check the placeholder path.
class _EmptyRegistry extends DashboardWidgetRegistry {
  const _EmptyRegistry();

  @override
  Map<String, Widget Function()> get builders => const {};

  @override
  Map<String, DashboardWidgetSpec> get specs => const {};
}

void main() {
  group('DashboardDescriptor', () {
    test('picks the user\'s own dashboard over the factory one', () {
      // The captured `me` shape: a CUSTOM dashboard the user owns plus the
      // bank's factory USER_TYPE one. Personalization must target the
      // former, whose id is the PUT target.
      final descriptor = DashboardDescriptor.personalizableFromProfileResponse({
        'statusCode': 200,
        'body': {
          'userProfile': {'userName': 'nazcorp'},
          'dashboardResponse': {
            'dashboardDTOs': [
              {
                'dashboardId': '18',
                'dashboardClass': 'USER_TYPE',
                'dashboardClassValue': 'corporateuser',
                'factory': true,
              },
              {
                'dashboardId': '25801',
                'dashboardClass': 'CUSTOM',
                'dashboardClassValue': 'custom',
                'factory': false,
              },
            ],
          },
        },
      });

      expect(descriptor, isNotNull);
      expect(descriptor!.dashboardId, '25801');
      expect(descriptor.dashboardClass, 'CUSTOM');
      expect(descriptor.dashboardClassValue, 'custom');
    });

    test('never offers the factory dashboard as a write target', () {
      // A factory dashboard is shared by every user of the type — saving to
      // it would change the bank's default for all of them. What OBDX does
      // for a first-time user without a CUSTOM dashboard is unverified, so
      // such a user gets no personalization rather than a shared write.
      final descriptor = DashboardDescriptor.personalizableFromProfileResponse({
        'body': {
          'dashboardResponse': {
            'dashboardDTOs': [
              {
                'dashboardId': '9',
                'dashboardClass': 'USER_TYPE',
                'dashboardClassValue': 'retailuser',
                'factory': true,
              },
            ],
          },
        },
      });

      expect(descriptor, isNull);
    });

    test('rejects a non-factory dashboard that is not CUSTOM', () {
      // Being non-factory is not enough on its own — the user's own record
      // is the CUSTOM one.
      final descriptor = DashboardDescriptor.personalizableFromProfileResponse({
        'body': {
          'dashboardResponse': {
            'dashboardDTOs': [
              {
                'dashboardId': '40',
                'dashboardClass': 'USER_TYPE',
                'dashboardClassValue': 'retailuser',
                'factory': false,
              },
            ],
          },
        },
      });

      expect(descriptor, isNull);
    });

    test('returns null when me carried no usable dashboard', () {
      // Personalization is then unavailable rather than guessed at.
      expect(
        DashboardDescriptor.personalizableFromProfileResponse({'body': {}}),
        isNull,
      );
      expect(
        DashboardDescriptor.personalizableFromProfileResponse(null),
        isNull,
      );
      expect(
        DashboardDescriptor.personalizableFromProfileResponse({
          'body': {
            'dashboardResponse': {
              'dashboardDTOs': [
                {'dashboardId': '', 'dashboardClass': 'CUSTOM'},
              ],
            },
          },
        }),
        isNull,
      );
    });
  });

  group('DashboardDescriptorLookup.fromProfileResponse', () {
    test('no `me` response is unknown, not "no dashboard"', () {
      // What a session restore passes when its own `me` call failed.
      expect(
        DashboardDescriptorLookup.fromProfileResponse(null),
        isA<DashboardDescriptorUnknown>(),
      );
      expect(
        DashboardDescriptorLookup.fromProfileResponse(
            const {'statusCode': 500}),
        isA<DashboardDescriptorUnknown>(),
      );
    });

    test('a `me` without a CUSTOM dashboard is absent', () {
      expect(
        DashboardDescriptorLookup.fromProfileResponse(const {
          'statusCode': 200,
          'body': {
            'userProfile': {'userName': 'retail01'},
            'dashboardResponse': {
              'dashboardDTOs': [
                {
                  'dashboardId': '9',
                  'dashboardClass': 'USER_TYPE',
                  'dashboardClassValue': 'retailuser',
                  'factory': true,
                },
              ],
            },
          },
        }),
        isA<DashboardDescriptorAbsent>(),
      );
    });

    test('a `me` with a CUSTOM dashboard is found', () {
      final lookup = DashboardDescriptorLookup.fromProfileResponse(const {
        'statusCode': 200,
        'body': {
          'userProfile': {'userName': 'retail01'},
          'dashboardResponse': {
            'dashboardDTOs': [
              {
                'dashboardId': '25801',
                'dashboardClass': 'CUSTOM',
                'dashboardClassValue': 'custom',
                'factory': false,
              },
            ],
          },
        },
      });

      expect(lookup, isA<DashboardDescriptorFound>());
      expect(
        (lookup as DashboardDescriptorFound).descriptor.dashboardId,
        '25801',
      );
    });
  });

  group('DashboardWidgetRegistry', () {
    test('Corporate and Retail map different components', () {
      const corp = CorpWidgetRegistry();
      const retail = RetailWidgetRegistry();

      // The reason each user type gets its own registry: Retail's
      // `financial-summary` is a different component from Corporate's
      // `account-financial-summary`.
      expect(corp.isImplemented('account-financial-summary'), isTrue);
      expect(retail.isImplemented('account-financial-summary'), isFalse);

      expect(retail.isImplemented('financial-summary'), isTrue);
      expect(corp.isImplemented('financial-summary'), isFalse);

      // Corporate-only.
      expect(corp.isImplemented('pickup-point-collections'), isTrue);
      expect(retail.isImplemented('pickup-point-collections'), isFalse);

      // Retail-only.
      expect(retail.isImplemented('spend-summary'), isTrue);
      expect(corp.isImplemented('spend-summary'), isFalse);
    });

    test('each registry covers the components it claims', () {
      const corp = CorpWidgetRegistry();
      const retail = RetailWidgetRegistry();

      expect(corp.implementedComponents, isNotEmpty);
      expect(retail.implementedComponents, isNotEmpty);
      for (final name in corp.implementedComponents) {
        expect(corp.builders[name], isNotNull);
      }
      for (final name in retail.implementedComponents) {
        expect(retail.builders[name], isNotNull);
      }
    });

    test('every built widget declares its grid size', () {
      // A builder without a spec falls back to a guessed size — the gap
      // that left five of Retail's six widgets full width, one per row.
      for (final registry in const <DashboardWidgetRegistry>[
        CorpWidgetRegistry(),
        RetailWidgetRegistry(),
      ]) {
        for (final name in registry.implementedComponents) {
          expect(
            registry.specs[name],
            isNotNull,
            reason: '${registry.runtimeType} builds $name but gives no size',
          );
        }
      }
    });

    test('Retail widgets absent from the catalog are no longer full width', () {
      const retail = RetailWidgetRegistry();
      for (final name in const [
        'casa-account-card',
        'casa-balance-card',
        'loans-account-card',
        'loans-balance-card',
        'credit-card',
      ]) {
        // No catalog passed: these have no catalog entry at all.
        expect(
          retail.spanFor(name, breakpoint: DashboardBreakpoint.large),
          lessThan(12),
          reason: name,
        );
      }
    });

    test('the app size wins over a saved blanket oj-lg-12', () {
      // Earlier builds saved every widget they could not size as 12.
      const retail = RetailWidgetRegistry();
      expect(
        retail.spanFor(
          'loans-balance-card',
          breakpoint: DashboardBreakpoint.large,
          style: 'oj-lg-12',
        ),
        6,
      );
    });

    test('Corporate widgets are half the row, bar the Account Summary table',
        () {
      const corp = CorpWidgetRegistry();
      for (final name in corp.implementedComponents) {
        expect(
          corp.spanFor(name, breakpoint: DashboardBreakpoint.large),
          name == 'account-summary' ? 12 : 6,
          reason: name,
        );
      }
    });

    test('Retail widgets are half the row, like the fixed home', () {
      const retail = RetailWidgetRegistry();
      for (final name in retail.implementedComponents) {
        expect(
          retail.spanFor(name, breakpoint: DashboardBreakpoint.large),
          6,
          reason: name,
        );
      }
    });

    test('Retail widgets with a card keep it; bare ones get one', () {
      const retail = RetailWidgetRegistry();
      DashboardTile tile(String name) => retail.tileFor(
            DashboardLayoutItem(componentName: name, module: 'm'),
            breakpoint: DashboardBreakpoint.large,
          );

      // Drawn exactly as on the fixed home.
      expect(tile('spend-summary').framed, isFalse);
      expect(tile('recent-account-transactions').framed, isFalse);
      // The bare list has no card or heading of its own.
      expect(tile('casa-account-card').framed, isTrue);
      expect(tile('casa-account-card').title, 'My Accounts');
    });

    test('a widget the user made full width is drawn full width', () {
      const retail = RetailWidgetRegistry();
      expect(
        retail.spanFor(
          'loans-balance-card',
          breakpoint: DashboardBreakpoint.large,
          style: 'oj-lg-12 user-sized',
        ),
        12,
      );
    });

    test('phones always use the full width', () {
      const corp = CorpWidgetRegistry();
      expect(
        corp.spanFor('currency-exposure',
            breakpoint: DashboardBreakpoint.small),
        12,
      );
    });

    test('an unknown component gets a typical size, not the full row', () {
      const corp = CorpWidgetRegistry();
      expect(
        corp.spanFor('bulk-file-upload', breakpoint: DashboardBreakpoint.large),
        4,
      );
      expect(
        corp.spanFor(
          'bulk-file-upload',
          breakpoint: DashboardBreakpoint.medium,
        ),
        6,
      );
    });

    test('every Retail default component is one the registry can build', () {
      // The Retail dashboard draws its unpersonalized layout from
      // `defaultComponents`, so an entry with no builder would render as a
      // "not available" placeholder on a dashboard nobody personalized.
      const retail = RetailWidgetRegistry();
      for (final name in RetailWidgetRegistry.defaultComponents) {
        expect(
          retail.isImplemented(name),
          isTrue,
          reason: '$name is in the default layout but has no builder',
        );
      }
    });

    testWidgets('builds a named placeholder for an unimplemented component',
        (tester) async {
      // A component the user selected must not silently vanish — it stays
      // in the saved layout and the web client can still render it.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const _EmptyRegistry().build('bulk-file-upload'),
          ),
        ),
      );

      expect(find.text('Bulk File Upload'), findsOneWidget);
      expect(find.text('Not available in this app yet'), findsOneWidget);
    });

    testWidgets('names a component the catalog has never heard of',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const _EmptyRegistry().build('unreconciled-cash-flows'),
          ),
        ),
      );

      expect(find.text('Unreconciled Cash Flows'), findsOneWidget);
    });
  });
}
