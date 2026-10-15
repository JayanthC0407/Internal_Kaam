import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/dashboard_repository.dart';
import 'package:ubci_bank/src/infra/repositories/retail/accounts_repository.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/infra/session/session_manager.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/home/tabs/more_tab_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/accounts_tab_card.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/quick_actions_strip.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────

const _savings = CasaAccount(
  id: 'SAV1022',
  displayNumber: 'xxxxxxxxxxxx1022',
  status: 'ACTIVE',
  currencyCode: 'GBP',
  accountType: 'SAVING',
  productName: 'Savings Account',
  availableBalance: MoneyAmount(amount: 12450.75, currency: 'GBP'),
  isDefault: true,
);

const _current = CasaAccount(
  id: 'CUR3381',
  displayNumber: 'xxxxxxxxxxxx3381',
  status: 'ACTIVE',
  currencyCode: 'GBP',
  accountType: 'CURRENT',
  productName: 'Current Account',
  availableBalance: MoneyAmount(amount: 3280.40, currency: 'GBP'),
);

const _euro = CasaAccount(
  id: 'EUR0001',
  displayNumber: 'xxxxxxxxxxxx0001',
  status: 'ACTIVE',
  currencyCode: 'EUR',
  accountType: 'SAVING',
  productName: 'Euro Savings',
  availableBalance: MoneyAmount(amount: 999, currency: 'EUR'),
);

class _FakeAccounts implements AccountsRepository {
  @override
  Future<ResponseHandler<CasaAccountsSummary>> fetchCasaAccounts() async =>
      ResponseHandler.success(CasaAccountsSummary.fromAccounts(const [_savings, _current]), code: 200);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// `me/components`: [allowed], or a failed call when null.
class _FakeDashboard implements DashboardRepository {
  _FakeDashboard(this.allowed);

  final Set<String>? allowed;

  @override
  Future<ResponseHandler<DashboardAuthorizedComponents>> fetchAuthorizedComponents() async =>
      allowed == null
          ? ResponseHandler.exceptionError()
          : ResponseHandler.success(DashboardAuthorizedComponents(authorized: allowed!), code: 200);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeSession implements SessionManager {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('session ${i.memberName}');
}

class _FakeEnrollment implements BiometricEnrollmentController {
  @override
  Future<bool> isEnabled() async => false;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('enrollment ${i.memberName}');
}

class _FakeBiometrics implements BiometricService {
  @override
  Future<BiometricPresentation> presentation() async => BiometricPresentation.android;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('biometrics ${i.memberName}');
}

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  Map<String, Object> prefs = const {},
  Set<String>? allowed,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountsRepositoryProvider.overrideWithValue(_FakeAccounts()),
        sessionManagerProvider.overrideWithValue(_FakeSession()),
        biometricEnrollmentProvider.overrideWithValue(_FakeEnrollment()),
        biometricServiceProvider.overrideWithValue(_FakeBiometrics()),
        dashboardRepositoryProvider.overrideWithValue(_FakeDashboard(allowed)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleConfig.supportedLocales,
        home: Scaffold(body: body),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('Quick Actions (fixed)', () {
    testWidgets('four fixed tiles, no Edit; Transfer opens, the rest are Coming soon', (tester) async {
      var transfers = 0;
      await _pump(
        tester,
        ColoredBox(
          color: Colors.teal,
          child: QuickActionsStrip(onTransfer: () => transfers++),
        ),
      );
      for (final label in ['Quick Actions', 'Transfer', 'Scan & Pay', 'Bill', 'Saving']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Edit'), findsNothing);
      expect(find.text('More Services'), findsNothing);

      await tester.tap(find.text('Transfer'));
      expect(transfers, 1);
      await tester.tap(find.text('Bill'));
      await tester.pump();
      expect(find.textContaining('This feature will be available soon.'), findsOneWidget);
    });
  });

  group('Credit Card tab (phone)', () {
    testWidgets('cards swipe one at a time with dots, like Accounts', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: AccountsTabCard(
            framed: false,
            accounts: const [_savings],
            revealedAccountIds: const {},
            onToggleAccountVisibility: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Credit Card'));
      await tester.pumpAndSettle();
      expect(find.text('DEBIT'), findsOneWidget);
      expect(find.text('CREDIT'), findsNothing);
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('CREDIT'), findsOneWidget);
    });
  });

  group('Home accounts card (Total Balance)', () {
    Widget card({List<CasaAccount> accounts = const [_savings, _current], VoidCallback? onDeposit}) =>
        SingleChildScrollView(
          child: AccountsTabCard(
            framed: false,
            showTotalCard: true,
            accounts: accounts,
            revealedAccountIds: const {},
            onToggleAccountVisibility: (_) {},
            displayName: 'Sarah Johnson',
            onDeposit: onDeposit ?? () {},
          ),
        );

    testWidgets('opens on Total Balance, hidden until the eye is tapped', (tester) async {
      await _pump(tester, card());
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Total Balance'), findsOneWidget);
      expect(find.text('2 Accounts'), findsOneWidget);
      expect(find.textContaining('15,731.15'), findsNothing);

      await tester.tap(find.byTooltip('Total Balance'));
      await tester.pump();
      expect(find.textContaining('15,731.15'), findsOneWidget);
    });

    testWidgets('other currencies are not added into the total', (tester) async {
      await _pump(tester, card(accounts: const [_savings, _current, _euro]));
      await tester.tap(find.byTooltip('Total Balance'));
      await tester.pump();
      expect(find.textContaining('15,731.15'), findsOneWidget);
      expect(find.text('2 Accounts'), findsOneWidget);
    });

    testWidgets('"Primary Account" only on the primary card; Deposit opens', (tester) async {
      var deposits = 0;
      await _pump(tester, card(onDeposit: () => deposits++));
      // Page 2 is the primary (savings) card, page 3 the current account.
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Primary Account'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Primary Account'), findsNothing);
      await tester.tap(find.text('Deposit'));
      expect(deposits, 1);
    });
  });

  group('Menu', () {
    testWidgets('Personalize Dashboard only when the customer has one', (tester) async {
      await _pump(tester, const MoreTabScreen(displayName: 'Sarah Johnson'));
      expect(find.text('Personalize Dashboard'), findsNothing);

      var opened = 0;
      await _pump(
        tester,
        MoreTabScreen(displayName: 'Sarah Johnson', onPersonalize: () => opened++),
      );
      await tester.tap(find.text('Personalize Dashboard'));
      expect(opened, 1);
    });


    testWidgets('profile card, tiles and list; App Settings opens in place', (tester) async {
      var rewards = 0;
      await _pump(tester, MoreTabScreen(displayName: 'Sarah Johnson', onRewardsTap: () => rewards++));
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Sarah Johnson'), findsOneWidget);
      expect(find.text('•••• •••• •••• 1022'), findsOneWidget);
      for (final label in [
        'Networth',
        'Rewards',
        'Languages',
        "What's New",
        'Explore Products',
        'Notification',
        'App Settings',
        'Need Help',
        'Log out',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      await tester.tap(find.text('Rewards'));
      expect(rewards, 1);

      await tester.tap(find.text('Networth'));
      await tester.pump();
      expect(find.textContaining('This feature will be available soon.'), findsOneWidget);

      await tester.tap(find.text('App Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Forget device'), findsOneWidget);
      expect(find.text('Log out'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Menu'), findsOneWidget);
    });
  });
}
