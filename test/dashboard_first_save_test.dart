import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_descriptor.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/core/models/corp/corp_user_profile.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_dashboard_api.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_user_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/dashboard_repository.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';

/// A new user's first personalization, as captured in
/// `customize for new user.har`: their `me` lists no `CUSTOM` dashboard,
/// OBDX shows them their role's `USER_TYPE` one, and the first save
/// creates theirs (`POST .../dashboards/user` → 201) — later saves `PUT`.

Map<String, dynamic> _dto(
  String id,
  String dashboardClass,
  String value, {
  bool factory = false,
}) =>
    {
      'enterpriseRole': 'retailuser',
      'dashboardId': id,
      'dashboardName': 'name-$id',
      'dashboardDescription': 'description-$id',
      'dashboardClass': dashboardClass,
      'dashboardClassValue': value,
      'factory': factory,
    };

/// `me` before the first save: the role dashboard and a factory one.
final _meBefore = {
  'dashboardResponse': {
    'dashboardDTOs': [
      _dto('25351', 'USER_TYPE', 'retailuser'),
      _dto('10', 'USER_TYPE', 'Customer', factory: true),
    ],
  },
};

/// `me` after it: the user's own `CUSTOM` dashboard too.
final _meAfter = {
  'dashboardResponse': {
    'dashboardDTOs': [
      _dto('26459', 'CUSTOM', 'custom'),
      _dto('25351', 'USER_TYPE', 'retailuser'),
      _dto('10', 'USER_TYPE', 'Customer', factory: true),
    ],
  },
};

Map<String, dynamic> _withLayout(
        Map<String, dynamic> dto, List<String> large) =>
    {
      ...dto,
      'layout': {
        'layout': {
          'defaultLayout': [],
          'large': [
            for (final name in large)
              {
                'componentName': name,
                'module': 'dashboard',
                'data': '{}',
                'style': 'oj-lg-4',
              },
          ],
          'medium': [],
          'small': [],
        },
      },
    };

DashboardConfig _config(
        String id, String dashboardClass, String value, List<String> large) =>
    DashboardConfig.fromPayload({
      'dashboardDTO': _withLayout(_dto(id, dashboardClass, value), large),
    })!;

// ── Provider fake ────────────────────────────────────────────────────────

class _FakeRepo implements DashboardRepository {
  /// What the host holds, by class.
  final configs = <String, DashboardConfig>{
    'USER_TYPE':
        _config('25351', 'USER_TYPE', 'retailuser', ['casa-account-card']),
  };
  final created = <DashboardConfig>[];
  final updated = <DashboardConfig>[];
  Completer<void>? createGate;

  @override
  Future<ResponseHandler<DashboardConfig>> fetchConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async {
    final config = configs[dashboardClass];
    return config == null
        ? ResponseHandler.error(404, 'none')
        : ResponseHandler.success(config, code: 200);
  }

  @override
  Future<ResponseHandler<DashboardConfig>> createConfig(
    DashboardConfig edited,
  ) async {
    final gate = createGate;
    createGate = null;
    if (gate != null) await gate.future;
    final own = edited.withIdentity(
      dashboardId: '26459',
      dashboardClass: 'CUSTOM',
      dashboardClassValue: 'custom',
    );
    created.add(edited);
    configs['CUSTOM'] = own;
    return ResponseHandler.success(own, code: 201);
  }

  @override
  Future<ResponseHandler<DashboardConfig>> saveConfig(
    DashboardConfig config,
  ) async {
    updated.add(config);
    return ResponseHandler.success(config, code: 200);
  }

  @override
  Future<ResponseHandler<DashboardAuthorizedComponents>>
      fetchAuthorizedComponents() async => ResponseHandler.success(
            const DashboardAuthorizedComponents(
              authorized: {'casa-account-card', 'loan-calculator'},
            ),
            code: 200,
          );

