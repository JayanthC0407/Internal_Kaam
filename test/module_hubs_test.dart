import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_bank/l10n/app_localizations.dart';
import 'package:demo_bank/src/core/config/locale_config.dart';
import 'package:demo_bank/src/core/theme/app_theme.dart';
import 'package:demo_bank/src/view/screens/common/bill_payments/bill_payments_hub_screen.dart';
import 'package:demo_bank/src/view/screens/common/credit_cards/credit_cards_hub_screen.dart';
import 'package:demo_bank/src/view/screens/retail/accounts/current_savings_hub_screen.dart';
import 'package:demo_bank/src/view/screens/retail/accounts/widgets/casa_shared_widgets.dart';
import 'package:demo_bank/src/view/screens/retail/certificates/certificates_screens.dart';
import 'package:demo_bank/src/view/screens/retail/home/widgets/home_menu_button.dart';

// The Credit Cards and Bill Payments module pages: one side-menu entry
// each, every OBDX menu item on one page (OBDX labels, nls/menu.js).

Future<void> _pump(WidgetTester tester, Widget page, {double width = 390}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: LocaleConfig.supportedLocales,
      home: Scaffold(drawer: const Drawer(), body: page),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 1280.0]) {
    final layout = width < 600 ? 'phone' : 'web';

    testWidgets('$layout: Credit Cards page opens both built functions; the rest are Coming soon', (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        CreditCardsHubScreen(
          onCreditCardsTap: () => opened.add('cards'),
          onTransactionsTap: () => opened.add('transactions'),
        ),
        width: width,
      );

      await tester.tap(find.text('Transactions'));
      await tester.tap(find.text('See your cards, limits and dues'));
      expect(opened, ['transactions', 'cards']);
      expect(find.text('Coming soon'), findsOneWidget);
      for (final label in [
        'Credit Card Details',
        'Card Payment',
        'Request PIN',
        'Block/Unblock Card',
        'Cancel Card',
        'Auto Pay',
        'Reset PIN',
        'Add-On Card',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$layout: Bill Payments page opens Billers, Add Billers and History', (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        BillPaymentsHubScreen(
          onBillersTap: () => opened.add('billers'),
          onAddBillerTap: () => opened.add('add'),
          onHistoryTap: () => opened.add('history'),
        ),
        width: width,
      );

      await tester.tap(find.text('Billers'));
      await tester.tap(find.text('Add Billers'));
      await tester.tap(find.text('Bill Payment History'));
      expect(opened, ['billers', 'add', 'history']);
      for (final label in ['Favorites', 'Quick Bill Pay', 'Quick Recharge']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone: opened from the side menu, a module page shows ‹ (as Loans), not ☰', (tester) async {
    var backs = 0;
    final pages = <Widget Function(VoidCallback?)>[
      (b) => CurrentSavingsHubScreen(
            onBack: b,
            onAccountsTap: () {},
            onChequeBookTap: () {},
            onDebitCardsTap: () {},
            onSweepInTap: () {},
          ),
      (b) => CertificatesHubScreen(onBack: b, onInterestTap: () {}, onBalanceTap: () {}, onTdsTap: () {}),
      (b) => CreditCardsHubScreen(onBack: b, onCreditCardsTap: () {}, onTransactionsTap: () {}),
      (b) => BillPaymentsHubScreen(onBack: b, onBillersTap: () {}, onAddBillerTap: () {}, onHistoryTap: () {}),
    ];
    for (final page in pages) {
      await _pump(tester, page(() => backs++));
      expect(find.byType(HomeMenuButton), findsNothing);
      await tester.tap(find.byType(CasaBackButton));
      await _pump(tester, page(null));
      expect(find.byType(HomeMenuButton), findsOneWidget, reason: 'no back: the menu, as before');
      expect(find.byType(CasaBackButton), findsNothing);
    }
    expect(backs, 4);
  });
}
