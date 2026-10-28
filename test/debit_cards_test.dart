import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/cards/debit_card_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/cards_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/debit_cards/debit_cards_screen.dart';

// Shapes follow OBDX debit-card-list (docs/obdx/features/debit-cards.md).
// Values are made up.

Map<String, dynamic> _card(String n, String status, {String account = 'A1'}) => {
      'cardNo': {'value': 'D$n', 'displayValue': 'xxxx xxxx xxxx $n'},
      'cardType': 'Visa',
      'cardHolderName': 'Jane Martin',
      'expiryDate': '2027-03-31T00:00:00',
      'cardStatus': status,
      'accountId': {'value': account, 'displayValue': 'xxxxxxxxxx$account'},
    };

Map<String, dynamic> _payload() => {
      'debitCardDetails': [
        _card('4444', 'CANCELLED'),
        _card('3333', 'HOTLISTED', account: 'A2'),
        _card('2222', 'ACTIVATED'),
        _card('9999', 'EXPIRED'),
        _card('1111', 'ACTIVE'),
      ],
    };

void main() {
  group('model (OBDX debit-card-list rules)', () {
    final cards = DebitCard.listFromPayload(_payload());

    test('order: ACTIVE, ACTIVATED (as ACTIVE), HOTLISTED (as BLOCKED), CANCELLED; others dropped', () {
      expect(cards.map((c) => c.cardNo), ['D1111', 'D2222', 'D3333', 'D4444']);
      expect(cards.map((c) => c.status), [
        DebitCardStatus.active,
        DebitCardStatus.active,
        DebitCardStatus.blocked,
        DebitCardStatus.cancelled,
      ]);
      expect(cards.first.expiryLabel, '03/27');
      expect(cards.first.accountDisplay, 'xxxxxxxxxxA1');
    });

    test('menu: Debit Card Limits always; ACTIVE five more; BLOCKED Block/Unblock', () {
      expect(debitCardMenu(cards[0]), [
        DebitCardAction.limits,
        DebitCardAction.blockUnblock,
        DebitCardAction.requestPin,
        DebitCardAction.upgradeCard,
        DebitCardAction.resetPin,
        DebitCardAction.reissueCard,
      ]);
      expect(debitCardMenu(cards[2]), [DebitCardAction.limits, DebitCardAction.blockUnblock]);
      expect(debitCardMenu(cards[3]), [DebitCardAction.limits]);
    });

    test('search and Filter (on the device)', () {
      expect(const DebitCardFilter(query: '3333').matches(cards[2]), isTrue);
      expect(const DebitCardFilter(query: 'jane').matches(cards[0]), isTrue);
      expect(const DebitCardFilter(status: DebitCardStatus.blocked).matches(cards[0]), isFalse);
      expect(const DebitCardFilter(accountId: 'A2').matches(cards[2]), isTrue);
      expect(const DebitCardFilter(accountId: 'A2').matches(cards[0]), isFalse);
    });
  });

  Future<void> pump(WidgetTester tester, {double width = 390, Map<String, dynamic>? payload}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardsRepositoryProvider.overrideWithValue(_FakeCards(payload ?? _payload()))],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleConfig.supportedLocales,
          home: const DebitCardsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone: card image, rows with Account Number, Block/Unblock where OBDX offers it', (tester) async {
    await pump(tester);
    expect(find.text('Debit Cards (4)'), findsOneWidget);
    expect(find.text('****  ****  ****  1111'), findsOneWidget, reason: 'the card image, first card');
    expect(find.text('Account Number'), findsNWidgets(4));
    expect(find.text('BLOCKED'), findsOneWidget);
    expect(find.text('CANCELLED'), findsOneWidget);
    // ACTIVE x2 and BLOCKED x1 have the button; CANCELLED has not.
    expect(find.widgetWithText(FilledButton, 'Block/Unblock Card'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('⋮: OBDX menu; actions are not built yet', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    for (final item in ['Debit Card Limits', 'Request PIN', 'Upgrade Card', 'Reset PIN', 'Reissue Card']) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    await tester.tap(find.text('Reissue Card'));
    await tester.pumpAndSettle();
    expect(find.text('Reissue Card · This feature will be available soon.'), findsOneWidget);
  });

  testWidgets('search and Filter: instant', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '3333');
    await tester.pumpAndSettle();
    expect(find.text('Debit Cards (1)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELLED').last);
    await tester.pumpAndSettle();
    expect(find.text('Debit Cards (1)'), findsOneWidget);
  });

  testWidgets('no cards: OBDX text', (tester) async {
    await pump(tester, payload: const {'debitCardDetails': <dynamic>[]});
    expect(find.text('No card to display'), findsOneWidget);
  });

  testWidgets('web: rows side by side, no overflow', (tester) async {
    await pump(tester, width: 1280);
    expect(find.text('xxxx xxxx xxxx 2222'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeCards implements CardsRepository {
  _FakeCards(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<ResponseHandler<List<DebitCard>>> fetchDebitCards() async =>
      ResponseHandler.success(DebitCard.listFromPayload(payload), code: 200);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
