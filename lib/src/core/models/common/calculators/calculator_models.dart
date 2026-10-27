import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/obdx_otp_outcome.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Calculators (OBDX `components/widgets/calculators`). Every request and
/// field is from docs/obdx/features/calculators.md; hooks.js lines inline.

/// Which calculator a `defaultRange` call is for (`for=` query value).
enum CalcKind {
  loanInstallment('LOANCALCULATOR', ['INTERESTRATE', 'NOOFINSTALLMENTS', 'PRINCIPALAMOUNT', 'TENURE']),
  loanEligibility('LOANELIGIBILITYCALCULATOR', ['GROSSMONTHLYINCOME', 'INTERESTRATE', 'MONTHLYEXPENSES', 'TENURE']);

  const CalcKind(this.code, this.variables);

  final String code;

  /// The `var=` values OBDX asks for (loan-calculator/hooks.js:110-115,
  /// loan-eligibility-calculator/hooks.js:123-128).
  final List<String> variables;
}

/// One slider's range: `{minimumRange, maximumRange, defaultValue}`.
/// Interest values are percentages (OBDX divides them by 100 for its
/// slider, then multiplies back for the request).
class CalcRange {
  const CalcRange({required this.min, required this.max, required this.defaultValue});

  final double min;
  final double max;
  final double defaultValue;

  /// [value] kept inside the range.
  double clamp(double value) => value < min ? min : (value > max ? max : value);

  factory CalcRange.fromPayload(Map<String, dynamic> body) {
    final min = _num(body['minimumRange']) ?? 0;
    final max = _num(body['maximumRange']) ?? min;
    return CalcRange(
      min: min,
      max: max < min ? min : max,
      defaultValue: (_num(body['defaultValue']) ?? min).clamp(min, max < min ? min : max).toDouble(),
    );
  }
}

// ── Request bodies (the OBDX payload templates, nulls included) ──

Map<String, dynamic> _money(String currency, num? amount) => {'currency': currency, 'amount': amount};

/// Term Deposit: `POST td tdcalculators/deposit/maturity`
/// (td-calculator-widget/hooks.js:181-188). [interestPercent] is the rate
/// in percent, as OBDX sends it (field × 100).
Map<String, dynamic> tdMaturityBody({
  required String currency,
  required double amount,
  required int years,
  required int months,
  required int days,
  required double interestPercent,
}) =>
    {
      'initialDepositAmount': _money(currency, amount),
      'interestRate': interestPercent,
      'tenure': {'year': years, 'month': months, 'day': days, 'date': null},
    };

/// Loan Installment: `POST loan loancalculators/mortgage/schedule`
/// (loan-calculator/hooks.js:169-174).
Map<String, dynamic> loanScheduleBody({
  required String currency,
  required double principal,
  required int years,
  required double interestPercent,
}) =>
    {
      'principalAmount': _money(currency, principal),
      'interestRate': interestPercent,
      'loanDisbursementDate': null,
      'noOfInstallments': null,
      'firstDueDate': null,
      'tenure': {'year': years, 'month': null, 'day': null, 'date': null},
    };

/// Loan Eligibility: `POST loan loancalculators/loanEligibility`
/// (loan-eligibility-calculator/hooks.js:207-214).
Map<String, dynamic> loanEligibilityBody({
  required String currency,
  required double monthlyIncome,
  required double monthlyExpenses,
  required int years,
  required double interestPercent,
}) =>
    {
      'grossMonthlyIncomeAmount': _money(currency, monthlyIncome),
      'monthlyExpenseAmount': _money(currency, monthlyExpenses),
      'tenure': {'year': years, 'month': null, 'day': null, 'date': null},
      'interestRate': interestPercent,
    };

/// OBDX skips the call when income ≤ expenses and shows its message
/// (loan-eligibility-calculator/hooks.js:216-218).
bool eligibilityInputsValid(double monthlyIncome, double monthlyExpenses) => monthlyIncome > monthlyExpenses;

/// Forex: `POST forexdeal calculators/foreignExchange`: buy [from] (the
/// amount typed), sell [to] (forex-calculator/hooks.js:290-299).
Map<String, dynamic> forexBody({required String from, required String to, required double amount}) => {
      'sellCurrency': {'currency': to, 'amount': null},
      'buyCurrency': {'currency': from, 'amount': amount},
    };

// ── Results ──

/// `maturityAmount` (retail shows it as Maturity Amount); the corporate
/// layout also shows `totalInterestEarned`.
class TdMaturity {
  const TdMaturity({required this.maturityAmount, this.interestEarned});