  @override
  Future<DashboardCatalogResult> fetchCatalog() async => DashboardCatalogResult(
        catalog: DashboardWidgetCatalog.fromPayload(const {'components': []}),
        source: DashboardCatalogSource.environment,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

// ── API fake, for the repository ─────────────────────────────────────────

class _FakeApi implements ObdxDashboardApi {
  _FakeApi({this.createStatus = 201});

  final int createStatus;
  final posts = <Map<String, dynamic>>[];
  final gets = <String>[];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> createDashboardConfig({
    required Map<String, dynamic> payload,
  }) async {
    posts.add(payload);
    if (createStatus != 201) {
      return ResponseHandler.success({
        'statusCode': createStatus,
        'body': {
          'status': {
            'result': 'SUCCESSFUL',
            'message': {'code': 'DIGX_X', 'detail': 'Nope', 'type': 'ERROR'},
          },
        },
      });
    }
    return ResponseHandler.success({
      'statusCode': 201,
      'body': {
        'status': {'result': 'SUCCESSFUL'},
        'dashboardDTO': _dto('26459', 'CUSTOM', 'custom'),
      },
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchDashboardConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async {
    gets.add('$dashboardClass/$dashboardClassValue');
    final layout = posts.isEmpty
        ? const <String, dynamic>{}
        : (posts.last['layout'] as Map)['layout'] as Map;
    return ResponseHandler.success({
      'statusCode': 200,
      'body': {
        'dashboardDTO': {
          ..._dto('26459', 'CUSTOM', 'custom'),
          'layout': {'layout': Map<String, dynamic>.from(layout)},
        },
      },
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _NoUserApi implements ObdxUserApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// Answers `me` with [profile].
class _MeUserApi implements ObdxUserApi {
  _MeUserApi(this.profile);

  final Map<String, dynamic> profile;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchProfile({
    String? challengeResponseHeader,
  }) async =>
      ResponseHandler.success({'statusCode': 200, 'body': profile});

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// A corporate `me` with no `CUSTOM` dashboard: only the factory
/// `corporateuser` one (id 18 in the corporate captures).
final _corpMe = {
  'userProfile': {'userName': 'pooja'},
  'dashboardResponse': {
    'dashboardDTOs': [
      {
        'enterpriseRole': 'corporateuser',
        'dashboardId': '18',
        'dashboardName': 'Corporate',
        'dashboardDescription': 'Corporate dashboard',
        'dashboardClass': 'USER_TYPE',
        'dashboardClassValue': 'corporateuser',
        'factory': true,
      },
    ],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reading `me`', () {
    test('no CUSTOM dashboard: absent, with the role dashboard to start from',
        () {
      final lookup = DashboardDescriptorLookup.fromProfileResponse(_meBefore);
      expect(lookup, isA<DashboardDescriptorAbsent>());
      final template = (lookup as DashboardDescriptorAbsent).template!;
      expect(template.dashboardId, '25351');
      expect(template.dashboardClass, 'USER_TYPE');
      expect(template.dashboardClassValue, 'retailuser');
    });

    test('after the first save: their own dashboard', () {
      final lookup = DashboardDescriptorLookup.fromProfileResponse(_meAfter);
      expect(
        (lookup as DashboardDescriptorFound).descriptor.dashboardId,
        '26459',
      );
    });

    test("the role's dashboard is preferred to a factory one", () {
      final picked = DashboardDescriptor.templateFrom([
        DashboardDescriptor.fromJson(
          _dto('10', 'USER_TYPE', 'Customer', factory: true),
        ),
        DashboardDescriptor.fromJson(_dto('25351', 'USER_TYPE', 'retailuser')),
      ]);
      expect(picked!.dashboardId, '25351');
    });

    test('no USER_TYPE dashboard at all: nothing to start from', () {
      expect(DashboardDescriptor.templateFrom(const []), isNull);
      final lookup = DashboardDescriptorLookup.fromProfileResponse({
        'dashboardResponse': {'dashboardDTOs': []},
      });
      expect((lookup as DashboardDescriptorAbsent).template, isNull);
    });
  });

  group('the personalization state', () {
    late _FakeRepo repo;
    late ProviderContainer container;

    PersonalizationState state() => container.read(personalizationProvider);
    PersonalizationNotifier notifier() =>
        container.read(personalizationProvider.notifier);

    setUp(() {
      repo = _FakeRepo();
      container = ProviderContainer(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
      );
      container.listen(personalizationProvider, (_, __) {});
    });
    tearDown(() => container.dispose());

    Future<void> loadNewUser() => notifier().ensureLoaded(
          DashboardDescriptorLookup.fromProfileResponse(_meBefore),
          userKey: 'nazretail',
        );

    test('a new user can personalize, starting from the role dashboard',
        () async {
      await loadNewUser();
      expect(state().isUnavailable, isFalse);
      expect(state().config!.dashboardId, '25351');
      expect(state().bodyStatus, PersonalizedBodyStatus.ready);
      expect(notifier().saveBlockedReason, isNull);
    });

    test('the first save creates their own dashboard; the next updates it',
        () async {
      await loadNewUser();

      notifier().beginEditing();
      notifier().toggle('loan-calculator');
      expect(await notifier().save(), isTrue);

      // Created — the shared role dashboard was never written.
      expect(repo.created, hasLength(1));
      expect(repo.updated, isEmpty);
      expect(
        repo.created.single.selectedComponentsAt(state().breakpoint),
        ['casa-account-card', 'loan-calculator'],
      );
      expect(state().config!.dashboardId, '26459');
      expect(notifier().descriptor!.dashboardClass, 'CUSTOM');

      // Now it is theirs: an ordinary update.
      notifier().beginEditing();
      notifier().toggle('casa-account-card');
      expect(await notifier().save(), isTrue);
      expect(repo.created, hasLength(1));
      expect(repo.updated.single.dashboardId, '26459');
    });

    test('a second save while the first creates is refused — one dashboard',
        () async {
      await loadNewUser();
      final gate = repo.createGate = Completer<void>();

      notifier().beginEditing();
      notifier().toggle('loan-calculator');
      final first = notifier().save();
      expect(await notifier().save(), isFalse);

      gate.complete();
      expect(await first, isTrue);
      expect(repo.created, hasLength(1));
    });

    test('with no role dashboard either, personalization stays unavailable',
        () async {
      await notifier().ensureLoaded(
        const DashboardDescriptorAbsent(),
        userKey: 'nazretail',
      );
      expect(state().isUnavailable, isTrue);
    });
  });

  group('creating, in the repository', () {
    final template = _config(
      '25351',
      'USER_TYPE',
      'retailuser',
      ['casa-account-card', 'loan-calculator'],
    );

    test('POSTs the edited layout under fresh names, then re-reads it',
        () async {
      final api = _FakeApi();
      final repository =
          DashboardRepository(dashboardApi: api, userApi: _NoUserApi());

      final result = await repository.createConfig(template);

      final payload = api.posts.single;
      expect(payload.keys.toSet(),
          {'dashboardName', 'dashboardDescription', 'layout'});
      for (final key in ['dashboardName', 'dashboardDescription']) {
        final name = payload[key] as String;
        expect(name, startsWith('obdx'), reason: key);
        expect(name, hasLength(40), reason: key);
        // Never the shared role dashboard's own names.
        expect(name, isNot(contains('25351')), reason: key);
      }
      final large =
          ((payload['layout'] as Map)['layout'] as Map)['large'] as List;
      expect([for (final i in large) (i as Map)['componentName']],
          ['casa-account-card', 'loan-calculator']);

      expect(api.gets, ['CUSTOM/custom']);
      final config = (result as Success<DashboardConfig>).data!;
      expect(config.dashboardId, '26459');
      expect(config.isUserCustom, isTrue);
      expect(config.selectedComponentsAt(DashboardBreakpoint.large),
          ['casa-account-card', 'loan-calculator']);
    });

    test('a rejected create is a failure, and nothing is re-read', () async {
      final api = _FakeApi(createStatus: 400);
      final repository =
          DashboardRepository(dashboardApi: api, userApi: _NoUserApi());
      final result = await repository.createConfig(template);
      expect(result, isNot(isA<Success<DashboardConfig>>()));
      expect(api.gets, isEmpty);
    });

    test('fresh names differ every time', () {
      expect(DashboardConfig.newOpaqueName(),
          isNot(DashboardConfig.newOpaqueName()));
    });
  });

  group('corporate users', () {
    test('no CUSTOM dashboard: the corporateuser one to start from', () {
      final profile = CorpUserProfile.fromProfileResponse(_corpMe)!;
      expect(profile.personalizableDashboard, isNull);
      final template = profile.templateDashboard!;
      expect(template.dashboardId, '18');
      expect(template.dashboardClassValue, 'corporateuser');
    });

    test('they can personalize; the first save creates, never writes 18',
        () async {
      final repo = _FakeRepo()
        ..configs['USER_TYPE'] = _config(
          '18',
          'USER_TYPE',
          'corporateuser',
          ['casa-account-card'],
        );
      final container = ProviderContainer(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(personalizationProvider, (_, __) {});
      final notifier = container.read(personalizationProvider.notifier);
      final profile = CorpUserProfile.fromProfileResponse(_corpMe)!;

      await notifier.ensureLoaded(
        DashboardDescriptorLookup.resolved(
          profile.personalizableDashboard,
          template: profile.templateDashboard,
        ),
        userKey: profile.userName,
      );
      expect(container.read(personalizationProvider).isUnavailable, isFalse);

      notifier.beginEditing();
      notifier.toggle('loan-calculator');
      expect(await notifier.save(), isTrue);
      expect(repo.created, hasLength(1));
      expect(repo.updated, isEmpty);
      expect(notifier.descriptor!.dashboardId, '26459');
    });

    test('reading `me` again resolves the template too', () async {
      final repository = DashboardRepository(
        dashboardApi: _FakeApi(),
        userApi: _MeUserApi(_corpMe),
      );
      final result = await repository.fetchPersonalizableDashboard();
      final lookup = (result as Success<DashboardDescriptorLookup>).data;
      expect(
        (lookup as DashboardDescriptorAbsent).template!.dashboardId,
        '18',
      );
    });
  });
}
