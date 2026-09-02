import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/payee/payee_models.dart';

/// The two payment journeys covered by this module (see
/// "Internal & International Payments — Functional Flow Document",
/// section 1: Select Payment Type → Source Account → Beneficiary →
/// Payment Details → Review → Authentication → Submit → Confirmation).
enum TransferType { internal, international }

/// A beneficiary the customer can pay — either an existing internal
/// (same-bank) payee, or an international beneficiary with bank/country
/// details attached.
///
/// Internal beneficiaries are backed by the real [PayeeSummary] list
/// (`payeeRepositoryProvider.fetchPayees()`); international beneficiaries
/// come from [PaymentRepository], which — per the functional-flow doc's
/// note that "the supplied documentation does not provide the complete
/// International Payment field-level flow" — is currently a local mock.
class TransferBeneficiary {
  const TransferBeneficiary({
    required this.id,
    required this.nickname,
    required this.isInternational,
    this.accountNumber,
    this.bankName,
    this.bankCountry,
    this.swiftCode,
    this.iban,
    this.currencyCode,
  });

  final String id;
  final String nickname;
  final bool isInternational;
  final String? accountNumber;
  final String? bankName;
  final String? bankCountry;
  final String? swiftCode;
  final String? iban;
  final String? currencyCode;

  String get maskedAccountNumber {
    final digits = (accountNumber ?? '').replaceAll(RegExp(r'\s+'), '');
    if (digits.length <= 4) return digits;
    return '••••${digits.substring(digits.length - 4)}';
  }

  factory TransferBeneficiary.fromPayeeSummary(PayeeSummary payee) {
    return TransferBeneficiary(
      id: payee.accountNumber ?? payee.nickname,
      nickname: payee.nickname,
      isInternational: false,
      accountNumber: payee.accountNumber,
      bankName: payee.accountDetails,
    );
  }
}

/// A destination country for an international payment.
class PaymentCountry {
  const PaymentCountry({
    required this.code,
    required this.name,
    required this.defaultCurrencyCode,
  });

  final String code;
  final String name;
  final String defaultCurrencyCode;
}

/// A settlement currency offered for an international payment.
class PaymentCurrency {
  const PaymentCurrency({
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String code;
  final String name;
  final String symbol;
}

/// A payment-purpose code, required by many correspondent-banking
/// regulators for cross-border transfers (functional flow doc, §15).
class PaymentPurpose {
  const PaymentPurpose({required this.code, required this.description});

  final String code;
  final String description;
}

/// Live exchange-rate quote used to convert the entered send amount into
/// the beneficiary's settlement currency (functional flow doc, §13).
class ExchangeRateQuote {
  const ExchangeRateQuote({
    required this.sourceCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.convertedAmount,
  });

  final String sourceCurrency;
  final String targetCurrency;
  final double rate;
  final double convertedAmount;
}

/// Fee breakdown for a payment (functional flow doc, §14).
class PaymentCharges {
  const PaymentCharges({
    required this.amount,
    required this.currency,
    this.description = 'Bank charges',
  });

  final double amount;
  final String currency;
  final String description;
}

/// Outbound request for an internal (same-bank) transfer.
class InternalPaymentRequest {
  const InternalPaymentRequest({
    required this.sourceAccount,
    required this.beneficiary,
    required this.amount,
    required this.currency,
    this.remarks,
  });

  final CasaAccount sourceAccount;
  final TransferBeneficiary beneficiary;
  final double amount;
  final String currency;
  final String? remarks;
}

/// Outbound request for an international (cross-border) transfer.
class InternationalPaymentRequest {
  const InternationalPaymentRequest({
    required this.sourceAccount,
    required this.beneficiary,
    required this.destinationCountry,
    required this.currency,
    required this.amount,
    required this.exchangeRate,
    required this.charges,
    this.purpose,
    this.additionalInformation,
  });

  final CasaAccount sourceAccount;
  final TransferBeneficiary beneficiary;
  final PaymentCountry destinationCountry;
  final PaymentCurrency currency;
  final double amount;
  final ExchangeRateQuote exchangeRate;
  final PaymentCharges charges;
  final PaymentPurpose? purpose;
  final String? additionalInformation;

  double get totalDebit => amount + charges.amount;
}

/// Final state of a submitted payment. International payments may come
/// back `processing` rather than an immediate success/failure — the
/// functional flow doc (§18) explicitly warns against forcing every
/// international transaction into an instant "Success" state.
enum PaymentStatus { success, processing, failed }

class PaymentResult {
  const PaymentResult({
    required this.referenceKey,
    required this.status,
    required this.amount,
    required this.currency,
    required this.beneficiaryName,
    required this.date,
    this.destinationCountry,
  });

  final String referenceKey;
  final PaymentStatus status;
  final double amount;
  final String currency;
  final String beneficiaryName;
  final DateTime date;
  final String? destinationCountry;
}

/// A step-up authentication (OTP) challenge — mirrors
/// [LoanRepaymentChallenge] so the payment flows can reuse the same OTP
/// bottom-sheet interaction pattern already established for loan
/// repayment. The functional flow doc (§7, §17) is explicit that not
/// every payment will require OTP — this is only populated when the
/// backend actually challenges the submission.
class PaymentOtpChallenge {
  const PaymentOtpChallenge({
    required this.referenceNo,
    this.attemptsLeft,
    this.resendsLeft,
  });

  final String referenceNo;
  final int? attemptsLeft;
  final int? resendsLeft;
}

/// Outcome of a single payment-submission attempt.
sealed class PaymentOutcome {
  const PaymentOutcome();
}

class PaymentCompleted extends PaymentOutcome {
  const PaymentCompleted(this.result);

  final PaymentResult result;
}

class PaymentAwaitingOtp extends PaymentOutcome {
  const PaymentAwaitingOtp(this.challenge);

  final PaymentOtpChallenge challenge;
}
