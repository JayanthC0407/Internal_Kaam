import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:demo_bank/src/core/models/retail/casa_account.dart';
import 'package:demo_bank/src/sdui/dxp_api.dart';
import 'package:demo_bank/src/sdui/dxp_providers.dart';
import 'package:demo_bank/src/sdui/dxp_runtime.dart';
import 'package:demo_bank/src/sdui/render/render_context.dart';
import 'package:demo_bank/src/sdui/view/dxp_home_slot.dart';
import 'package:demo_bank/l10n/app_localizations.dart';
import 'package:demo_bank/src/core/theme/app_theme.dart';
import 'package:demo_bank/src/view/screens/retail/dxp/retail_app_widgets.dart';
import 'package:demo_bank/src/view/screens/retail/dxp/retail_preview_samples.dart';
import 'package:demo_bank/src/view/screens/retail/dxp/retail_dxp_host.dart';
import 'package:demo_bank/src/view/screens/retail/home/widgets/retail_nav.dart';

/// A platform in memory: a manifest that can be republished, and screens.
class _FakeApi extends DxpApi {
  _FakeApi(this.screens);

  Map<String, Map<String, dynamic>> screens;
  int version = 1;
  int manifestCalls = 0;
  int screenCalls = 0;
  Map<String, dynamic>? lastSession;

  String _hash(String id) => '${screens[id].hashCode}';

  @override
  Future<String> openSession(Map<String, dynamic> body) async {
    lastSession = body;
    return 'token';
  }

  @override
  Future<DxpManifestResult> manifest(String token, {String? etag}) async {
    manifestCalls++;
    final tag = 'v$version';
    if (etag == tag) return const DxpManifestResult.notModified();
    return DxpManifestResult.changed({
      'configVersion': version,
      'home': 'home',
      'menu': [
        {'label': 'Offers', 'icon': 'star', 'action': {'type': 'navigate', 'screen': 'offers'}},
      ],
      'screens': {for (final id in screens.keys) id: _hash(id)},
    }, tag);
  }

  @override
  Future<Map<String, dynamic>> screen(String token, String id) async {
    screenCalls++;
    return screens[id]!;
  }

  @override
  Future<void> postEvents(String token, List<Map<String, dynamic>> events) async {}

  @override
  Future<void> endSession(String token) async {}
}

class _FakeHost implements DxpHost {
  final opened = <String>[];

  @override
  Map<String, dynamic> get customer => {'firstName': 'Asha', 'name': 'Asha K', 'segment': 'RETAIL'};

  @override
  bool openNative(String route) {
    opened.add(route);
    return true;
  }

  @override
  Future<dynamic> resolveData(String source) async => null;

  @override
  Map<String, Widget Function()> get appWidgets => {
        'hello-widget': () => const Text('Native hello widget'),
      };
}

