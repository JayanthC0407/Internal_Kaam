import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';

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
  group('DashboardConfig parsing', () {
    test('reads the captured dashboard DTO', () {
      final config = DashboardConfig.fromPayload(_capturedConfig());

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
      final config = DashboardConfig.fromPayload({
        'statusCode': 200,
        'headers': <String, dynamic>{},
        'body': _capturedConfig(),
      });
      expect(config?.dashboardId, '25801');
    });

    test('parses every breakpoint, including the empty defaultLayout', () {
      final config = DashboardConfig.fromPayload(_capturedConfig())!;

      expect(config.layoutFor(DashboardBreakpoint.defaultLayout), isEmpty);
      expect(config.layoutFor(DashboardBreakpoint.large), hasLength(2));
      expect(config.layoutFor(DashboardBreakpoint.medium), hasLength(2));
      expect(config.layoutFor(DashboardBreakpoint.small), hasLength(5));
    });

    test('de-duplicates the selection the host stores with repeats', () {
      final config = DashboardConfig.fromPayload(_capturedConfig())!;

      // `small` holds 5 items for 3 distinct widgets.
      expect(config.hasDuplicatesAt(DashboardBreakpoint.small), isTrue);
      expect(
        config.selectedComponentsAt(DashboardBreakpoint.small),
        ['work-snapshot', 'approval-transactions-widget',
          'account-financial-summary'],
      );

      expect(config.hasDuplicatesAt(DashboardBreakpoint.large), isFalse);
    });

    test('returns null for a payload with no dashboardDTO', () {
      expect(DashboardConfig.fromPayload({'body': {}}), isNull);
      expect(DashboardConfig.fromPayload(null), isNull);
    });

    test('refuses the metadata-only body the save endpoint returns', () {
      // Verbatim from widgets(corp).har entry #4 — the PUT response. It has
      // a complete-looking dashboardDTO but no `layout` key at all.
      //
      // Regression: this used to parse into a config with every breakpoint
      // empty. Storing that as the current state and saving again wiped
      // `medium` and `small` on the host.
      final putResponse = DashboardConfig.fromPayload({
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
      final config = DashboardConfig.fromPayload({
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
      expect(config!.layoutFor(DashboardBreakpoint.large), isEmpty);
    });
  });

  group('DashboardBreakpoint.forWidth', () {
    test('maps viewport width to the Oracle JET breakpoint', () {
      expect(DashboardBreakpoint.forWidth(390), DashboardBreakpoint.small);
      expect(DashboardBreakpoint.forWidth(767), DashboardBreakpoint.small);
      expect(DashboardBreakpoint.forWidth(768), DashboardBreakpoint.medium);
      expect(DashboardBreakpoint.forWidth(1023), DashboardBreakpoint.medium);
      expect(DashboardBreakpoint.forWidth(1024), DashboardBreakpoint.large);
      expect(DashboardBreakpoint.forWidth(1440), DashboardBreakpoint.large);
    });
  });

  group('DashboardConfig save payload', () {
    test('round-trips every item of an untouched config', () {
      // Compared field-by-field rather than by raw map equality, because
      // the PUT shape legitimately differs from the GET: the captured save
      // strips `childPanel` from every item (verified against
      // widgets(corp).har entry #4, where the GET has it on all items and
      // the PUT on none) and writes the keys in a different order.
      final source = _capturedConfig();
      final config = DashboardConfig.fromPayload(source)!;
      final rebuilt =
          (config.toUpdatePayload()['layout'] as Map)['layout'] as Map;
      final original = (((source['dashboardDTO'] as Map)['layout']
          as Map)['layout']) as Map;

      for (final breakpoint in DashboardBreakpoint.values) {
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
      final config = DashboardConfig.fromPayload(source)!;

      final edited = config.withLayout(DashboardBreakpoint.small, [
        const DashboardLayoutItem(
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
      final config = DashboardConfig.fromPayload(_capturedConfig())!;
      final rebuilt = config.toUpdatePayload();
      expect(rebuilt.toString().contains('childPanel'), isFalse);
    });

    test('preserves an item that has no data key', () {
      // The captured config mixes items with and without `data`; writing
      // one in where the host had none would itself be a change.
      final config = DashboardConfig.fromPayload(_capturedConfig())!;
      final small = config.layoutFor(DashboardBreakpoint.small);

      expect(small.first.data, isNull);
      expect(small.first.toJson().containsKey('data'), isFalse);
      expect(small.last.data, '{}');
      expect(small.last.toJson()['data'], '{}');
    });

    test('sends waterfallLayout back exactly as received', () {
      final config = DashboardConfig.fromPayload(_capturedConfig())!;
      final payload = config.toUpdatePayload();

      // The save replaces the whole `layout` object, so a waterfall that is
      // not sent back is at risk of being cleared.
      expect(
        (payload['layout'] as Map)['waterfallLayout'],
        {'defaultLayout': [], 'large': [], 'medium': [], 'small': []},
      );
      expect(payload.keys, ['dashboardName', 'dashboardDescription', 'layout']);
    });

    test('preserves a populated waterfallLayout through an edit', () {
      // The captured waterfall is empty, which is why omitting it looked
      // harmless. A populated one is the case that matters: editing `large`
      // must not lose it.
      final source = _capturedConfig();
      final layout = (source['dashboardDTO'] as Map)['layout'] as Map;
      layout['waterfallLayout'] = {
        'defaultLayout': [],
        'large': [
          {
            'componentName': 'account-quick-links',
            'module': 'corporateDashboard',
            'style': 'oj-lg-4',
            'childPanel': [],
          },
        ],
        'medium': [],
        'small': [],
      };

      final edited = DashboardConfig.fromPayload(source)!.withLayout(
        DashboardBreakpoint.large,
        const [
          DashboardLayoutItem(
            componentName: 'currency-exposure',
            module: 'corporateDashboard',
            style: 'oj-lg-4',
          ),
        ],
      );
      final sent = (edited.toUpdatePayload()['layout'] as Map)['waterfallLayout']
          as Map;

      // Verbatim — including `childPanel`, which the regular layout strips.
      // Nothing here edits the waterfall, so nothing should reshape it.
      expect(sent['large'], [
        {
          'componentName': 'account-quick-links',
          'module': 'corporateDashboard',
          'style': 'oj-lg-4',
          'childPanel': [],
        },
      ]);
    });

    test('does not invent a waterfallLayout the host never sent', () {
      final source = _capturedConfig();
      ((source['dashboardDTO'] as Map)['layout'] as Map)
          .remove('waterfallLayout');

      final payload = DashboardConfig.fromPayload(source)!.toUpdatePayload();
      expect((payload['layout'] as Map).containsKey('waterfallLayout'), isFalse);
    });

    test('the payload does not alias the config it came from', () {
      // A caller mutating what it is about to send must not be able to
      // reach back and change the stored configuration.
      final config = DashboardConfig.fromPayload(_capturedConfig())!;
      final first = config.toUpdatePayload();
      ((first['layout'] as Map)['waterfallLayout'] as Map)['large'] = ['x'];

      final second = config.toUpdatePayload();
      expect(((second['layout'] as Map)['waterfallLayout'] as Map)['large'],
          isEmpty);
    });
  });

  group('DashboardConfig.isUserCustom', () {
    test('is true only for a non-factory CUSTOM dashboard', () {
      expect(DashboardConfig.fromPayload(_capturedConfig())!.isUserCustom,
          isTrue);

      final factory = _capturedConfig();
      (factory['dashboardDTO'] as Map)
        ..['factory'] = true
        ..['dashboardClass'] = 'USER_TYPE'
        ..['dashboardClassValue'] = 'corporateuser';
      expect(DashboardConfig.fromPayload(factory)!.isUserCustom, isFalse);

      // A host could answer a CUSTOM request with a factory record; the
      // factory flag alone must be enough to refuse it.
      final customButFactory = _capturedConfig();
      (customButFactory['dashboardDTO'] as Map)['factory'] = true;
      expect(DashboardConfig.fromPayload(customButFactory)!.isUserCustom,
          isFalse);
    });
  });
}
