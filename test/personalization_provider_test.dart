import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_descriptor.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/dashboard_repository.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';

/// Stands in for the host. The test swaps [next] to change what the next
/// configuration fetch returns, since both users request the same
/// `CUSTOM`/`custom` class and the fake cannot tell them apart by argument.
class _FakeRepo implements DashboardRepository {
  DashboardConfig? next;

  /// One-shot gate: the next config fetch waits on it, so a test can hold a
  /// request in flight while something else happens.
  Completer<void>? gate;

  bool failAuthorization = false;
  int configFetches = 0;
  int saveCalls = 0;

  @override
  Future<ResponseHandler<DashboardConfig>> fetchConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async {
    configFetches++;
    // Captured before waiting, so a held request returns what it was
    // issued for — not whatever the test has swapped in meanwhile.
    final captured = next;
    final hold = gate;
    gate = null;
    if (hold != null) await hold.future;
    if (captured == null) return ResponseHandler.error(500, 'unavailable');
    return ResponseHandler.success(captured, code: 200);
  }

  @override
  Future<ResponseHandler<DashboardConfig>> saveConfig(
    DashboardConfig config,
  ) async {
    saveCalls++;
    return ResponseHandler.success(config, code: 200);
  }

  @override
  Future<ResponseHandler<DashboardAuthorizedComponents>>
      fetchAuthorizedComponents() async {
    if (failAuthorization) return ResponseHandler.error(500, 'boom');
    return ResponseHandler.success(
      const DashboardAuthorizedComponents(
        authorized: {'alice-widget', 'bob-widget', 'shared-widget'},
      ),
      code: 200,
    );
  }

