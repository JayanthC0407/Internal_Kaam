import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:demo_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:demo_bank/src/core/models/common/cards/debit_card_models.dart';
import 'package:demo_bank/src/core/models/common/payee/payee_models.dart';
import 'package:demo_bank/src/core/models/retail/casa_account.dart';
import 'package:demo_bank/src/core/models/retail/casa_transaction.dart';
import 'package:demo_bank/src/sdui/dxp_api.dart';
import 'package:demo_bank/src/sdui/dxp_providers.dart';
import 'package:demo_bank/src/sdui/dxp_runtime.dart';
import 'package:demo_bank/src/sdui/render/render_context.dart';
import 'package:demo_bank/src/sdui/render/renderer.dart';
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

  /// No answer at all, as when the server is off or unreachable.
  bool down = false;

  /// The platform answers and refuses, e.g. 403 NOT_IN_SCOPE.
  int? refuseWith;

  String _hash(String id) => '${screens[id].hashCode}';

  @override
  Future<String> openSession(Map<String, dynamic> body) async {
    final req = RequestOptions(path: '/session');
    if (down) throw DioException(requestOptions: req, type: DioExceptionType.connectionError);
    if (refuseWith != null) {
      throw DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: refuseWith),
      );
    }
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
      'releaseNo': version,
      'home': 'home',
      'menu': [
        {'label': 'Offers', 'icon': 'star', 'action': {'type': 'navigate', 'screen': 'offers'}},
      ],
      'screens': {for (final id in screens.keys) id: _hash(id)},
    }, tag);
  }

  @override
  Future<DxpScreenDoc> screen(String token, String id, {int? release}) async {
    screenCalls++;
    lastScreenRelease = release;
    final publish = publishDuringNextScreenFetch;
    if (publish != null) {
      // A checker approves a new release between the manifest and this call,
      // and this platform ignores `release` (the old behaviour).
      publishDuringNextScreenFetch = null;
      publish();
    }
    return DxpScreenDoc(screens[id]!, _hash(id));
  }

  int? lastScreenRelease;

  /// Runs once, inside the next screen fetch.
  void Function()? publishDuringNextScreenFetch;

  /// The live channel, as lines the platform would stream.
  final liveLines = StreamController<String>.broadcast();

  @override
  Future<Stream<String>> live(String token, CancelToken cancel) async => liveLines.stream;

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
    test('numbers are masked to their last four digits', () {
      expect(RetailDxpHost.maskNumber('0123 4567 8901 2345'), '•••• 2345');
      expect(RetailDxpHost.maskNumber('0000 00XX XXXX 4417'), '•••• 4417');
      expect(RetailDxpHost.maskNumber('123'), '123');
    });

    const account = CasaAccount(
      id: '000123456789', // OBDX's id is the full account number
      displayNumber: '000123456789',
      status: 'ACTIVE',
      currencyCode: 'INR',
      accountType: 'Saving',
      nickname: 'Salary',
      availableBalance: MoneyAmount(amount: 1500.5, currency: 'INR'),
    );

    test('a CASA account maps to the contract shape, with an opaque id', () {
      expect(RetailDxpHost.accountToContract(account, 0), {
        'id': 'a1',
        'name': 'Salary',
        'number': '•••• 6789',
        'type': 'SAVING',
        'balance': 1500.5,
        'currency': 'INR',
      });
    });

    test('a debit is negative, a credit positive', () {
      final debit = RetailDxpHost.transactionToContract(
        CasaTransaction(id: 'X', title: 'Grocery', amount: const MoneyAmount(amount: 250, currency: 'INR'), isCredit: false, transactionDate: DateTime(2026, 11, 5)),
        0,
      );
      expect(debit, {'id': 't1', 'date': '2026-11-05', 'description': 'Grocery', 'amount': -250.0, 'currency': 'INR', 'status': ''});
      final credit = RetailDxpHost.transactionToContract(
        CasaTransaction(id: 'Y', title: 'Salary', amount: const MoneyAmount(amount: 900, currency: 'INR'), isCredit: true),
        1,
      );
      expect(credit['amount'], 900.0);
      expect(credit['id'], 't2');
    });

    RetailDxpHost hostWith({
      Future<List<CasaTransaction>> Function(String)? txns,
      Future<List<CreditCard>> Function()? credit,
      Future<List<DebitCard>> Function()? debit,
      Future<List<PayeeSummary>> Function()? payees,
      List<String>? txnAccounts,
    }) =>
        RetailDxpHost(
          loadAccounts: () async => [
            account,
            const CasaAccount(id: '999988887777', displayNumber: '999988887777', status: 'ACTIVE', currencyCode: 'INR', isDefault: true),
          ],
          loadTransactions: txns,
          loadCreditCards: credit,
          loadDebitCards: debit,
          loadPayees: payees,
          openNavItem: (_) {},
          firstName: 'Asha',
          fullName: 'Asha K',
        );

    test('txn.history reads the default account and keeps the latest 10', () async {
      String? readFrom;
      final host = hostWith(txns: (id) async {
        readFrom = id;
        return [
          for (var i = 0; i < 15; i++)
            CasaTransaction(id: '$i', title: 'T$i', amount: const MoneyAmount(amount: 1), isCredit: true),
        ];
      });
      final out = await host.resolveData('txn.history') as List;
      expect(readFrom, '999988887777');
      expect(out, hasLength(10));
    });

    test('cards.list joins credit and debit cards, masked, with opaque ids', () async {
      final host = hostWith(
        credit: () async => const [
          CreditCard(id: '4111111111114417', displayNumber: '4111 11XX XXXX 4417', status: CreditCardStatus.active,
              creditLimit: MoneyAmount(amount: 200000, currency: 'INR'), availableCredit: MoneyAmount(amount: 180000, currency: 'INR')),
        ],
        debit: () async => const [
          DebitCard(cardNo: '5200000000001234', displayNumber: '5200 00XX XXXX 1234', status: DebitCardStatus.blocked, cardType: 'Visa Debit'),
        ],
      );
      final out = (await host.resolveData('cards.list') as List).cast<Map<String, dynamic>>();
      expect(out.map((c) => c['id']), ['c1', 'c2']);
      expect(out.map((c) => c['number']), ['•••• 4417', '•••• 1234']);
      expect(out[0]['kind'], 'CREDIT');
      expect(out[0]['limit'], 200000.0);
      expect(out[1]['status'], 'BLOCKED');
      expect(out[1]['name'], 'Visa Debit');
      expect(out.toString().contains('4111111111114417'), isFalse);
    });

    test('payees.list masks the account and keeps the bank', () async {
      final host = hostWith(payees: () async => const [
            PayeeSummary(nickname: 'Landlord', accountType: 'Domestic', accountDetails: 'HDFC Bank', accountNumber: '50100012349012'),
          ]);
      expect(await host.resolveData('payees.list'), [
        {'id': 'p1', 'name': 'Landlord', 'account': '•••• 9012', 'bank': 'HDFC Bank', 'type': ''},
      ]);
    });

    test('a failed source renders empty instead of failing the screen', () async {
      final host = hostWith(payees: () async => throw StateError('OBDX down'));
      expect(await host.resolveData('payees.list'), isNull);
      expect(await host.resolveData('no.such.source'), isNull);
    });

    test('every data source matches the platform allow-list', () {
      // dxp-platform src/validate.js DATA_SOURCES.
      expect(RetailDxpHost.dataSources.toSet(),
          {'customer.profile', 'accounts.list', 'txn.history', 'cards.list', 'payees.list'});
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
      // Home, then every other screen for the offline copy.
      expect(api.screenCalls, 2);

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

  test('live channel: a ping marks it live, a publish signal refreshes', () async {
    final api = _FakeApi({'home': _bannerHome('A')});
    final runtime = DxpRuntime(api: api, enabled: true);
    await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
    await Future<void>.delayed(Duration.zero);
    expect(runtime.liveConnected, isFalse);

    api.liveLines.add(': ping');
    await Future<void>.delayed(Duration.zero);
    expect(runtime.liveConnected, isTrue);

    api
      ..screens['home'] = _bannerHome('B')
      ..version = 2;
    api.liveLines
      ..add('event: config.published')
      ..add('data: {"configVersion":2}')
      ..add('');
    // Applied after a random delay of up to 1.5 s.
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    expect(runtime.configVersion, 2);
    await runtime.stop();
    expect(runtime.liveConnected, isFalse);
  });

  test('screens are requested from the manifest\'s own release', () async {
    final api = _FakeApi({'home': _bannerHome('A')})..version = 7;
    final runtime = DxpRuntime(api: api, enabled: true, live: false);
    await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
    expect(api.lastScreenRelease, 7);
    await runtime.stop();
  });

  test('a release published mid-fetch never mixes two releases', () async {
    final api = _FakeApi({'home': _bannerHome('A')});
    final runtime = DxpRuntime(api: api, enabled: true, live: false);
    await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');

    // Release 2 is announced; while the app fetches its home, release 3 lands.
    api
      ..screens['home'] = _bannerHome('B')
      ..version = 2
      ..publishDuringNextScreenFetch = () => api
        ..screens['home'] = _bannerHome('C')
        ..version = 3;
    await runtime.refresh();

    // The screen did not match release 2's hash, so the app re-checked and
    // applied release 3 whole: manifest and screen from the same release.
    expect(runtime.configVersion, 3);
    expect(runtime.cachedScreen('home')!['root']['children'][0]['props']['title'], 'C');
    await runtime.stop();
  });

  group('Grid block (two columns, like the web Home)', () {
    final grid = {
      'type': 'Grid',
      'children': [
        {'type': 'Text', 'props': {'text': 'A'}},
        {'type': 'Text', 'props': {'text': 'B'}},
        {'type': 'Text', 'span': 'full', 'props': {'text': 'WIDE'}},
        {'type': 'Text', 'props': {'text': 'C'}},
      ],
    };

    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final renderer = Renderer(onAction: (_, __) {}, onStateChanged: () {}, onError: (_, __, ___) {});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: renderer.build(grid, RenderContext.build(customer: const {}))),
      ));
    }

    testWidgets('wide: left, right, then a full-width row, then left again', (tester) async {
      await pumpAt(tester, 1200);
      final a = tester.getTopLeft(find.text('A'));
      final b = tester.getTopLeft(find.text('B'));
      final wide = tester.getTopLeft(find.text('WIDE'));
      final c = tester.getTopLeft(find.text('C'));
      expect(a.dy, b.dy); // same row
      expect(b.dx, greaterThan(500)); // B in the right column
      expect(wide.dy, greaterThan(a.dy)); // full width below them
      expect(c.dx, a.dx); // C starts the left column again
      expect(c.dy, greaterThan(wide.dy));
    });

    testWidgets('narrow: one column in the designer\'s order', (tester) async {
      await pumpAt(tester, 400);
      final ys = ['A', 'B', 'WIDE', 'C'].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(ys, orderedEquals([...ys]..sort()));
      expect(tester.getTopLeft(find.text('A')).dx, tester.getTopLeft(find.text('B')).dx);
    });
  });

  test('the fallback poll is slow', () {
    expect(DxpRuntime.fallbackPollInterval, const Duration(minutes: 5));
  });

  group('device cache (platform down)', () {
    Map<String, Map<String, dynamic>> published() =>
        {'home': _bannerHome('Saved banner'), 'offers': {'id': 'offers', 'root': {'type': 'Column'}}};

    test('a successful start saves every screen for offline use', () async {
      final api = _FakeApi(published());
      final runtime = DxpRuntime(api: api, enabled: true, live: false);
      await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      expect(runtime.offline, isFalse);
      // Home up front, offers prefetched for the saved copy.
      expect(api.screenCalls, 2);
      await runtime.stop();
    });

    test('platform down: the saved configuration is drawn, offline', () async {
      final api = _FakeApi(published());
      final first = DxpRuntime(api: api, enabled: true, live: false);
      await first.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      await first.stop();

      api.down = true;
      final runtime = DxpRuntime(api: api, enabled: true, live: false);
      await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      expect(runtime.status, DxpStatus.ready);
      expect(runtime.offline, isTrue);
      expect(runtime.menu.single['label'], 'Offers');
      expect(runtime.cachedScreen('home')!['root']['children'][0]['props']['title'], 'Saved banner');
      expect(runtime.cachedScreen('offers'), isNotNull);
      await runtime.stop();
    });

    test('platform back: an offline app reconnects on resume and goes live', () async {
      final api = _FakeApi(published());
      final first = DxpRuntime(api: api, enabled: true, live: false);
      await first.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      await first.stop();

      api.down = true;
      final runtime = DxpRuntime(api: api, enabled: true, live: false);
      await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      expect(runtime.offline, isTrue);

      api
        ..down = false
        ..screens['home'] = _bannerHome('New banner')
        ..version = 2;
      runtime.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(runtime.offline, isFalse);
      expect(runtime.configVersion, 2);
      expect(runtime.cachedScreen('home')!['root']['children'][0]['props']['title'], 'New banner');
      await runtime.stop();
    });

    test('platform down and nothing saved: the app stays native', () async {
      final api = _FakeApi(published())..down = true;
      final runtime = DxpRuntime(api: api, enabled: true, live: false);
      await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      expect(runtime.status, DxpStatus.unavailable);
    });

    test('platform refuses the app: the saved copy is not used', () async {
      final api = _FakeApi(published());
      final first = DxpRuntime(api: api, enabled: true, live: false);
      await first.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      await first.stop();

      api.refuseWith = 403;
      final runtime = DxpRuntime(api: api, enabled: true, live: false);
      await runtime.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      expect(runtime.status, DxpStatus.unavailable);
      expect(runtime.offline, isFalse);
    });

    test('a saved copy for another user type is never used', () async {
      final api = _FakeApi(published());
      final first = DxpRuntime(api: api, enabled: true, live: false);
      await first.start(host: _FakeHost(), userId: 'asha', userType: 'RETAIL');
      await first.stop();

      api.down = true;
      final runtime = DxpRuntime(api: api, enabled: true, live: false);
      await runtime.start(host: _FakeHost(), userId: 'boss', userType: 'CORP');
      expect(runtime.status, DxpStatus.unavailable);
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
