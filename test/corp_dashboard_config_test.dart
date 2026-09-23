import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/corp/corp_dashboard_config.dart';

/// The real `GET /digx-admin/config/v1/dashboards/modules?class=CUSTOM&value=custom`
/// response from `widgets(corp).har` (entry #3), trimmed only by dropping
/// items — the duplicates in `medium`/`small` are reproduced exactly as the
/// host stores them.
Map<String, dynamic> _capturedConfig() => {
      'status': {'result': 'SUCCESSFUL', 'apiType': 'config'},
      'dashboardDTO': {
        'enterpriseRole': 'corporateuser',
        'author': 'nazcorp',
        'dashboardId': '25801',
        'dashboardName': 'obdx4b6t4v2r6hq1934rp6t6n5i2g43222r777u29',
        'dashboardDescription': 'obdxi5c4243a5f7a1n3n6rt4d5e47747e143k5n40',
        'layout': {
          'layout': {
            'defaultLayout': [],
            'large': [
              {
                'style': 'oj-lg-8',
                'componentName': 'account-financial-summary',
                'childPanel': [],
                'data': '{}',
                'module': 'corporateDashboard',
              },
              {
                'style': 'oj-lg-4',
                'componentName': 'account-quick-links',
                'childPanel': [],
                'data': '{}',
                'module': 'corporateDashboard',
              },
            ],
            'medium': [
              {
                'style': 'oj-md-12',
                'componentName': 'account-financial-summary',
                'childPanel': [],
                'module': 'corporateDashboard',
              },
              {
                'style': 'oj-md-6',
                'componentName': 'account-financial-summary',
                'childPanel': [],
                'data': '{}',
                'module': 'corporateDashboard',
              },
            ],
            'small': [
              {
                'style': 'oj-sm-12',
                'componentName': 'work-snapshot',
                'childPanel': [],
                'module': 'corporateDashboard',
              },
              {
                'style': 'oj-sm-12',
                'componentName': 'approval-transactions-widget',
                'childPanel': [],
                'module': 'corporateDashboard',
              },
              {
                'style': 'oj-sm-12',
                'componentName': 'account-financial-summary',
                'childPanel': [],
                'module': 'corporateDashboard',
              },
              {
                'style': 'oj-sm-12',
                'componentName': 'approval-transactions-widget',
                'childPanel': [],
                'data': '{}',
                'module': 'corporateDashboard',
              },
              {
                'style': 'oj-sm-12',
                'componentName': 'approval-transactions-widget',
                'childPanel': [],
                'data': '{}',
                'module': 'corporateDashboard',
              },
            ],
          },
          'waterfallLayout': {
            'defaultLayout': [],
            'large': [],
            'medium': [],
            'small': [],
          },
        },
        'creationDate': '2026-09-11T07:17:37',
        'dashboardClass': 'CUSTOM',
        'dashboardClassValue': 'custom',
        'factory': false,
      },
    };

/// The fields that must survive a save, in order — everything the host
/// stores about a layout item except `childPanel`, which the captured PUT
/// drops.
List<String> _fingerprint(dynamic layoutArray) {
  if (layoutArray is! List) return const [];
  return [
    for (final item in layoutArray)
      if (item is Map)
        '${item['componentName']}|${item['module']}|'
            '${item.containsKey('data') ? item['data'] : '<none>'}|'
            '${item['style']}',
  ];
}

