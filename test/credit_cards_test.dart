import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/cards_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/credit_cards_screen.dart';

// Shapes follow OBDX credit-card-listing and account-transactions (type
// CREDIT) — docs/obdx/features/credit-cards.md. Values are made up.

Map<String, dynamic> _card(
  String n, {
  String status = 'ACT',
  String ownership = 'PRIMARY',
  num billed = 0,
}) =>
    {
      'creditCard': {'value': 'C$n', 'displayValue': 'xxxx xxxx xxxx $n'},
      'ownerName': 'Sarah Johnson',
      'cardStatus': status,
      'cardOwnershipType': ownership,
      'validity': {'end': '2028-03-31T00:00:00'},
      'limits': [
        {'type': 'CA', 'available': {'amount': 99, 'currency': 'GBP'}},
        {
          'type': 'CR',
          'available': {'amount': 4200, 'currency': 'GBP'},
          'total': {'amount': 5000, 'currency': 'GBP'},
        },
      ],
      'due': {
        'unbilledAmount': {'amount': 310.5, 'currency': 'GBP'},
        'billedAmount': {'amount': billed, 'currency': 'GBP'},
        'minimumAmount': {'amount': 25, 'currency': 'GBP'},
        'expectedPaymentDate': '2026-11-10T00:00:00',
      },
    };

Map<String, dynamic> _statement() => {
      'statement': [
        {
          'statementDate': '15-09-2026',
          'product': 'Platinum',
          'cardOwnershipType': 'PRIMARY',
          'number': {'displayValue': 'xxxx 1111'},
          'statmentItems': [
            {
              'transactionDate': '2026-09-02T00:00:00',
              'crdrFlag': 'D',
              'transactionDescription': 'Grocer',
              'amount': {'amount': 40, 'currency': 'GBP'},
            },
            {
              'transactionDate': '2026-09-10T00:00:00',
              'crdrFlag': 'C',
              'transactionDescription': 'Refund',
              'amount': {'amount': 12, 'currency': 'GBP'},
            },
          ],
        },
      ],
    };

