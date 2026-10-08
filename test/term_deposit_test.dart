import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/retail/account_transaction.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit_actions.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_term_deposit_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/term_deposit_repository.dart';
import 'package:ubci_bank/src/view/providers/retail/term_deposit_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_maturity_edit_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_open_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_redeem_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_route_args.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_top_up_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/term_deposit_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/term_deposits_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/widgets/td_shared_widgets.dart';

// ── Payloads shaped like the TD capture (values made up) ────────────────

Map<String, dynamic> _depositJson(
  String id, {
  String number = 'xxxxxxxxxxxx8078',
  String status = 'ACTIVE',
  double current = 122000,
  double maturity = 124869.77,
  String rollOver = 'A',
}) =>
    {
      'id': {'displayValue': number, 'value': id},
      'partyId': {'displayValue': '***788', 'value': 'P1'},
      'displayName': 'DEMO CUSTOMER',
      'partyName': 'DEMO CUSTOMER1',
      'status': status,
      'type': 'TRD',
      'currencyCode': 'GBP',
      'branchCode': '000',
      'productDTO': {'variance': 0},
      'openingDate': '2022-12-22T00:00:00',
      'valueDate': '2022-12-22T00:00:00',
      'branchAddressDTO': {'id': '000', 'branchName': 'CITY HEAD OFFICE'},
      'holdingPattern': 'SINGLE',
      'module': 'CON',
      'maturityAmount': {'currency': 'GBP', 'amount': maturity},
      'maturityDate': '2023-03-22T00:00:00',
      'principalAmount': {'currency': 'GBP', 'amount': 105000},
      'currentPrincipalAmount': {'currency': 'GBP', 'amount': current},
      'availableBalance': {'currency': 'GBP', 'amount': current},
      'holdAmount': {'currency': 'GBP', 'amount': 0},
      'tenure': {'days': 0, 'months': 3, 'years': 0},
      'interestRate': 10,
      'rollOverType': rollOver,
      'payoutInstructions': [],
    };

final _listPayload = {
  'accounts': [
    _depositJson('TD1'),
    _depositJson('TD2',
        number: 'xxxxxxxxxxxx8069', current: 90000, maturity: 92117.05),
    _depositJson('TD3',
        number: 'xxxxxxxxxxxx7001', status: 'CLOSED', current: 0, maturity: 0),
  ],
};

final _payoutPayload = {
  'payOutInstructions': [
    {
      'branchId': '000',
      'percentage': 100,
      'type': 'I',
      'payoutComponentType': 'P',
      'account': '000@~000000788014',
    },
  ],
};

final _casaPayload = {
  'accounts': [
    {
      'id': {'displayValue': 'xxxxxxxxxxxx8014', 'value': 'CASA1'},
      'partyName': 'DEMO CUSTOMER1',
      'branchCode': '000',
      'currencyCode': 'GBP',
      'availableBalance': {'currency': 'GBP', 'amount': 83645.84},
      'holdingPattern': 'SINGLE',
    },
    {
      'id': {'displayValue': 'xxxxxxxxxxxx9999', 'value': 'WAL1'},
      'currencyCode': 'GBP',
      'productDTO': {'productId': 'WALLET'},
    },
  ],
};

TermDeposit _deposit([String id = 'TD1']) =>
    TermDeposit.listFromPayload(_listPayload).firstWhere((d) => d.id == id);

final _casa = TdPayAccount.listFromPayload(_casaPayload).single;

// ── A fake repository ────────────────────────────────────────────────────

class _FakeRepository implements TermDepositRepository {
  _FakeRepository({this.products = const [], this.needOtp = false});

  final List<TdProduct> products;
  bool needOtp;
  final calls = <String>[];
  TdRedeemRequest? redeemed;
  TdMaturityUpdate? updated;

  Future<ResponseHandler<T>> _ok<T>(T value) async =>
      ResponseHandler.success(value, code: 200);

  @override
  Future<ResponseHandler<TermDepositsSummary>> fetchDeposits({
    bool includeClosed = true,
  }) =>
      _ok(TermDepositsSummary.fromPayload(_listPayload));

