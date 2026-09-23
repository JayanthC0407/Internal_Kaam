import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/corp/corp_dashboard_config.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_dashboard_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_dashboard_repository.dart';

/// Stands in for the host. Records what was PUT and serves the GET, so the
/// test can assert on the exact payload the repository sends.
class _FakeDashboardApi implements ObdxCorpDashboardApi {
  _FakeDashboardApi({required this.stored});

  /// The layout the "host" currently holds, in GET response shape.
  Map<String, dynamic> stored;

  /// Payloads received by the PUT, in order.
  final List<Map<String, dynamic>> puts = [];

  /// Set true to make the re-fetch after saving fail, exercising the
  /// fallback path.
  bool failRefetch = false;

  int getCount = 0;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchDashboardConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async {
    getCount++;
    if (failRefetch && getCount > 1) {
      return ResponseHandler.error(500, 'boom');
    }
    return ResponseHandler.success({
      'statusCode': 200,
      'body': {'dashboardDTO': stored},
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> saveDashboardConfig({
    required String dashboardId,
    required Map<String, dynamic> payload,
  }) async {
    puts.add(payload);

    // Apply the write the way the host does — replace the whole layout.
    final layout = (payload['layout'] as Map)['layout'] as Map;
    stored = {
      ...stored,
      'layout': {'layout': Map<String, dynamic>.from(layout)},
    };

    // The real save returns metadata only — no layout. This is the shape
    // that caused the bug.
    return ResponseHandler.success({
      'statusCode': 200,
      'body': {
        'status': {'result': 'SUCCESSFUL'},
        'dashboardDTO': {
          'dashboardId': dashboardId,
          'dashboardName': 'obdx-name',
          'dashboardDescription': 'obdx-description',
          'dashboardClass': 'CUSTOM',
          'dashboardClassValue': 'custom',
          'factory': false,
        },
      },
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

Map<String, dynamic> _storedDashboard() => {
      'dashboardId': '25801',
      'dashboardName': 'obdx-name',
      'dashboardDescription': 'obdx-description',
      'dashboardClass': 'CUSTOM',
      'dashboardClassValue': 'custom',
      'factory': false,
      'layout': {
        'layout': {
          'defaultLayout': [],
          'large': [
            {
              'style': 'oj-lg-8',
              'componentName': 'account-financial-summary',
              'module': 'corporateDashboard',
            },
          ],
          'medium': [
            {
              'style': 'oj-md-12',
              'componentName': 'work-snapshot',
              'module': 'corporateDashboard',
            },
          ],
          'small': [
            {
              'style': 'oj-sm-12',
              'componentName': 'bulk-file-upload',
              'module': 'corporateDashboard',
            },
          ],
        },
      },
    };

List<String> _names(dynamic array) {
  if (array is! List) return const [];
  return [
    for (final item in array)
      if (item is Map) item['componentName'].toString(),
  ];
}

void main() {
  group('CorpDashboardRepository.saveConfig', () {
    test('editing large leaves medium and small untouched on the host',
        () async {
      // The exact scenario reported: personalize on a desktop screen, and
      // the phone and tablet layouts come back empty.
      final api = _FakeDashboardApi(stored: _storedDashboard());
      final repository = CorpDashboardRepository(dashboardApi: api);

      final loaded = await repository.fetchConfig(
        dashboardClass: 'CUSTOM',
        dashboardClassValue: 'custom',
      );
      final config = (loaded as Success<CorpDashboardConfig>).data!;

      final edited = config.withLayout(CorpLayoutBreakpoint.large, [
        const CorpDashboardLayoutItem(
          componentName: 'currency-exposure',
          module: 'corporateDashboard',
          style: 'oj-lg-4',
        ),
      ]);

      await repository.saveConfig(edited);

      final sent = (api.puts.single['layout'] as Map)['layout'] as Map;
      expect(_names(sent['large']), ['currency-exposure']);
      // The untouched breakpoints must still carry their widgets.
      expect(_names(sent['medium']), ['work-snapshot']);
      expect(_names(sent['small']), ['bulk-file-upload']);
    });

    test('a second save does not wipe what the first one preserved',
        () async {
      // The actual failure mode: the first save was fine, but the
      // layout-less PUT response replaced in-memory state with empties, so
      // the *second* save blanked medium and small.
      final api = _FakeDashboardApi(stored: _storedDashboard());
      final repository = CorpDashboardRepository(dashboardApi: api);

      final loaded = await repository.fetchConfig(
        dashboardClass: 'CUSTOM',
        dashboardClassValue: 'custom',
      );
      var config = (loaded as Success<CorpDashboardConfig>).data!;

      for (final component in ['currency-exposure', 'account-quick-links']) {
        final edited = config.withLayout(CorpLayoutBreakpoint.large, [
          CorpDashboardLayoutItem(
            componentName: component,
            module: 'corporateDashboard',
            style: 'oj-lg-4',
          ),
        ]);
        final result = await repository.saveConfig(edited);
        config = (result as Success<CorpDashboardConfig>).data!;
      }

      expect(api.puts, hasLength(2));
      final second = (api.puts.last['layout'] as Map)['layout'] as Map;
      expect(_names(second['large']), ['account-quick-links']);
      expect(_names(second['medium']), ['work-snapshot']);
      expect(_names(second['small']), ['bulk-file-upload']);
    });

    test('re-reads the configuration after saving, as the web client does',
        () async {
      final api = _FakeDashboardApi(stored: _storedDashboard());
      final repository = CorpDashboardRepository(dashboardApi: api);

      final loaded = await repository.fetchConfig(
        dashboardClass: 'CUSTOM',
        dashboardClassValue: 'custom',
      );
      final config = (loaded as Success<CorpDashboardConfig>).data!;

      final result = await repository.saveConfig(config);

      // GET → PUT → GET, matching widgets(corp).har entries #3, #4, #5.
      expect(api.getCount, 2);
      final returned = (result as Success<CorpDashboardConfig>).data!;
      expect(
        returned.layoutFor(CorpLayoutBreakpoint.medium).single.componentName,
        'work-snapshot',
      );
    });

    test('falls back to the sent config when the re-read fails', () async {
      // The host accepted the write, so what we sent is authoritative —
      // far better than a config with empty layouts.
      final api = _FakeDashboardApi(stored: _storedDashboard())
        ..failRefetch = true;
      final repository = CorpDashboardRepository(dashboardApi: api);

      final loaded = await repository.fetchConfig(
        dashboardClass: 'CUSTOM',
        dashboardClassValue: 'custom',
      );
      final config = (loaded as Success<CorpDashboardConfig>).data!;

      final result = await repository.saveConfig(config);
      final returned = (result as Success<CorpDashboardConfig>).data!;

      expect(
        returned.layoutFor(CorpLayoutBreakpoint.small).single.componentName,
        'bulk-file-upload',
      );
    });
  });
}