void main() {
  group('model', () {
    test('card fields read like OBDX: CR limit, dues, MM/YY expiry', () {
      final c = CreditCard.fromJson(_card('1111', billed: 150))!;
      expect(c.id, 'C1111');
      expect(c.availableCredit?.amount, 4200, reason: 'the limits[] entry of type CR');
      expect(c.currentOutstanding?.amount, 310.5);
      expect(c.hasDues, isTrue);
      expect(c.dueDate, DateTime(2026, 11, 10));
      expect(c.expiryLabel, '03/28');
      expect(c.status, CreditCardStatus.active);
    });

    test('billed 0 → No Dues; Transactions only for PRIMARY, not INACTIVE', () {
      expect(CreditCard.fromJson(_card('1'))!.hasDues, isFalse);
      expect(CreditCard.fromJson(_card('1'))!.canViewTransactions, isTrue);
      expect(CreditCard.fromJson(_card('1', ownership: 'ADDON'))!.canViewTransactions, isFalse);
      expect(CreditCard.fromJson(_card('1', status: 'IAT'))!.canViewTransactions, isFalse);
    });

    test('12 billed months back from the statement date, across a year', () {
      final months = billedMonths(DateTime(2026, 2, 15));
      expect(months.length, 12);
      expect(months.first, const CardStatementMonth(2026, 2));
      expect(months[2], const CardStatementMonth(2025, 12));
      expect(months.last, const CardStatementMonth(2025, 3));
    });

    test('query: Unbilled has no month; Billed sends OBDX\'s 0-based month', () {
      expect(const CardTransactionsQuery(cardId: 'C1').toQueryParameters(), {'type': 'UNBILLED'});
      expect(
        const CardTransactionsQuery(
          cardId: 'C1',
          type: CardStatementType.billed,
          month: CardStatementMonth(2026, 10),
        ).toQueryParameters(),
        {'type': 'BILLED', 'statementMonth': 9, 'statementYear': 2026},
      );
      expect(
        const CardTransactionsQuery(cardId: 'C1', type: CardStatementType.billed).toQueryParameters(),
        {'type': 'BILLED'},
        reason: 'the probe for the statement date',
      );
    });

    test('statement: statmentItems, OBDX description, newest first, DD-MM-YYYY date', () {
      final r = CardStatementResult.fromPayload(_statement());
      expect(r.statementDate, DateTime(2026, 9, 15));
      expect(r.transactions.map((t) => t.description), [
        'Platinum-PRIMARY-xxxx 1111-Refund',
        'Platinum-PRIMARY-xxxx 1111-Grocer',
      ]);
      expect(r.transactions.first.isCredit, isTrue);
    });
  });

  group('design (2026-10-27)', () {
    final primary = CreditCard.fromJson(_card('1111', billed: 150))!;
    final addOn = CreditCard.fromJson(_card('2222', ownership: 'ADDON'))!;

    test("⋮ menu: OBDX's order and rules by ownership and status", () {
      expect(creditCardMenu(primary), [
        CreditCardAction.details,
        CreditCardAction.transactions,
        CreditCardAction.cardPayment,
        CreditCardAction.requestPin,
        CreditCardAction.resetPin,
        CreditCardAction.blockCard,
        CreditCardAction.cancelCard,
        CreditCardAction.autoPay,
        CreditCardAction.addOnCard,
      ]);
      expect(creditCardMenu(addOn), [
        CreditCardAction.details,
        CreditCardAction.requestPin,
        CreditCardAction.resetPin,
        CreditCardAction.blockCard,
        CreditCardAction.cancelCard,
      ]);
      final blocked = CreditCard.fromJson(_card('3333', status: 'BLK'))!;
      expect(creditCardMenu(blocked), [
        CreditCardAction.details,
        CreditCardAction.transactions,
        CreditCardAction.cardPayment,
        CreditCardAction.unblockCard,
        CreditCardAction.cancelCard,
      ]);
      final inactive = CreditCard.fromJson(_card('4444', status: 'IAT'))!;
      expect(creditCardMenu(inactive), [CreditCardAction.details, CreditCardAction.cancelCard]);
    });

    test('tiles: totals per currency from the card list', () {
      final usd = CreditCard.fromJson({
        ..._card('5555'),
        'limits': [
          {'type': 'CR', 'available': {'amount': 1, 'currency': 'USD'}, 'total': {'amount': 900, 'currency': 'USD'}},
        ],
      })!;
      final totals = CreditCardTotals.fromCards([primary, addOn, usd]);
      expect(totals.map((t) => t.currency), ['GBP', 'USD']);
      final gbp = totals.first;
      expect(gbp.creditLimit, 10000);
      expect(gbp.outstanding, 621);
      expect(gbp.totalDue, 150, reason: 'billed amounts only');
      expect(gbp.activeCards, 2);
      expect(gbp.nextDue, DateTime(2026, 11, 10));
      expect(gbp.outstandingShare!.toStringAsFixed(1), '6.2');
    });

    test('search and Filter (on the device)', () {
      bool m(CreditCardFilter f, CreditCard c) => f.matches(c);
      expect(m(const CreditCardFilter(query: '2222'), addOn), isTrue);
      expect(m(const CreditCardFilter(query: '2222'), primary), isFalse);
      expect(m(const CreditCardFilter(query: 'sarah'), primary), isTrue, reason: 'holder name');
      expect(m(const CreditCardFilter(primary: false), addOn), isTrue);
      expect(m(const CreditCardFilter(primary: false), primary), isFalse);
      expect(m(const CreditCardFilter(cardId: 'C1111'), addOn), isFalse);
    });
  });

  Future<_FakeCards> pump(WidgetTester tester, {double width = 390}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeCards();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cardsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleConfig.supportedLocales,
          home: const CreditCardsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('list: tiles, OBDX labels, dues vs No Dues', (tester) async {
    await pump(tester);
    expect(find.text('Credit Cards (2)'), findsOneWidget);
    expect(find.text('Total Credit Limit'), findsOneWidget);
    expect(find.text('2 active cards'), findsOneWidget);
    expect(find.text('6.2% of total limit'), findsOneWidget);
    expect(find.text('xxxx xxxx xxxx 1111'), findsOneWidget);
    // The tile, and card 1111 (the only one billed).
    expect(find.text('Total Due'), findsNWidgets(2));
    expect(find.text('Minimum Due'), findsOneWidget);
    expect(find.text('No Dues'), findsOneWidget);
    expect(find.text('Add-On Card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("⋮: OBDX's menu; unbuilt actions say Coming soon", (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    for (final item in ['Credit Card Details', 'Transactions', 'Card Payment', 'Block Card', 'Add-On Card']) {
      expect(find.text(item), findsWidgets, reason: item);
    }
    await tester.tap(find.text('Block Card'));
    await tester.pumpAndSettle();
    expect(find.text('Block Card · This feature will be available soon.'), findsOneWidget);

    await tester.tap(find.byTooltip('More actions').last);
    await tester.pumpAndSettle();
    expect(find.text('Transactions'), findsNothing, reason: 'Add-On card');
  });

  testWidgets('search, Filter and the eye: instant', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '2222');
    await tester.pumpAndSettle();
    expect(find.text('Credit Cards (1)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add-On Card').last);
    await tester.pumpAndSettle();
    expect(find.text('Credit Cards (1)'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Credit Cards (2)'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hide amounts').first);
    await tester.pumpAndSettle();
    expect(find.text('******'), findsNWidgets(3));
  });

  testWidgets('Transactions: Unbilled first, Billed picks the latest month (0-based on the wire)', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    expect(repo.queries.last.type, CardStatementType.unbilled);
    expect(find.text('Platinum-PRIMARY-xxxx 1111-Refund'), findsOneWidget);
    expect(find.text('Amount'), findsNothing, reason: 'OBDX never applies it to cards');

    // View Options: a choice reloads at once.
    await tester.tap(find.text('Unbilled Transactions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Billed Transactions').last);
    await tester.pumpAndSettle();
    final billed = repo.queries.where((q) => q.month != null).last;
    expect(billed.month, const CardStatementMonth(2026, 9));
    expect(billed.toQueryParameters()['statementMonth'], 8);
    expect(find.text('September 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('web: rows, then the Transactions table', (tester) async {
    await pump(tester, width: 1280);
    expect(find.text('xxxx xxxx xxxx 2222'), findsOneWidget);
    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    for (final h in ['Date', 'Description', 'Transaction Type', 'Amount']) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    expect(find.text('Credit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeCards implements CardsRepository {
  final queries = <CardTransactionsQuery>[];

  @override
  Future<ResponseHandler<List<CreditCard>>> fetchCreditCards() async => ResponseHandler.success(
        CreditCard.listFromPayload({
          'creditcards': [
            _card('1111', billed: 150),
            _card('2222', ownership: 'ADDON'),
          ],
        }),
        code: 200,
      );

  @override
  Future<ResponseHandler<CardStatementResult>> fetchTransactions(CardTransactionsQuery query) async {
    queries.add(query);
    return ResponseHandler.success(CardStatementResult.fromPayload(_statement()), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