  @override
  Future<ResponseHandler<TermDeposit>> fetchDeposit(String id) =>
      _ok(_deposit(id));

  @override
  Future<ResponseHandler<List<TdPayoutInstruction>>> fetchPayoutInstructions(
    String id,
  ) =>
      _ok(TdPayoutInstruction.listFromPayload(_payoutPayload));

  @override
  Future<ResponseHandler<List<AccountTransaction>>> fetchTransactions(
    String id, {
    TdTransactionPeriod period = TdTransactionPeriod.currentMonth,
    String transactionType = 'A',
    DateTime? from,
    DateTime? to,
  }) {
    calls.add('txn:${period.code}:$transactionType');
    return _ok(AccountTransaction.listFromPayload({
      'items': [
        {
          'transactionDate': '2022-12-22T00:00:00',
          'amountInAccountCurrency': {'currency': 'GBP', 'amount': 2000},
          'description': 'NEW DEPOSIT',
          'key': {'transactionReferenceNumber': '000TOPD223560120'},
          'transactionType': 'C',
        },
      ],
    }));
  }

  @override
  Future<ResponseHandler<List<TdEnumOption>>> fetchEnumeration(String name) =>
      _ok(const []);

  @override
  Future<ResponseHandler<List<TdPayAccount>>> fetchPayAccounts(
    String taskCode,
  ) =>
      _ok([_casa]);

  @override
  Future<ResponseHandler<TdBranch?>> fetchBranch(String code) => _ok(
        const TdBranch(name: 'CITY HEAD OFFICE', line1: 'Unit 1'),
      );

  @override
  Future<ResponseHandler<List<TdProduct>>> fetchProducts() => _ok(products);

  @override
  Future<ResponseHandler<TdTopUpQuote>> simulateTopUp({
    required TermDeposit deposit,
    required double amount,
    required TdPayAccount source,
  }) {
    calls.add('simulateTopUp:$amount');
    return _ok(TdTopUpQuote.fromPayload({
      'topUpDetail': {
        'revisedPricipal': {'currency': 'GBP', 'amount': 122000 + amount},
        'revisedMaturity': {'currency': 'GBP', 'amount': 130000},
        'revisedInterestRate': 10,
      },
    }, request: const {}));
  }

  Future<ResponseHandler<TdSubmitOutcome>> _submit(String what, String? otp) {
    calls.add('$what${otp == null ? '' : ':$otp'}');
    if (needOtp && otp == null) {
      return _ok(const TdNeedsOtp(
        ObdxChallenge(authType: 'OTP', referenceNo: 'CH1', attemptsLeft: 3),
      ));
    }
    return _ok(const TdSubmitted(reference: 'REF-123'));
  }

  @override
  Future<ResponseHandler<TdSubmitOutcome>> confirmTopUp({
    required String depositId,
    required TdTopUpQuote quote,
    String? otp,
    ObdxChallenge? challenge,
  }) =>
      _submit('confirmTopUp', otp);

  @override
  Future<ResponseHandler<TdRedemptionQuote>> quoteRedemption(
    TdRedeemRequest request,
  ) {
    calls.add('quote:${request.type.code}:${request.amount}');
    return _ok(TdRedemptionQuote.fromPayload({
      'redemptionDetailDTO': {
        'charges': {'currency': 'GBP', 'amount': 150},
        'netCreditAmt': {'currency': 'GBP', 'amount': 121850},
      },
    }));
  }

  @override
  Future<ResponseHandler<TdSubmitOutcome>> redeem({
    required TdRedeemRequest request,
    required TdRedemptionQuote quote,
    String? otp,
    ObdxChallenge? challenge,
  }) {
    redeemed = request;
    return _submit('redeem', otp);
  }