void main() {
  group('CorpDashboardConfig parsing', () {
    test('reads the captured dashboard DTO', () {
      final config = CorpDashboardConfig.fromPayload(_capturedConfig());

      expect(config, isNotNull);
      expect(config!.dashboardId, '25801');
      expect(config.dashboardClass, 'CUSTOM');
      expect(config.dashboardClassValue, 'custom');
      expect(config.enterpriseRole, 'corporateuser');
      expect(config.isFactory, isFalse);
      // Opaque host names must survive verbatim — they are echoed on save.
      expect(
        config.dashboardName,
        'obdx4b6t4v2r6hq1934rp6t6n5i2g43222r777u29',
      );
    });

    test('unwraps the wrapHttpResponse envelope', () {
      final config = CorpDashboardConfig.fromPayload({
        'statusCode': 200,
        'headers': <String, dynamic>{},
        'body': _capturedConfig(),
      });
      expect(config?.dashboardId, '25801');
    });

    test('parses every breakpoint, including the empty defaultLayout', () {
      final config = CorpDashboardConfig.fromPayload(_capturedConfig())!;

      expect(config.layoutFor(CorpLayoutBreakpoint.defaultLayout), isEmpty);
      expect(config.layoutFor(CorpLayoutBreakpoint.large), hasLength(2));
      expect(config.layoutFor(CorpLayoutBreakpoint.medium), hasLength(2));
      expect(config.layoutFor(CorpLayoutBreakpoint.small), hasLength(5));
    });

    test('de-duplicates the selection the host stores with repeats', () {
      final config = CorpDashboardConfig.fromPayload(_capturedConfig())!;

      // `small` holds 5 items for 3 distinct widgets.
      expect(config.hasDuplicatesAt(CorpLayoutBreakpoint.small), isTrue);
      expect(
        config.selectedComponentsAt(CorpLayoutBreakpoint.small),
        ['work-snapshot', 'approval-transactions-widget',
          'account-financial-summary'],
      );

      expect(config.hasDuplicatesAt(CorpLayoutBreakpoint.large), isFalse);
    });

    test('returns null for a payload with no dashboardDTO', () {
      expect(CorpDashboardConfig.fromPayload({'body': {}}), isNull);
      expect(CorpDashboardConfig.fromPayload(null), isNull);
    });

    test('refuses the metadata-only body the save endpoint returns', () {
      // Verbatim from widgets(corp).har entry #4 — the PUT response. It has
      // a complete-looking dashboardDTO but no `layout` key at all.
      //
      // Regression: this used to parse into a config with every breakpoint
      // empty. Storing that as the current state and saving again wiped
      // `medium` and `small` on the host.
      final putResponse = CorpDashboardConfig.fromPayload({
        'status': {'result': 'SUCCESSFUL', 'message': {'type': 'INFO'}},
        'dashboardDTO': {
          'enterpriseRole': 'corporateuser',
          'author': 'nazcorp',
          'authorType': 'corporateuser',
          'dashboardId': '25801',
          'dashboardName': 'obdx4b6t4v2r6hq1934rp6t6n5i2g43222r777u29',
          'dashboardDescription': 'obdxi5c4243a5f7a1n3n6rt4d5e47747e143k5n40',
          'creationDate': '2026-09-11T07:17:37',
          'dashboardClass': 'CUSTOM',
          'dashboardClassValue': 'custom',
          'factory': false,
        },
      });

      expect(putResponse, isNull);
    });

    test('still parses a dashboard whose layouts are genuinely empty', () {
      // The distinction the guard has to preserve: an empty layout *object*
      // is a real, parseable dashboard; a missing one is not.
      final config = CorpDashboardConfig.fromPayload({
        'dashboardDTO': {
          'dashboardId': '25801',
          'dashboardName': 'n',
          'dashboardDescription': 'd',
          'layout': {
            'layout': {
              'defaultLayout': [],
              'large': [],
              'medium': [],
              'small': [],
            },
          },
        },
      });

      expect(config, isNotNull);
      expect(config!.layoutFor(CorpLayoutBreakpoint.large), isEmpty);
    });
  });

  group('CorpLayoutBreakpoint.forWidth', () {
    test('maps viewport width to the Oracle JET breakpoint', () {
      expect(CorpLayoutBreakpoint.forWidth(390), CorpLayoutBreakpoint.small);
      expect(CorpLayoutBreakpoint.forWidth(767), CorpLayoutBreakpoint.small);
      expect(CorpLayoutBreakpoint.forWidth(768), CorpLayoutBreakpoint.medium);
      expect(CorpLayoutBreakpoint.forWidth(1023), CorpLayoutBreakpoint.medium);
      expect(CorpLayoutBreakpoint.forWidth(1024), CorpLayoutBreakpoint.large);
      expect(CorpLayoutBreakpoint.forWidth(1440), CorpLayoutBreakpoint.large);
    });
  });

  group('CorpDashboardConfig save payload', () {
    test('round-trips every item of an untouched config', () {
      // Compared field-by-field rather than by raw map equality, because
      // the PUT shape legitimately differs from the GET: the captured save
      // strips `childPanel` from every item (verified against
      // widgets(corp).har entry #4, where the GET has it on all items and
      // the PUT on none) and writes the keys in a different order.
      final source = _capturedConfig();
      final config = CorpDashboardConfig.fromPayload(source)!;
      final rebuilt =
          (config.toUpdatePayload()['layout'] as Map)['layout'] as Map;
      final original = (((source['dashboardDTO'] as Map)['layout']
          as Map)['layout']) as Map;

      for (final breakpoint in CorpLayoutBreakpoint.values) {
        expect(
          _fingerprint(rebuilt[breakpoint.key]),
          _fingerprint(original[breakpoint.key]),
          reason: '${breakpoint.key} must survive a parse/serialize cycle '
              'with every item intact, duplicates and all',
        );
      }
    });

    test('editing one breakpoint leaves every other one untouched', () {
      // The constraint the captured PUT imposes: it replaces the whole
      // layout object, so a mobile edit that dropped `large` would wipe the
      // user's desktop dashboard.
      final source = _capturedConfig();
      final config = CorpDashboardConfig.fromPayload(source)!;

      final edited = config.withLayout(CorpLayoutBreakpoint.small, [
        const CorpDashboardLayoutItem(
          componentName: 'currency-exposure',
          module: 'corporateDashboard',
          data: '{}',
          style: 'oj-sm-12',
        ),
      ]);

      final original = (((source['dashboardDTO'] as Map)['layout']
          as Map)['layout']) as Map;
      final rebuilt = (edited.toUpdatePayload()['layout'] as Map)['layout']
          as Map;

      // Untouched breakpoints still carry exactly what the host sent us.
      expect(_fingerprint(rebuilt['large']), _fingerprint(original['large']));
      expect(_fingerprint(rebuilt['medium']), _fingerprint(original['medium']));
      expect(rebuilt['defaultLayout'], isEmpty);

      // Only `small` changed, and in the key shape the captured PUT uses.
      expect(rebuilt['small'], [
        {
          'componentName': 'currency-exposure',
          'module': 'corporateDashboard',
          'data': '{}',
          'style': 'oj-sm-12',
        },
      ]);
    });

    test('strips childPanel on save, as the captured PUT does', () {
      final config = CorpDashboardConfig.fromPayload(_capturedConfig())!;
      final rebuilt = config.toUpdatePayload();
      expect(rebuilt.toString().contains('childPanel'), isFalse);
    });

    test('preserves an item that has no data key', () {
      // The captured config mixes items with and without `data`; writing
      // one in where the host had none would itself be a change.
      final config = CorpDashboardConfig.fromPayload(_capturedConfig())!;
      final small = config.layoutFor(CorpLayoutBreakpoint.small);

      expect(small.first.data, isNull);
      expect(small.first.toJson().containsKey('data'), isFalse);
      expect(small.last.data, '{}');
      expect(small.last.toJson()['data'], '{}');
    });

    test('omits waterfallLayout, matching the captured PUT', () {
      final config = CorpDashboardConfig.fromPayload(_capturedConfig())!;
      final payload = config.toUpdatePayload();

      expect((payload['layout'] as Map).containsKey('waterfallLayout'), isFalse);
      expect(payload.keys, ['dashboardName', 'dashboardDescription', 'layout']);
    });
  });
}
