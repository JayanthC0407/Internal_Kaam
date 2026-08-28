import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Outbound body for `POST /digx-common/loan/v1/loan/{id}/repayments`,
/// shaped exactly like the payload captured from the OBDX retail loan
/// repayment screen.
///
/// [typeOfSettlement] defaults to `'P'` (the only value seen in the
/// capture — a partial/principal repayment against the loan's outstanding
/// balance). If your host also exposes full-settlement or scheduled
/// installment codes, pass them explicitly.
class LoanRepaymentRequest {
  const LoanRepaymentRequest({
    required this.amount,
    required this.currency,
    required this.settlementAccountId,
    required this.settlementAccountDisplay,
    this.principalAmount,
    this.principalBalance,
    this.interestAmount = 0,
    this.charges = 0,
    this.installmentArrears = 0,
    this.typeOfSettlement = 'P',
  });

  final double amount;
  final String currency;
  final String settlementAccountId;
  final String settlementAccountDisplay;
  final double? principalAmount;
  final double? principalBalance;
  final double interestAmount;
  final double charges;
  final double installmentArrears;
  final String typeOfSettlement;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> money(double value) => {
          'currency': currency,
          'amount': value,
        };

    return {
      'amount': money(amount),
      'charges': money(charges),
      'installmentArrears': money(installmentArrears),
      'interestAmount': money(interestAmount),
      if (principalAmount != null) 'principalAmount': money(principalAmount!),
      if (principalBalance != null)
        'principalBalance': money(principalBalance!),
      'settlementAccountId': {
        'value': settlementAccountId,
        'displayValue': settlementAccountDisplay,
      },
      'typeOfSettlement': typeOfSettlement,
      'settlementCurrency': currency,
    };
  }
}

/// Result of a submitted repayment, from the `repaymentDetail` object in
/// the `POST .../repayments` response.
class LoanRepaymentResult {
  const LoanRepaymentResult({
    this.referenceKey,
    this.amount,
    this.settlementAccountDisplay,
    this.installmentDue,
  });

  final String? referenceKey;
  final MoneyAmount? amount;
  final String? settlementAccountDisplay;
  final bool? installmentDue;

  factory LoanRepaymentResult.fromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final dto = ObdxApiUtils.asMap(root['repaymentDetail']);
    final settlementId = ObdxApiUtils.asMap(dto['settlementAccountId']);
    return LoanRepaymentResult(
      referenceKey: dto['key']?.toString(),
      amount:
          dto['amount'] != null ? MoneyAmount.fromJson(dto['amount']) : null,
      settlementAccountDisplay: settlementId['displayValue']?.toString(),
      installmentDue: dto['installmentDue'] is bool
          ? dto['installmentDue'] as bool
          : null,
    );
  }
}

/// A step-up authentication (OTP) challenge, parsed from the `X-CHALLENGE`
/// response header OBDX sends with a `417 Expectation Failed` when the
/// repayment task has OTP verification enabled (confirmed against the
/// capture with OTP turned on from the admin module).
class LoanRepaymentChallenge {
  const LoanRepaymentChallenge({
    required this.referenceNo,
    this.authType,
    this.attemptsLeft,
    this.resendsLeft,
    this.scope,
  });

  final String referenceNo;
  final String? authType;
  final int? attemptsLeft;
  final int? resendsLeft;
  final String? scope;

  factory LoanRepaymentChallenge.fromJson(Map<String, dynamic> json) {
    return LoanRepaymentChallenge(
      referenceNo: json['referenceNo']?.toString() ?? '',
      authType: json['authType']?.toString(),
      attemptsLeft: _asInt(json['attemptsLeft']),
      resendsLeft: _asInt(json['resendsLeft']),
      scope: json['scope']?.toString(),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

/// Outcome of a single `POST .../repayments` attempt. Most hosts (OTP
/// disabled) will only ever produce [LoanRepaymentCompleted] directly; when
/// OTP is enabled, the first attempt produces [LoanRepaymentAwaitingOtp]
/// and a second attempt — carrying the entered OTP — produces
/// [LoanRepaymentCompleted] (or another [LoanRepaymentAwaitingOtp] with a
/// fresh challenge if the OTP was wrong).
sealed class LoanRepaymentOutcome {
  const LoanRepaymentOutcome();
}

class LoanRepaymentCompleted extends LoanRepaymentOutcome {
  const LoanRepaymentCompleted(this.result);

  final LoanRepaymentResult result;
}

class LoanRepaymentAwaitingOtp extends LoanRepaymentOutcome {
  const LoanRepaymentAwaitingOtp(this.challenge);

  final LoanRepaymentChallenge challenge;
}
