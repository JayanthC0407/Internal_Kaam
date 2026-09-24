import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_descriptor.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_dashboard_api.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_user_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/dashboard_repository.dart';

/// Stands in for the host. Records what was PUT and serves the GET, so the
/// test can assert on the exact payload the repository sends.
class _FakeDashboardApi implements ObdxDashboardApi {
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
  group('DashboardRepository.saveConfig', () {
    test('editing large leaves medium and small untouched on the host',
        () async {
      // The exact scenario reported: personalize on a desktop screen, and
      // the phone and tablet layouts come back empty.
      final api = _FakeDashboardApi(stored: _storedDashboard());
      final repository =
          DashboardRepository(dashboardApi: api, userApi: _FakeUserApi());

      final loaded = await repository.fetchConfig(
        dashboardClass: 'CUSTOM',
        dashboardClassValue: 'custom',
      );
      final config = (loaded as Success<DashboardConfig>).data!;

      final edited = config.withLayout(DashboardBreakpoint.large, [
        const DashboardLayoutItem(
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

    test('a second save does not wipe what the first one preserved', () async {
      // The actual failure mode: the first save was fine, but the
      // layout-less PUT response replaced in-memory state with empties, so
      // the *second* save blanked medium and small.
      final api = _FakeDashboardApi(stored: _storedDashboard());
      final repository =
          DashboardRepository(dashboardApi: api, userApi: _FakeUserApi());

      final loaded = await repository.fetchConfig(
        dashboardClass: 'CUSTOM',
        dashboardClassValue: 'custom',
      );
      var config = (loaded as Success<DashboardConfig>).data!;

      for (final component in ['currency-exposure', 'account-quick-links']) {
        final edited = config.withLayout(DashboardBreakpoint.large, [
          DashboardLayoutItem(
            componentName: component,
            module: 'corporateDashboard',
            style: 'oj-lg-4',
          ),
        ]);
        final result = await repository.saveConfig(edited);
        config = (result as Success<DashboardConfig>).data!;
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
      final repository =
          DashboardRepository(dashboardApi: api, userApi: _FakeUserApi());

      final loaded = await repository.fetchConfig(
        dashboardClass: 'CUSTOM',
        dashboardClassValue: 'custom',
      );
      final config = (loaded as Success<DashboardConfig>).data!;

      final result = await repository.saveConfig(config);

      // GET → PUT → GET, matching widgets(corp).har entries #3, #4, #5.
      expect(api.getCount, 2);
      final returned = (result as Success<DashboardConfig>).data!;
      expect(
        returned.layoutFor(DashboardBreakpoint.medium).single.componentName,
        'work-snapshot',
      );
    });

    test('falls back to the sent config when the re-read fails', () async {
      // The host accepted the write, so what we sent is authoritative —
      // far better than a config with empty layouts.
      final api = _FakeDashboardApi(stored: _storedDashboard())
        ..failRefetch = true;
      final repository =
          DashboardRepository(dashboardApi: api, userApi: _FakeUserApi());

      final loaded = await repository.fetchConfig(
        dashboardClass: 'CUSTOM',
        dashboardClassValue: 'custom',
      );
      final config = (loaded as Success<DashboardConfig>).data!;

      final result = await repository.saveConfig(config);
      final returned = (result as Success<DashboardConfig>).data!;

      expect(
        returned.layoutFor(DashboardBreakpoint.small).single.componentName,
        'bulk-file-upload',
      );
    });
  });

  group('DashboardRepository.fetchPersonalizableDashboard', () {
    DashboardRepository repositoryWith(
      ResponseHandler<Map<String, dynamic>> me,
    ) =>
        DashboardRepository(
          dashboardApi: _FakeDashboardApi(stored: _storedDashboard()),
          userApi: _FakeUserApi(profile: me),
        );

    Map<String, dynamic> meWith(List<Map<String, dynamic>> dashboards) => {
          'statusCode': 200,
          'body': {
            'userProfile': {'userName': 'retail01'},
            'dashboardResponse': {'dashboardDTOs': dashboards},
          },
        };

    test('finds the CUSTOM dashboard `me` lists', () async {
      final result = await repositoryWith(
        ResponseHandler.success(
          meWith([
            {
              'dashboardId': '25801',
              'dashboardClass': 'CUSTOM',
              'dashboardClassValue': 'custom',
              'factory': false,
            },
          ]),
          code: 200,
        ),
      ).fetchPersonalizableDashboard();

      final lookup = (result as Success<DashboardDescriptorLookup>).data;
      expect(lookup, isA<DashboardDescriptorFound>());
      expect(
        (lookup as DashboardDescriptorFound).descriptor.dashboardId,
        '25801',
      );
    });

    test('a `me` it read with no CUSTOM dashboard is a definite "none"',
        () async {
      final result = await repositoryWith(
        ResponseHandler.success(
          meWith([
            {
              'dashboardId': '18',
              'dashboardClass': 'USER_TYPE',
              'dashboardClassValue': 'retailuser',
              'factory': true,
            },
          ]),
          code: 200,
        ),
      ).fetchPersonalizableDashboard();

      expect(
        (result as Success<DashboardDescriptorLookup>).data,
        isA<DashboardDescriptorAbsent>(),
      );
    });

    test('a failed `me` is a failure, never "none"', () async {
      final result = await repositoryWith(
        ResponseHandler.success(
          const {'statusCode': 500, 'body': <String, dynamic>{}},
          code: 500,
        ),
      ).fetchPersonalizableDashboard();

      expect(result, isNot(isA<Success<DashboardDescriptorLookup>>()));
    });

    test('a 200 that is not a `me` body is a failure too', () async {
      final result = await repositoryWith(
        ResponseHandler.success(
          const {'statusCode': 200, 'body': <String, dynamic>{}},
          code: 200,
        ),
      ).fetchPersonalizableDashboard();

      expect(result, isNot(isA<Success<DashboardDescriptorLookup>>()));
    });
  });
}

/// Serves a fixed `me` result. The default is only for the tests that never
/// read `me`.
class _FakeUserApi implements ObdxUserApi {
  _FakeUserApi({ResponseHandler<Map<String, dynamic>>? profile})
      : _profile = profile ?? ResponseHandler.error(500, 'not used');

  final ResponseHandler<Map<String, dynamic>> _profile;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchProfile({
    String? challengeResponseHeader,
  }) async =>
      _profile;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