  @override
  Future<DashboardCatalogResult> fetchCatalog() async => DashboardCatalogResult(
        catalog: DashboardWidgetCatalog.fromPayload(const {
          'components': [
            {
              'componentName': 'shared-widget',
              'module': 'corporateDashboard',
              'segment': ['common'],
            },
          ],
        }),
        source: DashboardCatalogSource.environment,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

DashboardConfig _config({
  required String id,
  List<String> large = const [],
  bool factory = false,
  String dashboardClass = 'CUSTOM',
}) {
  return DashboardConfig.fromPayload({
    'dashboardDTO': {
      'dashboardId': id,
      'dashboardName': 'name-$id',
      'dashboardDescription': 'description-$id',
      'dashboardClass': dashboardClass,
      'dashboardClassValue': dashboardClass == 'CUSTOM' ? 'custom' : 'user',
      'factory': factory,
      'layout': {
        'layout': {
          'defaultLayout': [],
          'large': [
            for (final name in large)
              {'componentName': name, 'module': 'corporateDashboard'},
          ],
          'medium': [],
          'small': [],
        },
      },
    },
  })!;
}

DashboardDescriptor _custom(String id) => DashboardDescriptor(
      dashboardId: id,
      dashboardClass: 'CUSTOM',
      dashboardClassValue: 'custom',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late ProviderContainer container;
  late ProviderSubscription<PersonalizationState> keepAlive;

  PersonalizationState state() => container.read(personalizationProvider);
  PersonalizationNotifier notifier() =>
      container.read(personalizationProvider.notifier);

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
    );
    // The provider is autoDispose; a dashboard would be watching it.
    keepAlive = container.listen(personalizationProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  group('user scoping', () {
    test('loads once per user', () async {
      repo.next = _config(id: 'A', large: ['alice-widget']);

      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');
      // Case and whitespace in the user name do not count as a new user.
      await notifier().ensureLoaded(_custom('A'), userKey: '  Alice ');

      expect(repo.configFetches, 1);
    });

    test('a different user discards the previous user\'s state', () async {
      repo.next = _config(id: 'A', large: ['alice-widget']);
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');
      expect(state().selectedComponents, ['alice-widget']);

      repo.next = _config(id: 'B', large: ['bob-widget']);
      final loading = notifier().ensureLoaded(_custom('B'), userKey: 'bob');

      // Reset synchronously — nothing of Alice's is visible while Bob's
      // dashboard is still loading.
      expect(state().config, isNull);
      expect(state().selectedComponents, isEmpty);

      await loading;
      expect(state().selectedComponents, ['bob-widget']);
      expect(repo.configFetches, 2);
    });

    test('a request in flight for one user never lands in the next user\'s '
        'state', () async {
      final aliceGate = Completer<void>();
      repo
        ..next = _config(id: 'A', large: ['alice-widget'])
        ..gate = aliceGate;
      final aliceLoad = notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      // Bob signs in while Alice's request is still out.
      repo.next = _config(id: 'B', large: ['bob-widget']);
      await notifier().ensureLoaded(_custom('B'), userKey: 'bob');
      expect(state().selectedComponents, ['bob-widget']);

      // Alice's response finally arrives. It must be dropped.
      aliceGate.complete();
      await aliceLoad;
      expect(state().selectedComponents, ['bob-widget']);
      expect(state().config?.dashboardId, 'B');
    });

    test('a request in flight at logout never lands, even for the same user',
        () async {
      final gate = Completer<void>();
      repo
        ..next = _config(id: 'A', large: ['alice-widget'])
        ..gate = gate;
      final load = notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      // Logout advances the session generation app-wide.
      SessionGeneration.advance();
      gate.complete();
      await load;

      expect(state().config, isNull);
    });

    test('autoDispose discards the state once nothing watches it', () async {
      repo.next = _config(id: 'A', large: ['alice-widget']);
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');
      expect(state().isReady, isTrue);

      // Logging out pops the dashboard, which drops its subscription.
      keepAlive.close();
      await Future<void>.delayed(Duration.zero);

      keepAlive = container.listen(personalizationProvider, (_, __) {});
      expect(state().hasStarted, isFalse);
      expect(state().config, isNull);
    });
  });

  group('write target', () {
    test('refuses to save to a factory dashboard the host returned', () async {
      // `me` described a CUSTOM dashboard, but the host answered the CUSTOM
      // request with the shared factory record — which is exactly how a
      // first-time user could end up writing to everyone's default.
      repo.next = _config(id: 'A', large: ['alice-widget'], factory: true);
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      notifier()
        ..beginEditing()
        ..toggle('shared-widget');
      expect(notifier().saveBlockedReason, isNotNull);

      final saved = await notifier().save();
      expect(saved, isFalse);
      expect(repo.saveCalls, 0);
      expect(state().saveErrorMessage, isNotNull);
    });

    test('refuses to save when the returned dashboard is not the one `me` '
        'described', () async {
      repo.next = _config(id: 'SOMEONE-ELSE', large: ['alice-widget']);
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      notifier()
        ..beginEditing()
        ..toggle('shared-widget');

      expect(await notifier().save(), isFalse);
      expect(repo.saveCalls, 0);
    });

    test('saves to the user\'s own CUSTOM dashboard', () async {
      repo.next = _config(id: 'A', large: ['alice-widget']);
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      notifier()
        ..beginEditing()
        ..toggle('shared-widget');
      expect(notifier().saveBlockedReason, isNull);

      expect(await notifier().save(), isTrue);
      expect(repo.saveCalls, 1);
    });

    test('no descriptor means personalization is unavailable', () async {
      await notifier().ensureLoaded(null, userKey: 'alice');

      expect(state().isUnavailable, isTrue);
      expect(state().bodyStatus, PersonalizedBodyStatus.unavailable);
      expect(repo.configFetches, 0);
    });
  });

  group('body status', () {
    test('the first frame, before any load, is loading — not the defaults',
        () {
      // Showing the defaults here is what made the dashboard visibly swap
      // once the real configuration arrived.
      expect(state().hasStarted, isFalse);
      expect(state().bodyStatus, PersonalizedBodyStatus.loading);
    });

    test('an intentionally empty CUSTOM dashboard is empty, not unavailable',
        () async {
      repo.next = _config(id: 'A');
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      expect(state().bodyStatus, PersonalizedBodyStatus.empty);
    });

    test('a dashboard emptied by authorization filtering is also empty',
        () async {
      repo.next = _config(id: 'A', large: ['not-authorized-widget']);
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      expect(state().renderableItems, isEmpty);
      expect(state().bodyStatus, PersonalizedBodyStatus.empty);
    });

    test('a configuration that fails to load is unavailable', () async {
      repo.next = null;
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      expect(state().bodyStatus, PersonalizedBodyStatus.unavailable);
    });
  });

  group('authorization', () {
    test('a failed load is explicit and fails closed', () async {
      repo
        ..next = _config(id: 'A', large: ['alice-widget'])
        ..failAuthorization = true;
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      expect(state().authorizationStatus, DashboardAuthorizationStatus.failed);
      expect(state().authorizationError, isNotNull);
      // Unknown is not allowed: nothing renders and nothing is offered.
      expect(state().isAuthorized('alice-widget'), isFalse);
      expect(state().renderableItems, isEmpty);
      expect(state().availableWidgets('corporateuser'), isEmpty);
      expect(
        state().bodyStatus,
        PersonalizedBodyStatus.authorizationFailed,
      );
      // And nothing can be saved without it.
      expect(notifier().saveBlockedReason, isNotNull);
    });

    test('retrying recovers without reloading the configuration', () async {
      repo
        ..next = _config(id: 'A', large: ['alice-widget'])
        ..failAuthorization = true;
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');
      expect(repo.configFetches, 1);

      repo.failAuthorization = false;
      await notifier().retryAuthorization();

      expect(state().authorizationStatus, DashboardAuthorizationStatus.loaded);
      expect(state().bodyStatus, PersonalizedBodyStatus.ready);
      expect(state().renderableItems.single.componentName, 'alice-widget');
      expect(repo.configFetches, 1);
    });

    test('a loaded but empty authorization set authorizes nothing', () async {
      // The distinction the status exists for: this loaded, and says no.
      repo.next = _config(id: 'A', large: ['not-authorized-widget']);
      await notifier().ensureLoaded(_custom('A'), userKey: 'alice');

      expect(state().authorizationStatus, DashboardAuthorizationStatus.loaded);
      expect(state().isAuthorized('not-authorized-widget'), isFalse);
    });
  });
}
