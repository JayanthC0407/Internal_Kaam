import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_descriptor.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/retail/dashboard_widgets/retail_widget_registry.dart';

/// A registry with nothing in it, to check the placeholder path.
class _EmptyRegistry extends DashboardWidgetRegistry {
  const _EmptyRegistry();

  @override
  Map<String, Widget Function()> get builders => const {};
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

    test('falls back to the factory dashboard when that is all there is', () {
      // A user who has never personalized still needs somewhere to save.
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

      expect(descriptor?.dashboardId, '9');
      expect(descriptor?.dashboardClassValue, 'retailuser');
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
