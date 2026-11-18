import 'dart:convert';
import 'dart:io';

import 'package:assistant_actions/assistant_actions.dart';
import 'package:assistant_core/assistant_core.dart';
import 'package:demo_bank/src/view/routes/routes_const.dart';
import 'package:demo_bank/src/view/screens/common/assistant/ask_assistant_button.dart';
import 'package:demo_bank/src/view/screens/common/assistant/named_route_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The AI assistant (Noor) integration: the SDK opens this app's own named
/// routes, and only those in the tenant's screen map.

/// The assistant repo's config for this bank (`schemas/examples/demobank-ae.json`).
const _configPath =
    '../AI-Chat-Assistant/schemas/examples/demobank-ae.json';

void main() {
  Widget appWith(GlobalKey<NavigatorState> key, List<String> opened) => MaterialApp(
        navigatorKey: key,
        home: const Scaffold(body: Text('home')),
        onGenerateRoute: (settings) {
          opened.add(settings.name!);
          return MaterialPageRoute<void>(settings: settings, builder: (_) => Text('route ${settings.name}'));
        },
      );

  TenantConfig config() => TenantConfig.fromJson(jsonDecode(File(_configPath).readAsStringSync()));

  testWidgets('NamedRouteNavigator pushes the route by name', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final opened = <String>[];
    await tester.pumpWidget(appWith(key, opened));

    NamedRouteNavigator(key).open('${RoutesConst.casaAccountsListScreen}?from=assistant');
    await tester.pumpAndSettle();

    expect(opened, [RoutesConst.casaAccountsListScreen]);
  });

  test("the bank config's screen map matches this app's routes", () {
    final routes = config().screenMap.values.map((e) => e.route).toSet();
    expect(routes, {
      RoutesConst.casaAccountsListScreen,
      RoutesConst.transferMoneyScreen,
      RoutesConst.payeesScreen,
    });
  });

  testWidgets('a sensitive screen from the assistant opens only after the tap', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final opened = <String>[];
    await tester.pumpWidget(appWith(key, opened));

    final offers = <ActionOffer>[];
    final dispatcher = AssistantActionDispatcher(
      config: config(),
      navigator: NamedRouteNavigator(key),
      onOffer: offers.add,
      isSavedPayee: (_) async => false,
    );

    final result = await dispatcher.handle({
      'tenantId': 'demobank-ae',
      'type': 'navigate',
      'input': {'screen': 'fund_transfer'},
    });
    await tester.pumpAndSettle();
    expect(result, ActionResult.offered);
    expect(opened, isEmpty);

    offers.single.accept();
    await tester.pumpAndSettle();
    expect(opened, [RoutesConst.transferMoneyScreen]);

    // Not in the screen map, or another bank's action: nothing opens.
    for (final action in [
      {'tenantId': 'demobank-ae', 'type': 'navigate', 'input': {'screen': 'login'}},
      {'tenantId': 'bank-xyz-ae', 'type': 'navigate', 'input': {'screen': 'account_summary'}},
    ]) {
      expect((await dispatcher.handle(action)).outcome, 'rejected');
    }
    // Tier 3: no transfer drafts.
    final prefill = await dispatcher.handle({
      'tenantId': 'demobank-ae',
      'type': 'prefillTransfer',
      'input': {
        'fromAccountId': 'acc_test',
        'payeeId': 'pay_test',
        'amount': {'amount': '10.00', 'currency': 'AED'},
      },
    });
    expect(prefill.reason, RejectReason.tierNotEnabled);
    await tester.pumpAndSettle();
    expect(opened, [RoutesConst.transferMoneyScreen]);
  });

  testWidgets('the Ask Noor button renders only when the assistant is enabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(floatingActionButton: AskAssistantButton(enabled: false))));
    expect(find.byKey(const Key('ask-assistant')), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(floatingActionButton: AskAssistantButton(enabled: true))));
    expect(find.byKey(const Key('ask-assistant')), findsOneWidget);
    expect(find.byTooltip('Ask Noor'), findsOneWidget);
  });
}
