import 'dart:math';

import 'package:ubci_bank/src/core/models/payment/payment_models.dart';

/// **MOCK REPOSITORY.**
///
/// The functional-flow doc this module is built from is explicit that it
/// does not define the field-level Internal/International Payment APIs
/// ("The exact fields should be taken from the actual OBDX API/UI used by
/// your project" — §5, §11, §12.3, §13, §14, §15). There is no
/// `obdx_payment_api.dart` / payment endpoint in this codebase yet, so
/// this repository stands in for one: every method resolves locally after
/// a short simulated delay instead of calling the network.
///
/// The UI (screens, providers, submission state machine, OTP step-up) is
/// fully wired against this repository's interface. To go live, replace
/// the bodies below with real calls through an `ObdxPaymentApi` (same
/// `ObdxApiBase` / `ResponseHandler` pattern as [PayeeRepository] and
/// [LoanRepository]) — the rest of the flow should not need to change.
class PaymentRepository {
  PaymentRepository();

  final _random = Random();

  static const _simulatedLatency = Duration(milliseconds: 600);

  /// OTP that always succeeds against the mock OTP challenge below, so the
  /// flow is testable end-to-end without a real auth backend.
  static const String mockValidOtp = '123456';

  Future<List<TransferBeneficiary>> fetchInternationalBeneficiaries() async {
    await Future.delayed(_simulatedLatency);
    return const [
      TransferBeneficiary(
        id: 'intl-ben-1',
        nickname: 'Michael Chen',
        isInternational: true,
        accountNumber: 'GB29NWBK60161331926819',
        bankName: 'NatWest Bank',
        bankCountry: 'United Kingdom',
        swiftCode: 'NWBKGB2L',
        iban: 'GB29NWBK60161331926819',
        currencyCode: 'GBP',
      ),
      TransferBeneficiary(
        id: 'intl-ben-2',
        nickname: 'Fatima Al Mansoori',
        isInternational: true,
        accountNumber: 'AE070331234567890123456',
        bankName: 'Emirates NBD',
        bankCountry: 'United Arab Emirates',
        swiftCode: 'EBILAEAD',
        iban: 'AE070331234567890123456',
        currencyCode: 'AED',
      ),
      TransferBeneficiary(
        id: 'intl-ben-3',
        nickname: 'Priya Nair',
        isInternational: true,
        accountNumber: '000123456789',
        bankName: 'HDFC Bank',
        bankCountry: 'India',
        swiftCode: 'HDFCINBB',
        currencyCode: 'INR',
      ),
    ];
  }

  Future<List<PaymentCountry>> fetchCountries() async {
    await Future.delayed(_simulatedLatency);
    return const [
      PaymentCountry(code: 'US', name: 'United States', defaultCurrencyCode: 'USD'),
      PaymentCountry(code: 'GB', name: 'United Kingdom', defaultCurrencyCode: 'GBP'),
      PaymentCountry(code: 'AE', name: 'United Arab Emirates', defaultCurrencyCode: 'AED'),
      PaymentCountry(code: 'IN', name: 'India', defaultCurrencyCode: 'INR'),
      PaymentCountry(code: 'EU', name: 'Eurozone', defaultCurrencyCode: 'EUR'),
      PaymentCountry(code: 'SG', name: 'Singapore', defaultCurrencyCode: 'SGD'),
    ];
  }

