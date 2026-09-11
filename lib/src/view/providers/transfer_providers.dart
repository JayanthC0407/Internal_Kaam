import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/own_account_transfer.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/transfer_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/network_providers.dart';

final transferRepositoryProvider = Provider(
  (ref) => TransferRepository(
    paymentsApi: ref.watch(obdxPaymentsApiProvider),
    accountsApi: ref.watch(obdxAccountsApiProvider),
  ),
);

class OwnAccountTransferState {
  const OwnAccountTransferState({
    this.step = 0,
    this.debitAccount,
    this.creditAccount,
    this.amountText = '',
    this.transferCurrency,
    this.creditCurrency,
    this.note = '',
    this.transferNow = true,
    this.scheduledDate,
    this.chargesFromDebitAccount = true,
    this.eligibleAccounts = const [],
    this.currencies = const [],
    this.validation,
    this.charges,
    this.paymentDate,
    this.isLoadingMeta = false,
    this.isValidating = false,
    this.isSubmitting = false,
    this.otpChallenge,
    this.errorMessage,
  });

  final int step;
  final CasaAccount? debitAccount;
  final CasaAccount? creditAccount;
  final String amountText;
  final String? transferCurrency;
  final String? creditCurrency;
  final String note;
  final bool transferNow;
  final DateTime? scheduledDate;
  final bool chargesFromDebitAccount;
  final List<CasaAccount> eligibleAccounts;
  final List<PaymentCurrencyOption> currencies;
  final TransferValidationResult? validation;
  final PaymentChargesSummary? charges;
  final DateTime? paymentDate;
  final bool isLoadingMeta;
  final bool isValidating;
  final bool isSubmitting;
  final ObdxChallenge? otpChallenge;
  final String? errorMessage;

  bool get requiresOtp => otpChallenge != null;

