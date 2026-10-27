import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/calculators/calculator_models.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_calculators_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/calculators_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/calculators/calculator_screens.dart';

// Field names follow OBDX components/widgets/calculators
// (docs/obdx/features/calculators.md); values are made up.

Map<String, dynamic> _wrap(Map<String, dynamic> body, {int status = 200, Map<String, dynamic> headers = const {}}) =>
    {'statusCode': status, 'headers': headers, 'rawBody': '', 'body': body};

void main() {
  group('model', () {
    test('TD body: percent rate, full tenure, date left null (hooks.js:181-188)', () {
      expect(
        tdMaturityBody(currency: 'GBP', amount: 1000, years: 1, months: 6, days: 0, interestPercent: 7.25),
        {
          'initialDepositAmount': {'currency': 'GBP', 'amount': 1000.0},
          'interestRate': 7.25,
          'tenure': {'year': 1, 'month': 6, 'day': 0, 'date': null},
        },
      );
    });

    test('loan bodies keep OBDX nulls; forex buys From and sells To', () {
      final loan = loanScheduleBody(currency: 'GBP', principal: 250000, years: 15, interestPercent: 7.5);
      expect(loan['noOfInstallments'], isNull);
      expect(loan['tenure'], {'year': 15, 'month': null, 'day': null, 'date': null});
      final elig = loanEligibilityBody(currency: 'GBP', monthlyIncome: 5000, monthlyExpenses: 1000, years: 10, interestPercent: 8);
      expect(elig['grossMonthlyIncomeAmount'], {'currency': 'GBP', 'amount': 5000.0});
      expect(forexBody(from: 'USD', to: 'GBP', amount: 1), {
        'sellCurrency': {'currency': 'GBP', 'amount': null},
        'buyCurrency': {'currency': 'USD', 'amount': 1.0},
      });
      expect(eligibilityInputsValid(1000, 1000), isFalse, reason: 'OBDX: income must exceed expenses');
    });

    test('ranges parse strings and keep the default inside', () {
      final r = CalcRange.fromPayload({'minimumRange': '1', 'maximumRange': '30', 'defaultValue': '45'});
      expect([r.min, r.max, r.defaultValue], [1, 30, 30]);
      expect(r.clamp(0), 1);
    });

    test('forex pairs work both ways round, grouped by From', () {
      final p = ForexPairs.fromPayload({
        'exchangeRateCurrency': [
          {
            'ccy1': 'USD',
            'ccy2': ['GBP', 'EUR'],
          },
          {
            'ccy1': 'GBP',
            'ccy2': ['USD'],
          },
        ],
      });
      expect(p.fromCurrencies, ['USD', 'GBP', 'EUR']);
      expect(p.toFor('GBP'), ['USD'], reason: 'the duplicate pair appears once');
      expect(p.toFor('EUR'), ['USD']);
    });

    test('results and local currency', () {
      expect(LoanInstallment.fromPayload({'loanScheduleDetails': []}).installment, isNull);
      final q = ForexQuote.fromPayload({
        'sellingCurrency': {'amount': 0.79},
        'midRateAmount': 0.79,
      });
      expect(q.converted, 0.79);
      expect(q.reverseRate, closeTo(1.2658, 0.0001));
      expect(
        localCurrencyFromPayload({
          'bankConfigurationDTO': {'localCurrency': 'GBP'},
        }),
        'GBP',
      );
    });
  });

  group('repository', () {
    test('ranges: one defaultRange call per OBDX variable', () async {
      final api = _FakeApi();
      final r = await CalculatorsRepository(api: api).fetchRanges(CalcKind.loanInstallment);
      expect((r as Success<Map<String, CalcRange>>).data!.keys, CalcKind.loanInstallment.variables);
      expect(api.rangeCalls, [for (final v in CalcKind.loanInstallment.variables) 'LOANCALCULATOR/$v']);
    });

    test('a calculation answered 417 asks for the OTP; 202 is pending with its result', () async {
      final api = _FakeApi()..status = 417;
      final repo = CalculatorsRepository(api: api);
      final first = await repo.tdMaturity(const {});
      expect((first as Success<CalcOutcome<TdMaturity>>).data!.challenge, isNotNull);
      api.status = 202;
      final second = await repo.tdMaturity(const {}, challenge: first.data!.challenge, otp: '1234');
      final done = (second as Success<CalcOutcome<TdMaturity>>).data!;
      expect(done.pendingApproval, isTrue);
      expect(done.result!.maturityAmount.amount, 1072.5);
    });
  });

  Future<_FakeRepo> pump(WidgetTester tester, Widget screen, {double width = 390, _FakeRepo? repo}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = repo ?? _FakeRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [calculatorsRepositoryProvider.overrideWithValue(r)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleConfig.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return r;
  }

  for (final width in [390.0, 1280.0]) {
    final layout = width < 600 ? 'phone' : 'web';

    testWidgets('$layout: Loan Installment calculates at once from the defaults (1b)', (tester) async {
      final repo = await pump(tester, const LoanInstallmentScreen(), width: width);
      expect(repo.loanBodies.length, 1);
      expect(repo.loanBodies.single['principalAmount'], {'currency': 'GBP', 'amount': 250000.0});
      expect(repo.loanBodies.single['interestRate'], 7.5);
      expect(find.text('Calculated monthly installment'), findsOneWidget);
      expect(find.text(MoneyFormat.format(2317.57, currencyCode: 'GBP')), findsOneWidget);
      // Total repayment and interest, from the installment over the tenure.
      expect(find.textContaining('Total repayment', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the tenure box asks again only after the typing pause (2b)', (tester) async {
    final repo = await pump(tester, const LoanInstallmentScreen());
    await tester.enterText(find.byType(TextField).at(1), '20');
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.loanBodies.length, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repo.loanBodies.length, 2);
    expect((repo.loanBodies.last['tenure'] as Map)['year'], 20);
  });

  testWidgets('typing in a box waits for the pause before asking (2b)', (tester) async {
    final repo = await pump(tester, const LoanInstallmentScreen());
    await tester.enterText(find.byType(TextField).first, '300000');
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.loanBodies.length, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repo.loanBodies.length, 2);
    expect((repo.loanBodies.last['principalAmount'] as Map)['amount'], 300000.0);
  });

  testWidgets('typing below the minimum is not overwritten mid-typing; the pause clamps it', (tester) async {
    await pump(tester, const LoanInstallmentScreen());
    final box = find.byType(TextField).first;
    await tester.enterText(box, '3');
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TextField>(box).controller!.text, '3');
    expect(find.text('Between 10000 and 5000000'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(box).controller!.text, '10,000');
  });

  testWidgets('Loan Eligibility: income not above expenses → OBDX message, no call', (tester) async {
    final repo = await pump(tester, const LoanEligibilityScreen(), repo: _FakeRepo(incomeDefault: 1000, expensesDefault: 1000));
    expect(repo.eligibilityBodies, isEmpty);
    expect(find.textContaining('Your monthly expenses seem to be higher'), findsOneWidget);
  });

  testWidgets('Loan Eligibility: disposable income first, then the bank\'s Eligible Amount and installment', (tester) async {
    final repo = await pump(tester, const LoanEligibilityScreen());
    expect(repo.eligibilityBodies.length, 1);
    expect(find.text('Calculated monthly disposable income'), findsOneWidget);
    expect(find.text(MoneyFormat.format(4000, currencyCode: 'GBP')), findsOneWidget);
    expect(find.textContaining(MoneyFormat.format(150000, currencyCode: 'GBP'), findRichText: true), findsOneWidget);
    expect(find.textContaining('${MoneyFormat.format(1800, currencyCode: 'GBP')} / Month', findRichText: true), findsOneWidget);
  });

  testWidgets('TD: needs an interest rate (OBDX message), then asks for the maturity', (tester) async {
    final repo = await pump(tester, const TdCalculatorScreen());
    // Deposit Amount, Years, Months, Days, Interest Rate.
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Please enter valid Interest'), findsOneWidget);
    expect(repo.tdBodies, isEmpty);

    await tester.enterText(find.byType(TextField).at(4), '0.25');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(repo.tdBodies.single['interestRate'], 0.25);
    expect(find.text(MoneyFormat.format(1072.5, currencyCode: 'GBP')), findsOneWidget);
    expect(find.textContaining('0.25%', findRichText: true), findsOneWidget);
  });

  testWidgets('Forex: pick From and To, rate lines shown; a tiny result leaves Amount alone (4b)', (tester) async {
    final repo = await pump(tester, const ForexCalculatorScreen());
    expect(find.text('Please Select Currency'), findsOneWidget);
    await tester.tap(find.text('Foreign Currency').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foreign Currency').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('JPY').last);
    await tester.pumpAndSettle();
    expect(repo.forexBodies.single['buyCurrency'], {'currency': 'USD', 'amount': 1.0});
    expect(find.text('@1 USD = 0.005 JPY'), findsOneWidget);
    expect(find.text('Converted amount'), findsOneWidget);
    final amount = tester.widget<TextField>(find.byType(TextField).first);
    expect(amount.controller!.text, '1', reason: 'OBDX would turn it into 1000');
    expect(repo.forexBodies.length, 1, reason: 'no second call with ×1000');
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('Financial Calculator: the four tabs switch calculators (${width.toInt()})', (tester) async {
      await pump(tester, const FinancialCalculatorScreen(), width: width);
      expect(find.text('Financial Calculator'), findsOneWidget);
      expect(find.text('Term Deposit Calculator'), findsOneWidget);
      for (final (tab, title) in [
        ('Loan Installment', 'Loan Installment Calculator'),
        ('Loan Eligibility', 'Loan Eligibility Calculator'),
        ('Term Deposit', 'Term Deposit Calculator'),
      ]) {
        // On a phone the tab strip scrolls sideways.
        await tester.ensureVisible(find.text(tab).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget, reason: tab);
      }
      await tester.ensureVisible(find.text('Forex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forex'));
      await tester.pumpAndSettle();
      expect(find.text('Converted amount'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _FakeRepo implements CalculatorsRepository {
  _FakeRepo({this.incomeDefault = 5000, this.expensesDefault = 1000});

  final double incomeDefault;
  final double expensesDefault;
  final tdBodies = <Map<String, dynamic>>[];
  final loanBodies = <Map<String, dynamic>>[];
  final eligibilityBodies = <Map<String, dynamic>>[];
  final forexBodies = <Map<String, dynamic>>[];

  @override
  Future<ResponseHandler<String>> fetchLocalCurrency() async => ResponseHandler.success('GBP', code: 200);

  @override
  Future<ResponseHandler<Map<String, CalcRange>>> fetchRanges(CalcKind kind) async => ResponseHandler.success(
        kind == CalcKind.loanInstallment
            ? const {
                'INTERESTRATE': CalcRange(min: 1, max: 20, defaultValue: 7.5),
                'NOOFINSTALLMENTS': CalcRange(min: 1, max: 360, defaultValue: 180),
                'PRINCIPALAMOUNT': CalcRange(min: 10000, max: 5000000, defaultValue: 250000),
                'TENURE': CalcRange(min: 1, max: 30, defaultValue: 15),
              }
            : {
                'GROSSMONTHLYINCOME': CalcRange(min: 1000, max: 100000, defaultValue: incomeDefault),
                'INTERESTRATE': const CalcRange(min: 1, max: 20, defaultValue: 8),
                'MONTHLYEXPENSES': CalcRange(min: 0, max: 100000, defaultValue: expensesDefault),
                'TENURE': const CalcRange(min: 1, max: 30, defaultValue: 10),
              },
        code: 200,
      );

  @override
  Future<ResponseHandler<ForexPairs>> fetchForexPairs() async => ResponseHandler.success(
        ForexPairs.fromPayload({
          'exchangeRateCurrency': [
            {
              'ccy1': 'USD',
              'ccy2': ['JPY', 'GBP'],
            },
          ],
        }),
        code: 200,
      );

  @override
  Future<ResponseHandler<CalcOutcome<TdMaturity>>> tdMaturity(Map<String, dynamic> body, {ObdxChallenge? challenge, String? otp}) async {
    tdBodies.add(body);
    return ResponseHandler.success(
      CalcOutcome.done(TdMaturity(maturityAmount: const MoneyAmount(amount: 1072.5, currency: 'GBP'))),
      code: 200,
    );
  }

  @override
  Future<ResponseHandler<CalcOutcome<LoanInstallment>>> loanInstallment(Map<String, dynamic> body,
      {ObdxChallenge? challenge, String? otp}) async {
    loanBodies.add(body);
    return ResponseHandler.success(
      const CalcOutcome.done(LoanInstallment(installment: MoneyAmount(amount: 2317.57, currency: 'GBP'))),
      code: 200,
    );
  }

  @override
  Future<ResponseHandler<CalcOutcome<LoanEligibility>>> loanEligibility(Map<String, dynamic> body,
      {ObdxChallenge? challenge, String? otp}) async {
    eligibilityBodies.add(body);
    return ResponseHandler.success(
      const CalcOutcome.done(LoanEligibility(
        eligibleAmount: MoneyAmount(amount: 150000, currency: 'GBP'),
        monthlyInstallment: MoneyAmount(amount: 1800, currency: 'GBP'),
      )),
      code: 200,
    );
  }

  @override
  Future<ResponseHandler<CalcOutcome<ForexQuote>>> forex(Map<String, dynamic> body, {ObdxChallenge? challenge, String? otp}) async {
    forexBodies.add(body);
    // Below 0.01: OBDX would multiply the amount by 1000 and ask again.
    return ResponseHandler.success(const CalcOutcome.done(ForexQuote(converted: 0.005, rate: 0.005)), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApi implements ObdxCalculatorsApi {
  int status = 200;
  final rangeCalls = <String>[];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchDefaultRange(String forCalculator, String variable) async {
    rangeCalls.add('$forCalculator/$variable');
    return ResponseHandler.success(_wrap({'minimumRange': 1, 'maximumRange': 10, 'defaultValue': 5}));
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> tdMaturity(Map<String, dynamic> body, {String? challengeResponseHeader}) async =>
      ResponseHandler.success(_wrap(
        {
          'maturityAmount': {'amount': 1072.5, 'currency': 'GBP'},
        },
        status: status,
        headers: status == 417
            ? {
                'X-CHALLENGE': ['{"referenceNo":"CH1","authType":"OTP","attemptsLeft":3}'],
              }
            : const {},
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