  final MoneyAmount maturityAmount;
  final MoneyAmount? interestEarned;

  factory TdMaturity.fromPayload(Map<String, dynamic> body) => TdMaturity(
        maturityAmount: MoneyAmount.fromJson(body['maturityAmount']),
        interestEarned: body['totalInterestEarned'] == null ? null : MoneyAmount.fromJson(body['totalInterestEarned']),
      );
}

/// `loanScheduleDetails[0].installmentAmount` (null when the list is empty).
class LoanInstallment {
  const LoanInstallment({this.installment});

  final MoneyAmount? installment;

  factory LoanInstallment.fromPayload(Map<String, dynamic> body) {
    final details = body['loanScheduleDetails'];
    final first = details is List && details.isNotEmpty ? ObdxApiUtils.asMap(details.first) : const <String, dynamic>{};
    return LoanInstallment(
      installment: first['installmentAmount'] == null ? null : MoneyAmount.fromJson(first['installmentAmount']),
    );
  }
}

/// Eligible Amount (`amount`) and Average Installment
/// (`monthlyInstallmentAmount`).
class LoanEligibility {
  const LoanEligibility({required this.eligibleAmount, this.monthlyInstallment});

  final MoneyAmount eligibleAmount;
  final MoneyAmount? monthlyInstallment;

  factory LoanEligibility.fromPayload(Map<String, dynamic> body) => LoanEligibility(
        eligibleAmount: MoneyAmount.fromJson(body['amount']),
        monthlyInstallment:
            body['monthlyInstallmentAmount'] == null ? null : MoneyAmount.fromJson(body['monthlyInstallmentAmount']),
      );
}

/// `sellingCurrency.amount` (the converted amount, in To) and
/// `midRateAmount` (1 From = rate To).
class ForexQuote {
  const ForexQuote({required this.converted, required this.rate});

  final double converted;
  final double rate;

  /// 1 To = 1/rate From.
  double get reverseRate => rate == 0 ? 0 : 1 / rate;

  factory ForexQuote.fromPayload(Map<String, dynamic> body) => ForexQuote(
        converted: _num(ObdxApiUtils.asMap(body['sellingCurrency'])['amount']) ?? 0,
        rate: _num(body['midRateAmount']) ?? 0,
      );
}

/// `forex/currencyPairs` → `exchangeRateCurrency[]{ccy1, ccy2[]}`. Each pair
/// works both ways round; grouped by From in first-seen order
/// (forex-calculator/hooks.js:235-273).
class ForexPairs {
  const ForexPairs(this.byFrom);

  /// From currency → the To currencies it pairs with.
  final Map<String, List<String>> byFrom;

  List<String> get fromCurrencies => byFrom.keys.toList();
  List<String> toFor(String from) => byFrom[from] ?? const [];

  factory ForexPairs.fromPayload(Map<String, dynamic> body) {
    final map = <String, List<String>>{};
    void add(String from, String to) {
      final list = map.putIfAbsent(from, () => []);
      if (!list.contains(to)) list.add(to);
    }

    final items = body['exchangeRateCurrency'];
    for (final raw in items is List ? items : const []) {
      final item = ObdxApiUtils.asMap(raw);
      final c1 = item['ccy1']?.toString();
      final c2s = item['ccy2'];
      if (c1 == null || c2s is! List) continue;
      for (final c2 in c2s) {
        add(c1, c2.toString());
        add(c2.toString(), c1);
      }
    }
    return ForexPairs(map);
  }
}

/// `bankConfigurationDTO.localCurrency`: the currency of the TD and loan
/// calculators (td-calculator-widget/hooks.js:137-148).
String? localCurrencyFromPayload(Map<String, dynamic> body) {
  final dto = ObdxApiUtils.asMap(body['bankConfigurationDTO'] ?? body['bankConfiguration']);
  final ccy = dto['localCurrency']?.toString().trim();
  return ccy == null || ccy.isEmpty ? null : ccy;
}

/// A calculation's result, possibly pending approval, or an OTP to enter
/// first (417). The calculators are POSTs, so they get the same handling as
/// every write (user decision 3a, 2026-10-26).
class CalcOutcome<T> implements ObdxOtpOutcome {
  const CalcOutcome.done(T this.result, {this.pendingApproval = false})
      : challenge = null,
        invalidOtp = false;

  const CalcOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : result = null,
        pendingApproval = false;

  final T? result;
  final bool pendingApproval;
  @override
  final ObdxChallenge? challenge;
  @override
  final bool invalidOtp;
}

double? _num(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString().replaceAll(',', '') ?? '');