  Future<List<PaymentCurrency>> fetchCurrencies() async {
    await Future.delayed(_simulatedLatency);
    return const [
      PaymentCurrency(code: 'USD', name: 'US Dollar', symbol: r'$'),
      PaymentCurrency(code: 'GBP', name: 'British Pound', symbol: '£'),
      PaymentCurrency(code: 'EUR', name: 'Euro', symbol: '€'),
      PaymentCurrency(code: 'AED', name: 'UAE Dirham', symbol: 'AED'),
      PaymentCurrency(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
      PaymentCurrency(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$'),
    ];
  }

  Future<List<PaymentPurpose>> fetchPurposes() async {
    await Future.delayed(_simulatedLatency);
    return const [
      PaymentPurpose(code: 'FAM', description: 'Family maintenance'),
      PaymentPurpose(code: 'EDU', description: 'Education fees'),
      PaymentPurpose(code: 'GDS', description: 'Payment for goods'),
      PaymentPurpose(code: 'SRV', description: 'Payment for services'),
      PaymentPurpose(code: 'INV', description: 'Investment'),
      PaymentPurpose(code: 'OTH', description: 'Other'),
    ];
  }

  /// Illustrative fixed rate table against INR — a real integration would
  /// call the OBDX Forex Calculator endpoint the doc references (§11, §13).
  static const Map<String, double> _ratesToInr = {
    'USD': 88.10,
    'GBP': 111.40,
    'EUR': 96.30,
    'AED': 23.99,
    'INR': 1.0,
    'SGD': 65.20,
  };

  Future<ExchangeRateQuote> fetchExchangeRate({
    required String sourceCurrency,
    required String targetCurrency,
    required double amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final sourceToInr = _ratesToInr[sourceCurrency] ?? 1.0;
    final targetToInr = _ratesToInr[targetCurrency] ?? 1.0;
    final rate = sourceToInr / targetToInr;
    return ExchangeRateQuote(
      sourceCurrency: sourceCurrency,
      targetCurrency: targetCurrency,
      rate: rate,
      convertedAmount: amount * rate,
    );
  }

  Future<PaymentCharges> calculateCharges({
    required double amount,
    required String currency,
    required bool isInternational,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!isInternational) {
      // Internal (same-bank) transfers are typically fee-free.
      return PaymentCharges(amount: 0, currency: currency);
    }
    final flat = 25.0;
    final percentageFee = amount * 0.001; // 0.1%
    return PaymentCharges(
      amount: double.parse((flat + percentageFee).toStringAsFixed(2)),
      currency: currency,
    );
  }

  Future<PaymentOutcome> submitInternalPayment(
    InternalPaymentRequest request, {
    String? otp,
    PaymentOtpChallenge? challenge,
  }) async {
    await Future.delayed(_simulatedLatency);
    return _resolveSubmission(
      isInternational: false,
      amount: request.amount,
      currency: request.currency,
      beneficiaryName: request.beneficiary.nickname,
      destinationCountry: null,
      otp: otp,
      challenge: challenge,
    );
  }

  Future<PaymentOutcome> submitInternationalPayment(
    InternationalPaymentRequest request, {
    String? otp,
    PaymentOtpChallenge? challenge,
  }) async {
    await Future.delayed(_simulatedLatency);
    return _resolveSubmission(
      isInternational: true,
      amount: request.totalDebit,
      currency: request.currency.code,
      beneficiaryName: request.beneficiary.nickname,
      destinationCountry: request.destinationCountry.name,
      otp: otp,
      challenge: challenge,
    );
  }

  /// Shared mock submission logic for both flows: the first attempt (no
  /// [otp]) always comes back as an OTP challenge — mirroring OBDX's
  /// `417 Expectation Failed` step-up pattern already used by loan
  /// repayment — so the flow is always exercised end-to-end. Entering
  /// [mockValidOtp] completes the payment; anything else returns a fresh
  /// challenge with a decremented attempt count.
  PaymentOutcome _resolveSubmission({
    required bool isInternational,
    required double amount,
    required String currency,
    required String beneficiaryName,
    required String? destinationCountry,
    String? otp,
    PaymentOtpChallenge? challenge,
  }) {
    if (otp == null) {
      return const PaymentAwaitingOtp(
        PaymentOtpChallenge(
          referenceNo: 'MOCKOTP',
          attemptsLeft: 3,
          resendsLeft: 2,
        ),
      );
    }

    if (otp != mockValidOtp) {
      final attemptsLeft = ((challenge?.attemptsLeft ?? 1) - 1).clamp(0, 99);
      return PaymentAwaitingOtp(
        PaymentOtpChallenge(
          referenceNo: challenge?.referenceNo ?? 'MOCKOTP',
          attemptsLeft: attemptsLeft,
          resendsLeft: challenge?.resendsLeft,
        ),
      );
    }

    final status = isInternational && amount > 5000
        ? PaymentStatus.processing
        : PaymentStatus.success;

    return PaymentCompleted(
      PaymentResult(
        referenceKey: _generateReference(),
        status: status,
        amount: amount,
        currency: currency,
        beneficiaryName: beneficiaryName,
        date: DateTime.now(),
        destinationCountry: destinationCountry,
      ),
    );
  }

  String _generateReference() {
    final digits = List.generate(10, (_) => _random.nextInt(10)).join();
    return 'TXN$digits';
  }
}