  @override
  Future<ResponseHandler<TdSubmitOutcome>> updateMaturity({
    required TdMaturityUpdate update,
    String? otp,
    ObdxChallenge? challenge,
  }) {
    updated = update;
    return _submit('updateMaturity', otp);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── A fake API, for the repository tests ────────────────────────────────

class _FakeApi implements ObdxTermDepositApi {
  _FakeApi(this.answer);

  final Map<String, dynamic> answer;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> updateMaturity(
    String id,
    Map<String, dynamic> body, {
    String? challengeResponse,
  }) async =>
      ResponseHandler.success(answer);

  @override
  Future<ResponseHandler<Map<String, dynamic>>> redeem(
    String id,
    Map<String, dynamic> body, {
    String? challengeResponse,
  }) async =>
      ResponseHandler.success(answer);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Pumping ──────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required _FakeRepository repository,
  double width = 1280,
  double height = 1400,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        termDepositRepositoryProvider.overrideWithValue(repository),
        tdBusinessDateProvider
            .overrideWith((ref) async => DateTime(2023, 3, 2)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleConfig.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('parsing the captured responses', () {
    test('the list: active and closed, totals from the active ones', () {
      final summary = TermDepositsSummary.fromPayload(_listPayload);
      expect(summary.deposits, hasLength(3));
      expect(summary.active, hasLength(2));
      expect(summary.closed, hasLength(1));
      final gbp = summary.totals.single;
      expect(gbp.currency, 'GBP');
      expect(gbp.count, 2);
      expect(gbp.invested, 212000);
      expect(gbp.maturity, closeTo(216986.82, 0.001));
      expect(gbp.expectedInterest, closeTo(4986.82, 0.001));
    });

    test('a deposit: identity, amounts, tenure, roll-over', () {
      final d = TermDeposit.fromDetailPayload({
        'termDepositDetails': _depositJson('TD1'),
      })!;
      expect(d.id, 'TD1');
      expect(d.lastFour, '8078');
      expect(d.currentValue!.amount, 122000);
      expect(d.tenure.label, '3 months');
      expect(d.rollOverType, TdRollOver.closeOnMaturity);
      expect(d.branchName, 'CITY HEAD OFFICE');
      expect(d.daysToMaturity(DateTime(2023, 3, 2)), 20);
    });

    test('payout instructions: the account number masked', () {
      final p = TdPayoutInstruction.listFromPayload(_payoutPayload).single;
      expect(p.componentType, 'P');
      expect(p.percentage, 100);
      expect(p.accountLabel, '••8014');
    });

    test('an enumeration', () {
      final options = TdEnumOption.listFromPayload({
        'enumRepresentations': [
          {
            'data': [
              {
                'code': 'P',
                'description': 'Renew Principal and Pay Out the Interest'
              },
              {'code': 'A', 'description': 'Close on Maturity'},
            ],
          },
        ],
      });
      expect([for (final o in options) o.code], ['P', 'A']);
    });

    test('pay accounts skip wallets', () {
      expect(TdPayAccount.listFromPayload(_casaPayload), hasLength(1));
      expect(_casa.partyName, 'DEMO CUSTOMER1');
      expect(_casa.branchCode, '000');
    });
  });

  group('the requests, as the OBDX web client builds them', () {
    test('top-up simulation body', () {
      final body = TdTopUpQuote.request(
        deposit: _deposit(),
        amount: 500,
        source: _casa,
      );
      expect(body['amount'], {'currency': 'GBP', 'amount': 500.0});
      expect(body['sourceAccountId'],
          {'value': 'CASA1', 'displayValue': 'xxxxxxxxxxxx8014'});
      expect(body['account'],
          {'displayValue': 'xxxxxxxxxxxx8078', 'value': 'TD1'});
      expect(body['currentPrincipal'], {'currency': 'GBP', 'amount': 122000.0});
    });

    test("top-up quote reads OBDX's misspelt revisedPricipal", () {
      final q = TdTopUpQuote.fromPayload({
        'topUpDetail': {
          'revisedPricipal': {'currency': 'GBP', 'amount': 122500},
        },
      }, request: const {});
      expect(q.revisedPrincipal!.amount, 122500);
      expect(q.raw.containsKey('revisedPricipal'), isTrue);
    });

    test('redeem: the quote fills the amounts the host requires', () {
      final request = TdRedeemRequest(
        deposit: _deposit(),
        type: TdRedemptionType.full,
        amount: 122000,
        payout: TdPayout.own(
          account: _casa,
          branch: const TdBranch(name: 'CITY HEAD OFFICE', line1: 'Unit 1'),
        ),
      );
      final quote = TdRedemptionQuote.fromPayload({
        'redemptionDetailDTO': {
          'charges': {'currency': 'GBP', 'amount': 150},
          'maturityAmount': {'currency': 'GBP', 'amount': 124869.77},
          'netCreditAmt': {'currency': 'GBP', 'amount': 121850},
          'revisedPrincipalAmount': {'currency': 'GBP', 'amount': 0},
          'revisedMaturityAmount': {'currency': 'GBP', 'amount': 0},
        },
      });
      final body = request.toJson(quote: quote);
      expect(body['typeRedemption'], 'F');
      expect(body['module'], 'CON');
      expect(body['redemptionAmount'], {'currency': 'GBP', 'amount': 122000.0});
      // The fields the UAT capture sent empty, and the host rejected:
      for (final key in [
        'netCreditAmt',
        'charges',
        'maturityAmount',
        'revisedPrincipalAmount',
        'revisedMaturityAmount',
      ]) {
        expect((body[key] as Map)['currency'], 'GBP', reason: key);
        expect((body[key] as Map)['amount'], isNotNull, reason: key);
      }
      final payout = (body['payoutInstructions'] as List).single as Map;
      expect(payout['type'], 'O');
      expect(payout['beneficiaryName'], 'DEMO CUSTOMER1');
      expect(payout['bankName'], 'CITY HEAD OFFICE');
      expect(payout['branchId'], '000');
      expect((payout['address'] as Map)['line1'], 'Unit 1');
      expect(payout['payoutComponentType'], isNull);
    });

    test('maturity edit: which payout goes with which roll-over', () {
      TdMaturityUpdate update(String code, {double? amount}) =>
          TdMaturityUpdate(
            deposit: _deposit(),
            rollOverType: code,
            payout: TdPayout.own(account: _casa),
            rollOverAmount: amount,
          );
      Map component(Map<String, dynamic> body) =>
          (body['payoutInstructions'] as List).single as Map;

      // Renew principal → the interest is paid out (the captured PUT).
      final p = update('P').toJson();
      expect(p['rollOverType'], 'P');
      expect(component(p)['payoutComponentType'], 'I');
      expect(p.containsKey('rollOverAmount'), isFalse);

      // Close → the principal is paid out.
      expect(component(update('A').toJson())['payoutComponentType'], 'P');

      // Special amount → the rest is paid out, and the amount is sent.
      final s = update('S', amount: 50000).toJson();
      expect(component(s)['payoutComponentType'], 'P');
      expect(s['rollOverAmount'], {'currency': 'GBP', 'amount': 50000.0});

      // Renew everything → nothing is paid out.
      expect(update('I').toJson().containsKey('payoutInstructions'), isFalse);
    });

    test('an internal-account payout sends no address', () {
      final json = const TdPayout.internal(accountNumber: '000000123456')
          .toJson(componentType: 'P');
      expect(json['type'], 'I');
      expect(json['account'], '000000123456');
      expect(json['address'], isNull);
    });

    test('open: product, pay-in account, tenure, maturity', () {
      final body = TdOpenRequest(
        product: TdProduct.fromJson({
          'productId': 'TD01',
          'name': 'Fixed Deposit',
          'module': 'CON',
          'amountParameters': [
            {
              'currency': 'GBP',
              'minAmount': {'amount': 1000},
              'maxAmount': {'amount': 500000},
            },
          ],
          'tenureParameter': {
            'minTenure': {'years': 0, 'months': 1, 'days': 0},
            'maxTenure': {'years': 5, 'months': 0, 'days': 0},
          },
        }),
        source: _casa,
        currency: 'GBP',
        amount: 10000,
        tenure: const TdTenure(months: 6),
        rollOverType: TdRollOver.renewPrincipalAndInterest,
        holderName: 'DEMO CUSTOMER1',
      ).toJson();
      expect(body['productDTO'], {
        'productId': 'TD01',
        'name': 'Fixed Deposit',
        'depositProductModule': 'TD',
        'accrualFrequency': null,
      });
      expect(body['principalAmount'], {'currency': 'GBP', 'amount': 10000.0});
      expect(body['tenure'], {'years': 0, 'months': 6, 'days': 0});
      expect(body['holdingPattern'], 'SINGLE');
      expect(body.containsKey('payoutInstructions'), isFalse);
      expect(
        ((body['payInInstruction'] as List).single as Map)['accountId'],
        {'displayValue': 'xxxxxxxxxxxx8014', 'value': 'CASA1'},
      );
    });

    test('a product: limits and tenure', () {
      final product = TdProduct.listFromPayload({
        'tdProductDTOList': [
          {
            'productId': 'TD01',
            'name': 'Fixed Deposit',
            'paymentType': 'D',
            'amountParameters': [
              {
                'currency': 'GBP',
                'minAmount': {'amount': 1000},
                'maxAmount': {'amount': 500000},
              },
            ],
            'tenureParameter': {
              'minTenure': {'months': 1},
              'maxTenure': {'years': 5},
            },
          },
        ],
      }).single;
      expect(product.discounted, isTrue);
      expect(product.limitFor('GBP')!.min, 1000);
      expect(product.minTenure!.label, '1 month');
      expect(product.maxTenure!.label, '5 years');
      // The capture's empty list.
      expect(TdProduct.listFromPayload({'tdProductDTOList': []}), isEmpty);
    });

    test("each flow's success reference", () {
      expect(TdSubmitted.fromPayload({'hostReference': 'H1'}).reference, 'H1');
      expect(
        TdSubmitted.fromPayload({
          'topUpDetail': {'topUpReferenceNumber': 'T1'},
        }).reference,
        'T1',
      );
      expect(
        TdSubmitted.fromPayload({
          'redemptionDetail': [
            {'redeemReferenceNo': 'R1'},
          ],
        }).reference,
        'R1',
      );
      final opened = TdSubmitted.fromPayload({
        'hostReference': 'H2',
        'termDepositDetails': {
          'id': {'displayValue': 'xxxxxxxxxxxx1234'},
        },
      });
      expect(opened.newDepositNumber, 'xxxxxxxxxxxx1234');
    });
  });

  group('the repository', () {
    test("a 417 with OBDX's challenge asks for the OTP", () async {
      final repository = TermDepositRepository(
        api: _FakeApi({
          'statusCode': 417,
          'headers': {
            'X-CHALLENGE': [
              '{"referenceNo":"CH9","authType":"OTP","attemptsLeft":2}'
            ],
          },
          'body': {},
        }),
      );
      final result = await repository.updateMaturity(
        update: TdMaturityUpdate(
          deposit: _deposit(),
          rollOverType: TdRollOver.renewPrincipalAndInterest,
        ),
      );
      final outcome = (result as Success<TdSubmitOutcome>).data;
      expect(outcome, isA<TdNeedsOtp>());
      expect((outcome as TdNeedsOtp).challenge.referenceNo, 'CH9');
    });

    test('a 201 is done; an OBDX error is a failure', () async {
      final done = await TermDepositRepository(
        api: _FakeApi({
          'statusCode': 201,
          'body': {
            'redemptionDetail': [
              {'redeemReferenceNo': 'R9'},
            ],
          },
        }),
      ).redeem(
        request: TdRedeemRequest(
          deposit: _deposit(),
          type: TdRedemptionType.full,
          amount: 1,
          payout: null,
        ),
        quote: const TdRedemptionQuote(),
      );
      expect(
        ((done as Success<TdSubmitOutcome>).data as TdSubmitted).reference,
        'R9',
      );

      final failed = await TermDepositRepository(
        api: _FakeApi({
          'statusCode': 400,
          'body': {
            'status': {
              'result': 'SUCCESSFUL',
              'message': {
                'code': 'DIGX_OR_AT_0003',
                'detail': 'Error while communicating with the host.',
                'type': 'ERROR',
              },
            },
          },
        }),
      ).updateMaturity(
        update: TdMaturityUpdate(deposit: _deposit(), rollOverType: 'I'),
      );
      expect(failed, isNot(isA<Success<TdSubmitOutcome>>()));
    });
  });

  group('the screens', () {
    testWidgets('the list on the web: portfolio, cards, active and closed',
        (tester) async {
      await _pump(
        tester,
        const TermDepositsListScreen(),
        repository: _FakeRepository(),
      );
      expect(find.text('Term Deposits'), findsOneWidget);
      expect(find.text('Total invested'), findsOneWidget);
      expect(find.textContaining('212,000'), findsOneWidget);
      expect(find.text('Term Deposit ••8078'), findsOneWidget);
      expect(find.text('Term Deposit ••8069'), findsOneWidget);
      expect(find.text('Matures in 20 days'), findsNWidgets(2));
      await _tapText(tester, 'Closed (1)');
      expect(find.text('Term Deposit ••7001'), findsOneWidget);
      expect(find.text('Term Deposit ••8078'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the list fits a phone', (tester) async {
      await _pump(
        tester,
        const TermDepositsListScreen(),
        repository: _FakeRepository(),
        width: 390,
        height: 1600,
      );
      expect(find.text('Term Deposit ••8078'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('details: sections, payout, transactions, actions',
        (tester) async {
      final repository = _FakeRepository();
      await _pump(
        tester,
        TermDepositDetailsScreen(
          args: TermDepositDetailsArgs(deposit: _deposit()),
        ),
        repository: repository,
        height: 2400,
      );
      for (final text in [
        'Deposit details',
        'Maturity',
        'General details',
        'Transactions',
        'Top up',
        'Redeem',
        'Edit maturity',
        'Close on Maturity',
        '100% of principal to ••8014',
        'NEW DEPOSIT',
        'CITY HEAD OFFICE',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      await _tapText(tester, 'Last 10');
      expect(repository.calls, contains('txn:LNT:A'));
      await _tapText(tester, 'Credits');
      expect(repository.calls, contains('txn:LNT:C'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('details fit a phone', (tester) async {
      await _pump(
        tester,
        TermDepositDetailsScreen(
          args: TermDepositDetailsArgs(deposit: _deposit()),
        ),
        repository: _FakeRepository(),
        width: 360,
        height: 2600,
      );
      expect(find.text('Top up'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a closed deposit offers no actions', (tester) async {
      await _pump(
        tester,
        TermDepositDetailsScreen(
          args: TermDepositDetailsArgs(deposit: _deposit('TD3')),
        ),
        repository: _FakeRepository(),
      );
      expect(find.text('Top up'), findsNothing);
      expect(find.text('Redeem'), findsNothing);
    });

    testWidgets('top-up: amount → simulated review → OTP → done',
        (tester) async {
      final repository = _FakeRepository(needOtp: true);
      await _pump(
        tester,
        TdTopUpScreen(args: TdActionArgs(deposit: _deposit())),
        repository: repository,
        width: 390,
        height: 1600,
      );
      // Nothing entered: both fields complain.
      await _tapText(tester, 'Continue');
      expect(find.text('Enter an amount.'), findsOneWidget);
      expect(find.text('Select an account.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '500');
      await _tapText(tester, 'Select an account');
      await _tapText(tester, 'xxxxxxxxxxxx8014');
      await _tapText(tester, 'Continue');
      expect(repository.calls, contains('simulateTopUp:500.0'));
      expect(find.text('Revised principal'), findsOneWidget);
      expect(find.textContaining('122,500'), findsOneWidget);

      await _tapText(tester, 'Confirm top-up');
      // The host asked for an OTP.
      expect(find.byType(TdOtpSheet), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '1234');
      await _tapText(tester, 'Verify');
      expect(repository.calls, contains('confirmTopUp:1234'));
      expect(find.text('Deposit topped up'), findsOneWidget);
      expect(find.text('REF-123'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('redeem: full, own account, quote, done', (tester) async {
      final repository = _FakeRepository();
      await _pump(
        tester,
        TdRedeemScreen(args: TdActionArgs(deposit: _deposit())),
        repository: repository,
        width: 390,
        height: 1800,
      );
      await _tapText(tester, 'Continue');
      expect(find.text('Choose where the money goes.'), findsOneWidget);

      await _tapText(tester, 'Select an account');
      await _tapText(tester, 'xxxxxxxxxxxx8014');
      await _tapText(tester, 'Continue');
      expect(repository.calls, contains('quote:F:122000.0'));
      expect(find.text('Final redemption amount'), findsOneWidget);
      expect(find.textContaining('121,850'), findsOneWidget);

      await _tapText(tester, 'Confirm redemption');
      expect(find.text('Redemption requested'), findsOneWidget);
      final payout = repository.redeemed!.payout!;
      expect(payout.account!.id, 'CASA1');
      expect(payout.branch!.name, 'CITY HEAD OFFICE');
      expect(tester.takeException(), isNull);
    });

    testWidgets('redeem: a partial must be less than the full amount',
        (tester) async {
      await _pump(
        tester,
        TdRedeemScreen(args: TdActionArgs(deposit: _deposit())),
        repository: _FakeRepository(),
        height: 1800,
      );
      await _tapText(tester, 'Partial');
      await tester.enterText(find.byType(TextField).first, '999999');
      await _tapText(tester, 'Continue');
      expect(
        find.text('A partial redemption must be less than the full amount.'),
        findsOneWidget,
      );
    });

    testWidgets('maturity: renew principal and interest needs no payout',
        (tester) async {
      final repository = _FakeRepository();
      await _pump(
        tester,
        TdMaturityEditScreen(args: TdActionArgs(deposit: _deposit())),
        repository: repository,
        height: 1800,
      );
      // The current instruction is marked.
      expect(find.text('Current'), findsOneWidget);
      await _tapText(tester, 'Renew Principal and Interest');
      expect(find.text('My account'), findsNothing);
      await _tapText(tester, 'Continue');
      await _tapText(tester, 'Confirm changes');
      expect(find.text('Maturity instructions updated'), findsOneWidget);
      expect(repository.updated!.rollOverType, 'I');
      expect(repository.updated!.toJson().containsKey('payoutInstructions'),
          isFalse);
    });

    testWidgets('maturity: a special amount asks for the amount and payout',
        (tester) async {
      await _pump(
        tester,
        TdMaturityEditScreen(args: TdActionArgs(deposit: _deposit())),
        repository: _FakeRepository(),
        width: 390,
        height: 1800,
      );
      await _tapText(
        tester,
        'Renew Special Amount and Pay Out the Remaining Amount',
      );
      expect(find.text('Roll-over amount'), findsOneWidget);
      expect(find.text('Pay the remaining amount to'), findsOneWidget);
      await _tapText(tester, 'Continue');
      expect(find.text('Enter an amount.'), findsOneWidget);
      expect(find.text('Choose where the money goes.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('open: the capture had no products — say so', (tester) async {
      await _pump(
        tester,
        const TdOpenScreen(),
        repository: _FakeRepository(),
        width: 390,
      );
      expect(
        find.textContaining('No deposit products are available'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('open: limits and tenure are checked', (tester) async {
      await _pump(
        tester,
        const TdOpenScreen(),
        repository: _FakeRepository(products: [
          TdProduct.fromJson({
            'productId': 'TD01',
            'name': 'Fixed Deposit',
            'amountParameters': [
              {
                'currency': 'GBP',
                'minAmount': {'amount': 1000},
                'maxAmount': {'amount': 500000},
              },
            ],
            'tenureParameter': {
              'minTenure': {'months': 1},
              'maxTenure': {'years': 5},
            },
          }),
        ]),
        height: 2000,
      );
      await _tapText(tester, 'Select a product');
      await _tapText(tester, 'Fixed Deposit');
      await _tapText(tester, 'Select an account');
      await _tapText(tester, 'xxxxxxxxxxxx8014');
      await tester.enterText(find.byType(TextField).first, '10');
      await _tapText(tester, 'Continue');
      expect(find.textContaining('The minimum amount is'), findsOneWidget);
      expect(find.text('Enter the deposit term.'), findsOneWidget);
    });
  });
}
