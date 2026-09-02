import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/payee/payee_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/repository_providers.dart';

class PayeesState {
  const PayeesState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.payees = const [],
    this.accountTypes = const [],
    this.domesticNetworks = const [],
    this.errorMessage,
    this.submitError,
    this.submitSuccess = false,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<PayeeSummary> payees;
  final List<PayeeAccountTypeOption> accountTypes;
  final List<DomesticNetworkOption> domesticNetworks;
  final String? errorMessage;
  final String? submitError;
  final bool submitSuccess;

  PayeesState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<PayeeSummary>? payees,
    List<PayeeAccountTypeOption>? accountTypes,
    List<DomesticNetworkOption>? domesticNetworks,
    String? errorMessage,
    String? submitError,
    bool? submitSuccess,
    bool clearError = false,
    bool clearSubmitError = false,
  }) {
    return PayeesState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      payees: payees ?? this.payees,
      accountTypes: accountTypes ?? this.accountTypes,
      domesticNetworks: domesticNetworks ?? this.domesticNetworks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submitError:
          clearSubmitError ? null : (submitError ?? this.submitError),
      submitSuccess: submitSuccess ?? this.submitSuccess,
    );
  }
}

final payeesProvider = StateNotifierProvider<PayeesNotifier, PayeesState>(
  (ref) => PayeesNotifier(ref),
);

class PayeesNotifier extends StateNotifier<PayeesState> {
  PayeesNotifier(this._ref) : super(const PayeesState());

  final Ref _ref;
  bool _loadedOnce = false;

  Future<void> ensureLoaded() async {
    if (_loadedOnce || state.isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final repository = _ref.read(payeeRepositoryProvider);

    // Mirror the captured Manage Payee / Add Bank Account Payee bootstrap.
    // The configuration calls are kept here because they influence the real
    // OBDX payee UI/validation even when some values are not displayed yet.
    final payeesResult = await repository.fetchPayees();
    final accountTypesResult = await repository.fetchAccountTypes();
    final networksResult = await repository.fetchDomesticNetworks();
    await repository.fetchMaintenance();
    await repository.fetchCustomLimits();
    await repository.fetchBankConfiguration();
    await repository.fetchCountries();
    await repository.fetchAssignedLimits();
    await repository.fetchPayeeContent();
    final l10n = await AppLocalizationsHelper.current();

    final errors = <String>[];
    final payees = payeesResult is Success<List<PayeeSummary>>
        ? payeesResult.data ?? const []
        : const <PayeeSummary>[];
    final accountTypes =
        accountTypesResult is Success<List<PayeeAccountTypeOption>>
            ? accountTypesResult.data ?? const []
            : const <PayeeAccountTypeOption>[];
    final networks =
        networksResult is Success<List<DomesticNetworkOption>>
            ? networksResult.data ?? const []
            : const <DomesticNetworkOption>[];

    if (payeesResult is! Success<List<PayeeSummary>>) {
      errors.add(
        payeesResult.resolveUserMessage(
          l10n: l10n,
          fallback: 'Unable to load payees.',
        ),
      );
    }
    if (accountTypesResult is! Success<List<PayeeAccountTypeOption>>) {
      errors.add(
        accountTypesResult.resolveUserMessage(
          l10n: l10n,
          fallback: 'Unable to load account types.',
        ),
      );
    }
    if (networksResult is! Success<List<DomesticNetworkOption>>) {
      errors.add(
        networksResult.resolveUserMessage(
          l10n: l10n,
          fallback: 'Unable to load domestic networks.',
        ),
      );
    }

    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    _loadedOnce = true;
    state = PayeesState(
      isLoading: false,
      payees: payees,
      accountTypes: accountTypes,
      domesticNetworks: networks,
      errorMessage: errors.isEmpty ? null : errors.join('\n'),
    );
  }

  Future<bool> createInternalPayee({
    required String nickname,
    required String accountNumber,
    required String accountName,
    required String payeeEmail,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearSubmitError: true,
      submitSuccess: false,
    );

    final result = await _ref.read(payeeRepositoryProvider).createInternalPayee(
          nickname: nickname,
          accountNumber: accountNumber,
          accountName: accountName,
          payeeEmail: payeeEmail,
        );
    final l10n = await AppLocalizationsHelper.current();

    if (result is Success<void>) {
      state = state.copyWith(
        isSubmitting: false,
        submitSuccess: true,
        clearSubmitError: true,
      );
      _loadedOnce = false;
      await refresh();
      return true;
    }

    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isSubmitting: false, clearSubmitError: true);
      return false;
    }

    state = state.copyWith(
      isSubmitting: false,
      submitError: result.resolveUserMessage(
        l10n: l10n,
        fallback: 'Unable to create internal payee.',
      ),
      submitSuccess: false,
    );
    return false;
  }
}