  double? get parsedAmount {
    final cleaned = amountText.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  bool get hasCrossCurrency {
    final debit = debitAccount?.currencyCode.trim().toUpperCase();
    final credit = (creditCurrency ?? creditAccount?.currencyCode)
        ?.trim()
        .toUpperCase();
    if (debit == null || credit == null) return false;
    return debit != credit;
  }

  OwnAccountTransferState copyWith({
    int? step,
    CasaAccount? debitAccount,
    CasaAccount? creditAccount,
    bool clearDebitAccount = false,
    bool clearCreditAccount = false,
    String? amountText,
    String? transferCurrency,
    String? creditCurrency,
    String? note,
    bool? transferNow,
    DateTime? scheduledDate,
    bool clearScheduledDate = false,
    bool? chargesFromDebitAccount,
    List<CasaAccount>? eligibleAccounts,
    List<PaymentCurrencyOption>? currencies,
    TransferValidationResult? validation,
    bool clearValidation = false,
    PaymentChargesSummary? charges,
    bool clearCharges = false,
    DateTime? paymentDate,
    bool? isLoadingMeta,
    bool? isValidating,
    bool? isSubmitting,
    ObdxChallenge? otpChallenge,
    bool clearOtpChallenge = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OwnAccountTransferState(
      step: step ?? this.step,
      debitAccount:
          clearDebitAccount ? null : (debitAccount ?? this.debitAccount),
      creditAccount:
          clearCreditAccount ? null : (creditAccount ?? this.creditAccount),
      amountText: amountText ?? this.amountText,
      transferCurrency: transferCurrency ?? this.transferCurrency,
      creditCurrency: creditCurrency ?? this.creditCurrency,
      note: note ?? this.note,
      transferNow: transferNow ?? this.transferNow,
      scheduledDate: clearScheduledDate
          ? null
          : (scheduledDate ?? this.scheduledDate),
      chargesFromDebitAccount:
          chargesFromDebitAccount ?? this.chargesFromDebitAccount,
      eligibleAccounts: eligibleAccounts ?? this.eligibleAccounts,
      currencies: currencies ?? this.currencies,
      validation: clearValidation ? null : (validation ?? this.validation),
      charges: clearCharges ? null : (charges ?? this.charges),
      paymentDate: paymentDate ?? this.paymentDate,
      isLoadingMeta: isLoadingMeta ?? this.isLoadingMeta,
      isValidating: isValidating ?? this.isValidating,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      otpChallenge:
          clearOtpChallenge ? null : (otpChallenge ?? this.otpChallenge),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class OwnAccountTransferNotifier extends StateNotifier<OwnAccountTransferState> {
  OwnAccountTransferNotifier(this._ref)
      : super(const OwnAccountTransferState());

  final Ref _ref;

  Future<void> initialize() async {
    await _ref.read(casaAccountsProvider.notifier).ensureLoaded();
    final casaAccounts =
        _ref.read(casaAccountsProvider).summary?.accounts ?? const [];

    final repo = _ref.read(transferRepositoryProvider);
    var accounts = casaAccounts;

    final eligibleResult = await repo.fetchEligibleAccounts();
    if (eligibleResult is Success<List<CasaAccount>> &&
        (eligibleResult.data?.isNotEmpty ?? false)) {
      accounts = eligibleResult.data!;
    }

    if (accounts.isEmpty) {
      state = state.copyWith(eligibleAccounts: const []);
      return;
    }

    final debit = accounts.firstWhere(
      (a) => a.isActive || a.isDormant,
      orElse: () => accounts.first,
    );
    state = state.copyWith(
      eligibleAccounts: accounts,
      debitAccount: debit,
      transferCurrency: debit.currencyCode,
      creditCurrency: debit.currencyCode,
    );
    await _loadMeta();
  }

  void setStep(int step) {
    state = state.copyWith(
      step: step,
      clearError: true,
      clearOtpChallenge: true,
    );
  }

  void clearOtpChallenge() {
    state = state.copyWith(clearOtpChallenge: true, clearError: true);
  }

  Future<void> resetAfterSuccess() async {
    state = const OwnAccountTransferState();
    await initialize();
  }

  void selectDebitAccount(CasaAccount account) {
    state = state.copyWith(
      debitAccount: account,
      transferCurrency: account.currencyCode,
      clearValidation: true,
      clearCharges: true,
      clearError: true,
    );
    if (state.creditAccount?.id == account.id) {
      state = state.copyWith(clearCreditAccount: true);
    }
    _loadMeta();
  }

  void selectCreditAccount(CasaAccount account) {
    state = state.copyWith(
      creditAccount: account,
      creditCurrency: account.currencyCode,
      clearValidation: true,
      clearCharges: true,
      clearError: true,
    );
    _loadMeta();
  }

  void setAmountText(String value) {
    state = state.copyWith(
      amountText: value,
      clearValidation: true,
      clearCharges: true,
      clearError: true,
    );
  }

  void setTransferCurrency(String code) {
    state = state.copyWith(
      transferCurrency: code,
      clearValidation: true,
      clearCharges: true,
      clearError: true,
    );
  }

  void setCreditCurrency(String code) {
    state = state.copyWith(
      creditCurrency: code,
      clearValidation: true,
      clearCharges: true,
      clearError: true,
    );
  }

  void setNote(String value) => state = state.copyWith(note: value);

  void setTransferNow(bool value) {
    state = state.copyWith(
      transferNow: value,
      clearScheduledDate: value,
      clearValidation: true,
      clearError: true,
    );
  }

  void setScheduledDate(DateTime date) {
    state = state.copyWith(
      scheduledDate: date,
      transferNow: false,
      clearValidation: true,
      clearError: true,
    );
  }

  void setChargesFromDebitAccount(bool value) {
    state = state.copyWith(chargesFromDebitAccount: value);
  }

  Future<String?> validateStepAccounts() async {
    final l10n = await AppLocalizationsHelper.current();
    if (state.debitAccount == null || state.creditAccount == null) {
      return l10n.transferSelectBothAccounts;
    }
    if (state.debitAccount!.id == state.creditAccount!.id) {
      return l10n.transferSameAccountError;
    }
    return null;
  }

  Future<String?> validateStepAmount() async {
    final l10n = await AppLocalizationsHelper.current();
    final amount = state.parsedAmount;
    if (amount == null || amount <= 0) {
      return l10n.transferAmountRequired;
    }
    final available = state.debitAccount?.displayBalance?.amount;
    if (available != null && amount > available) {
      return l10n.transferInsufficientBalance;
    }
    if (!state.transferNow && state.scheduledDate == null) {
      return l10n.transferSelectDate;
    }
    return null;
  }

  Future<bool> prepareReview() async {
    final l10n = await AppLocalizationsHelper.current();
    final amountError = await validateStepAmount();
    if (amountError != null) {
      state = state.copyWith(errorMessage: amountError);
      return false;
    }

    state = state.copyWith(isValidating: true, clearError: true);
    final request = _buildRequest();
    if (request == null) {
      state = state.copyWith(
        isValidating: false,
        errorMessage: l10n.transferValidateFailed,
      );
      return false;
    }

    if (!state.transferNow) {
      final dateResult =
          await _ref.read(transferRepositoryProvider).validateScheduledDate(
                request: request,
              );
      if (dateResult is! Success<void>) {
        state = state.copyWith(
          isValidating: false,
          errorMessage: dateResult.resolveUserMessage(
          l10n: l10n,
          fallback: l10n.errorGeneric,
        ),
        );
        return false;
      }
    }

    final validateResult =
        await _ref.read(transferRepositoryProvider).validateTransfer(
              request: request,
            );

    if (validateResult is! Success<TransferValidationResult>) {
      if (SessionExpiryCoordinator.instance.isHandling) {
        state = state.copyWith(isValidating: false, clearError: true);
        return false;
      }
      state = state.copyWith(
        isValidating: false,
        errorMessage: validateResult.resolveUserMessage(
          l10n: l10n,
          fallback: l10n.transferValidateFailed,
        ),
      );
      return false;
    }

    final validation = validateResult.data;
    if (validation == null || validation.systemReferenceId.isEmpty) {
      state = state.copyWith(
        isValidating: false,
        errorMessage: l10n.transferValidateFailed,
      );
      return false;
    }

    final chargesResult =
        await _ref.read(transferRepositoryProvider).fetchCharges(
              request: request,
            );

    PaymentChargesSummary? charges;
    if (chargesResult is Success<PaymentChargesSummary>) {
      charges = chargesResult.data;
    }

    state = state.copyWith(
      isValidating: false,
      validation: validation,
      charges: charges,
      step: 2,
    );
    return true;
  }

  Future<TransferSubmitResult?> submit({String? otp}) async {
    final l10n = await AppLocalizationsHelper.current();
    final validation = state.validation;
    if (validation == null || validation.systemReferenceId.isEmpty) {
      state = state.copyWith(errorMessage: l10n.transferValidateFailed);
      return null;
    }

    final request = _buildRequest();
    if (request == null) {
      state = state.copyWith(errorMessage: l10n.transferSubmitFailed);
      return null;
    }

    final otpValue = otp?.trim();
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result =
        await _ref.read(transferRepositoryProvider).submitTransfer(
              request: request,
              systemReferenceId: validation.systemReferenceId,
              challenge: state.otpChallenge,
              otp: otpValue,
            );

    if (result is Success<TransferSubmitOutcome>) {
      final outcome = result.data;
      if (outcome?.result != null &&
          outcome!.result!.referenceNumber.isNotEmpty) {
        state = state.copyWith(
          isSubmitting: false,
          clearOtpChallenge: true,
          clearError: true,
        );
        return outcome.result;
      }
      if (outcome != null && outcome.requiresOtp) {
        state = state.copyWith(
          isSubmitting: false,
          otpChallenge: outcome.challenge,
          errorMessage: outcome.invalidOtp ? l10n.errorOtpInvalid : null,
          clearError: !outcome.invalidOtp,
        );
        return null;
      }
    }

    state = state.copyWith(isSubmitting: false);

    if (SessionExpiryCoordinator.instance.isHandling) {
      return null;
    }

    state = state.copyWith(
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: otpValue != null && otpValue.isNotEmpty
            ? l10n.errorOtpInvalid
            : l10n.transferSubmitFailed,
      ),
    );
    return null;
  }

  Future<bool> resendOtp() async {
    final l10n = await AppLocalizationsHelper.current();
    if (state.otpChallenge == null) return false;

    final remaining = state.otpChallenge!.resendsLeft;
    if (remaining != null && remaining <= 0) {
      state = state.copyWith(errorMessage: l10n.otpResendUnavailable);
      return false;
    }

    final validation = state.validation;
    final request = _buildRequest();
    if (validation == null || request == null) {
      state = state.copyWith(errorMessage: l10n.transferSubmitFailed);
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);
    final result =
        await _ref.read(transferRepositoryProvider).submitTransfer(
              request: request,
              systemReferenceId: validation.systemReferenceId,
            );

    if (result is Success<TransferSubmitOutcome> &&
        result.data != null &&
        result.data!.requiresOtp) {
      state = state.copyWith(
        isSubmitting: false,
        otpChallenge: result.data!.challenge,
        clearError: true,
      );
      return true;
    }

    state = state.copyWith(isSubmitting: false);
    if (SessionExpiryCoordinator.instance.isHandling) {
      return false;
    }
    state = state.copyWith(
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.otpResendUnavailable,
      ),
    );
    return false;
  }

  OwnAccountTransferRequest? _buildRequest() {
    final debit = state.debitAccount;
    final credit = state.creditAccount;
    final amount = state.parsedAmount;
    if (debit == null || credit == null || amount == null) return null;

    final currency = (state.transferCurrency ?? debit.currencyCode).trim();
    final paymentDate = state.transferNow
        ? (state.paymentDate ?? DateTime.now())
        : (state.scheduledDate ?? state.paymentDate ?? DateTime.now());

    Map<String, dynamic>? exchange;
    if (state.hasCrossCurrency && state.validation != null) {
      final v = state.validation!;
      exchange = {
        'sourceCurrency': v.sourceCurrency ?? currency,
        'targetCurrency':
            v.targetCurrency ?? state.creditCurrency ?? credit.currencyCode,
        'exchangeRate': v.exchangeRate?.toString() ?? '',
        'instructedAmount': {
          if (v.calculatedAmount != null) 'amount': v.calculatedAmount,
          if (v.calculatedCurrency != null) 'currency': v.calculatedCurrency,
        },
      };
    }

    return OwnAccountTransferRequest(
      debitAccount: debit,
      creditAccount: credit,
      amount: amount,
      currency: currency,
      paymentDate: paymentDate,
      remarks: state.note,
      chargesFromDebitAccount: state.chargesFromDebitAccount,
      systemReferenceId: state.validation?.systemReferenceId,
      currencyExchange: exchange,
    );
  }

  Future<void> _loadMeta() async {
    final debit = state.debitAccount;
    if (debit == null) return;

    state = state.copyWith(isLoadingMeta: true, clearError: true);
    final repo = _ref.read(transferRepositoryProvider);

    // Official OBDX sequence: networks + maintenance, then current date + currencies.
    await Future.wait([
      repo.fetchNetworks(),
      repo.fetchMaintenance(),
    ]);

    DateTime? bankDate;
    final dateResult = await repo.fetchCurrentDate();
    if (dateResult is Success<PaymentCurrentDate>) {
      bankDate = dateResult.data?.valueDate;
    }

    List<PaymentCurrencyOption> currencies = [];
    final currencyResult = await repo.fetchCurrencies(
      currency: debit.currencyCode,
    );
    if (currencyResult is Success<List<PaymentCurrencyOption>>) {
      currencies = currencyResult.data ?? [];
    }
    if (currencies.isEmpty) {
      currencies = [
        PaymentCurrencyOption(code: debit.currencyCode),
      ];
    }

    state = state.copyWith(
      isLoadingMeta: false,
      paymentDate: bankDate ?? DateTime.now(),
      currencies: currencies,
      transferCurrency: state.transferCurrency ?? debit.currencyCode,
      creditCurrency: state.creditCurrency ??
          state.creditAccount?.currencyCode ??
          debit.currencyCode,
    );
  }
}

final ownAccountTransferProvider = StateNotifierProvider.autoDispose<
    OwnAccountTransferNotifier, OwnAccountTransferState>(
  (ref) => OwnAccountTransferNotifier(ref),
);
