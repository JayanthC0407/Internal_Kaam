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
        {'type': 'CR', 'available': {'amount': 4200, 'currency': 'GBP'}},
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

  testWidgets('list: OBDX labels; dues vs No Dues; Transactions only where allowed', (tester) async {
    await pump(tester);
    expect(find.text('Credit Cards'), findsWidgets);
    expect(find.text('xxxx xxxx xxxx 1111'), findsOneWidget);
    expect(find.text('Total Due'), findsOneWidget, reason: 'only card 1111 has a billed amount');
    expect(find.text('Minimum Due'), findsOneWidget);
    expect(find.text('No Dues'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget, reason: 'the Add-On card has none');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Transactions: Unbilled first, Billed picks the latest month (0-based on the wire)', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.type, CardStatementType.unbilled);
    expect(find.text('Platinum-PRIMARY-xxxx 1111-Refund'), findsOneWidget);

    await tester.tap(find.text('Billed Transactions'));
    await tester.pumpAndSettle();
    final billed = repo.queries.where((q) => q.month != null).last;
    expect(billed.month, const CardStatementMonth(2026, 9));
    expect(billed.toQueryParameters()['statementMonth'], 8);
    expect(find.text('September 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('web: cards side by side, no overflow', (tester) async {
    await pump(tester, width: 1280);
    expect(find.text('xxxx xxxx xxxx 2222'), findsOneWidget);
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