Map<String, dynamic> _bannerHome(String title) => {
      'id': 'home',
      'data': {},
      'root': {
        'type': 'Column',
        'children': [
          {
            'type': 'Banner',
            'props': {'title': title, 'text': 'Hello {{customer.firstName}}'},
            'on': {'tap': {'type': 'nativeRoute', 'route': '/accounts/loans'}},
          },
          {'type': 'NotInThisApp', 'props': {}},
        ],
      },
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Retail binding (CONTRACT-OBDX §6, §7)', () {
    test('account numbers are masked to their last four digits', () {
      expect(RetailDxpHost.maskAccountNumber('0123 4567 8901 2345'), '•••• 2345');
      expect(RetailDxpHost.maskAccountNumber('123'), '123');
    });

    test('a CASA account maps to the contract shape', () {
      const account = CasaAccount(
        id: 'ACC-1',
        displayNumber: '000123456789',
        status: 'ACTIVE',
        currencyCode: 'INR',
        accountType: 'Saving',
        nickname: 'Salary',
        availableBalance: MoneyAmount(amount: 1500.5, currency: 'INR'),
      );
      expect(RetailDxpHost.accountToContract(account), {
        'id': 'ACC-1',
        'name': 'Salary',
        'number': '•••• 6789',
        'type': 'SAVING',
        'balance': 1500.5,
        'currency': 'INR',
      });
    });

    test('nativeRoute opens a Retail menu item; unknown routes are refused', () {
      final opened = <String>[];
      final host = RetailDxpHost(
        loadAccounts: () async => const [],
        openNavItem: opened.add,
        firstName: 'Asha',
        fullName: 'Asha K',
      );
      expect(host.openNative('/cards/credit'), isTrue);
      expect(host.openNative('/somewhere'), isFalse);
      expect(opened, [RetailNav.creditCards]);
    });

    test('every route matches the platform allow-list', () {
      // dxp-platform src/validate.js NATIVE_ROUTES.
      expect(RetailDxpHost.routeTable.keys.toSet(), {
        '/home', '/transfer', '/accounts', '/accounts/loans',
        '/accounts/term-deposits', '/cards/credit', '/bills',
      });
    });
  });

  test('userRef is opaque and stable (CONTRACT-OBDX §1.1)', () {
    final ref = DxpRuntime.userRefFor('Asha.K');
    expect(ref, matches(RegExp(r'^u_[a-f0-9]{64}$')));
    expect(ref, DxpRuntime.userRefFor(' asha.k '));
    expect(ref.contains('asha'), isFalse);
  });

  test('placeholders interpolate against the render context', () {
    final ctx = RenderContext.build(customer: {'firstName': 'Asha'}, data: {'n': 1250.5});
    expect(ctx.interpolate('Hi {{customer.firstName}}'), 'Hi Asha');
    expect(ctx.interpolate('{{n|money}}'), '1,250.500');
    expect(ctx.interpolate('{{missing.path}}!'), '!');
  });

  group('runtime', () {
    test('off: never calls the platform', () async {
      final api = _FakeApi({'home': _bannerHome('A')});
      final runtime = DxpRuntime(api: api, enabled: false, live: false);
      await runtime.start(host: _FakeHost(), userId: 'u', userType: 'RETAIL');
      expect(runtime.status, DxpStatus.off);
      expect(api.manifestCalls, 0);
    });

    testWidgets('starts, then applies a republished configuration once', (tester) async {
      final api = _FakeApi({'home': _bannerHome('A'), 'offers': {'id': 'offers'}});
      final runtime = DxpRuntime(api: api, enabled: true, live: false);
      await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');

      expect(runtime.status, DxpStatus.ready);
      expect(api.lastSession!['userRef'], DxpRuntime.userRefFor('asha'));
      expect(api.lastSession!['contract'], 'obdx-1');
      expect(runtime.menu.single['label'], 'Offers');
      expect(runtime.cachedScreen('home'), isNotNull);
      // Only the home screen is fetched up front.
      expect(api.screenCalls, 1);

      final before = runtime.revision;
      await runtime.refresh(); // 304
      expect(runtime.revision, before);

      api.screens['home'] = _bannerHome('B');
      api.version = 2;
      await runtime.refresh();
      expect(runtime.revision, before + 1);
      expect(runtime.configVersion, 2);
      expect(runtime.cachedScreen('home')!['root']['children'][0]['props']['title'], 'B');
      await runtime.stop();
    });
  });

  group('full Home layout', () {
    Map<String, dynamic> fullHome() => {
          'id': 'home',
          'layout': 'full',
          'data': {},
          'root': {
            'type': 'Column',
            'children': [
              {'type': 'AppWidget', 'props': {'name': 'hello-widget'}},
              {'type': 'AppWidget', 'props': {'name': 'not-in-app'}},
            ],
          },
        };

    test('is reported only once the runtime is ready', () async {
      final runtime = DxpRuntime(api: _FakeApi({'home': fullHome()}), enabled: true, live: false);
      expect(runtime.homeIsFullLayout, isFalse);
      await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      expect(runtime.homeIsFullLayout, isTrue);
      await runtime.stop();
      expect(runtime.homeIsFullLayout, isFalse);
    });

    testWidgets('AppWidget draws the host widget by name, a placeholder otherwise',
        (tester) async {
      final runtime = DxpRuntime(api: _FakeApi({'home': fullHome()}), enabled: true, live: false);
      await tester.runAsync(() => runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL'));
      await tester.pumpWidget(ProviderScope(
        overrides: [dxpRuntimeProvider.overrideWith((ref) => runtime)],
        child: const MaterialApp(home: Scaffold(body: DxpHomeSlot())),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Native hello widget'), findsOneWidget);
      expect(find.text('Not in this app version: not-in-app'), findsOneWidget);
      await tester.runAsync(runtime.stop);
    });
  });

  test('Retail palette names all have a widget', () {
    expect(RetailAppWidgets.builders.keys.toList(), RetailAppWidgets.names);
  });

  // What the Studio preview does: every palette widget, on sample data.
  for (final name in RetailAppWidgets.names) {
    testWidgets('preview draws "$name" from sample data', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: RetailPreviewSamples.overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: RetailAppWidgets.builders[name]!()),
          ),
        ),
      ));
      // Some cards animate in (the loan gauge); let them finish.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  group('Home slot', () {
    Future<void> pump(WidgetTester tester, DxpRuntime runtime) => tester.pumpWidget(
          ProviderScope(
            overrides: [dxpRuntimeProvider.overrideWith((ref) => runtime)],
            child: const MaterialApp(home: Scaffold(body: DxpHomeSlot())),
          ),
        );

    testWidgets('draws nothing when DXP is off', (tester) async {
      await pump(tester, DxpRuntime(api: _FakeApi({}), enabled: false, live: false));
      expect(find.byType(DxpHomeSlot), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('draws the published home, a placeholder for unknown widgets, '
        'and hands nativeRoute to the host', (tester) async {
      final host = _FakeHost();
      final runtime = DxpRuntime(api: _FakeApi({'home': _bannerHome('Loans made simple')}), enabled: true, live: false);
      await tester.runAsync(() => runtime.start(host: host, userId: 'asha', userType: 'RETAIL'));
      await pump(tester, runtime);
      await tester.pumpAndSettle();

      expect(find.text('Loans made simple'), findsOneWidget);
      expect(find.text('Hello Asha'), findsOneWidget);
      expect(find.text('Unsupported: NotInThisApp'), findsOneWidget);

      await tester.tap(find.text('Loans made simple'));
      await tester.pumpAndSettle();
      expect(host.opened, ['/accounts/loans']);
      await tester.runAsync(runtime.stop);
    });
  });
}
