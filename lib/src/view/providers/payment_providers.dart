import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/core/models/payee/payee_models.dart';
import 'package:ubci_bank/src/core/models/payment/payment_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/repository_providers.dart';

/// Existing (same-bank) payees mapped into [TransferBeneficiary] for the
/// Internal Payment beneficiary step. Per the functional flow doc (§4.2):
/// "For the first implementation, start with existing beneficiaries" — Add
/// Beneficiary is Phase 2, already covered by the Payees screen.
final internalBeneficiariesProvider =
    FutureProvider.autoDispose<List<TransferBeneficiary>>((ref) async {
  final result = await ref.read(payeeRepositoryProvider).fetchPayees();
  if (result is Success<List<PayeeSummary>>) {
    final payees = result.data ?? const [];
    return payees.map(TransferBeneficiary.fromPayeeSummary).toList();
  }
  throw Exception('Unable to load beneficiaries.');
});

final internationalBeneficiariesProvider =
    FutureProvider.autoDispose<List<TransferBeneficiary>>((ref) async {
  return ref.read(paymentRepositoryProvider).fetchInternationalBeneficiaries();
});

final paymentCountriesProvider =
    FutureProvider.autoDispose<List<PaymentCountry>>((ref) async {
  return ref.read(paymentRepositoryProvider).fetchCountries();
});

final paymentCurrenciesProvider =
    FutureProvider.autoDispose<List<PaymentCurrency>>((ref) async {
  return ref.read(paymentRepositoryProvider).fetchCurrencies();
});

final paymentPurposesProvider =
    FutureProvider.autoDispose<List<PaymentPurpose>>((ref) async {
  return ref.read(paymentRepositoryProvider).fetchPurposes();
});

/// Key for [internationalQuoteProvider] — refetches whenever the source
/// currency, target currency, or amount changes.
class InternationalQuoteKey {
  const InternationalQuoteKey({
    required this.sourceCurrency,
    required this.targetCurrency,
    required this.amount,
  });

  final String sourceCurrency;
  final String targetCurrency;
  final double amount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InternationalQuoteKey &&
          other.sourceCurrency == sourceCurrency &&
          other.targetCurrency == targetCurrency &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(sourceCurrency, targetCurrency, amount);
}

/// Combined exchange-rate + charges quote for the International Payment
/// amount step (functional flow doc §13–§14).
class InternationalQuote {
  const InternationalQuote({required this.rate, required this.charges});

  final ExchangeRateQuote rate;
  final PaymentCharges charges;
}

final internationalQuoteProvider = FutureProvider.autoDispose
    .family<InternationalQuote, InternationalQuoteKey>((ref, key) async {
  final repo = ref.read(paymentRepositoryProvider);
  final rate = await repo.fetchExchangeRate(
    sourceCurrency: key.sourceCurrency,
    targetCurrency: key.targetCurrency,
    amount: key.amount,
  );
  final charges = await repo.calculateCharges(
    amount: key.amount,
    currency: key.sourceCurrency,
    isInternational: true,
  );
  return InternationalQuote(rate: rate, charges: charges);
});

/// Submission state shared shape for both Internal and International
/// payments — mirrors [LoanRepaymentSubmissionState]'s OTP step-up
/// handling so both flows can reuse the same OTP bottom-sheet pattern.
class PaymentSubmissionState {
  const PaymentSubmissionState({
    this.isSubmitting = false,
    this.result,
    this.errorMessage,
    this.otpChallenge,
    this.otpError,
  });

  final bool isSubmitting;
  final PaymentResult? result;
  final String? errorMessage;
  final PaymentOtpChallenge? otpChallenge;
  final String? otpError;
}

class InternalPaymentSubmissionNotifier
    extends StateNotifier<PaymentSubmissionState> {
  InternalPaymentSubmissionNotifier(this._ref)
      : super(const PaymentSubmissionState());

  final Ref _ref;
  InternalPaymentRequest? _request;

  Future<void> submit(InternalPaymentRequest request) async {
    _request = request;
    state = const PaymentSubmissionState(isSubmitting: true);
    await _attempt();
  }

  Future<void> verifyOtp(String otp) async {
    final challenge = state.otpChallenge;
    if (challenge == null) return;
    state = PaymentSubmissionState(isSubmitting: true, otpChallenge: challenge);
    await _attempt(otp: otp, challenge: challenge);
  }

  Future<void> _attempt({String? otp, PaymentOtpChallenge? challenge}) async {
    final request = _request;
    if (request == null) return;

    final outcome = await _ref
        .read(paymentRepositoryProvider)
        .submitInternalPayment(request, otp: otp, challenge: challenge);

    if (outcome is PaymentCompleted) {
      state = PaymentSubmissionState(result: outcome.result);
      return;
    }
    if (outcome is PaymentAwaitingOtp) {
      state = PaymentSubmissionState(
        otpChallenge: outcome.challenge,
        otpError: otp != null ? 'Incorrect code. Please try again.' : null,
      );
    }
  }

  void reset() {
    _request = null;
    state = const PaymentSubmissionState();
  }
}

final internalPaymentSubmissionProvider = StateNotifierProvider.autoDispose<
    InternalPaymentSubmissionNotifier, PaymentSubmissionState>(
  (ref) => InternalPaymentSubmissionNotifier(ref),
);

class InternationalPaymentSubmissionNotifier
    extends StateNotifier<PaymentSubmissionState> {
  InternationalPaymentSubmissionNotifier(this._ref)
      : super(const PaymentSubmissionState());

  final Ref _ref;
  InternationalPaymentRequest? _request;

  Future<void> submit(InternationalPaymentRequest request) async {
    _request = request;
    state = const PaymentSubmissionState(isSubmitting: true);
    await _attempt();
  }

  Future<void> verifyOtp(String otp) async {
    final challenge = state.otpChallenge;
    if (challenge == null) return;
    state = PaymentSubmissionState(isSubmitting: true, otpChallenge: challenge);
    await _attempt(otp: otp, challenge: challenge);
  }

  Future<void> _attempt({String? otp, PaymentOtpChallenge? challenge}) async {
    final request = _request;
    if (request == null) return;

    final outcome = await _ref
        .read(paymentRepositoryProvider)
        .submitInternationalPayment(request, otp: otp, challenge: challenge);

    if (outcome is PaymentCompleted) {
      state = PaymentSubmissionState(result: outcome.result);
      return;
    }
    if (outcome is PaymentAwaitingOtp) {
      state = PaymentSubmissionState(
        otpChallenge: outcome.challenge,
        otpError: otp != null ? 'Incorrect code. Please try again.' : null,
      );
    }
  }

  void reset() {
    _request = null;
    state = const PaymentSubmissionState();
  }
}

final internationalPaymentSubmissionProvider = StateNotifierProvider
    .autoDispose<InternationalPaymentSubmissionNotifier,
        PaymentSubmissionState>(
  (ref) => InternationalPaymentSubmissionNotifier(ref),
);
