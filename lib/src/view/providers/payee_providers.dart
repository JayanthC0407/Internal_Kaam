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
    this.countries = const [],
    this.internationalNetworkTypes = const [],
    this.nationalClearingCodeTypes = const [],
    this.errorMessage,
    this.submitError,
    this.submitSuccess = false,
  });

  final bool isLoading;
  final bool isSubmitting;
  final List<PayeeSummary> payees;
  final List<PayeeAccountTypeOption> accountTypes;
  final List<DomesticNetworkOption> domesticNetworks;
  final List<CountryOption> countries;
  final List<PayeeEnumOption> internationalNetworkTypes;
  final List<PayeeEnumOption> nationalClearingCodeTypes;
  final String? errorMessage;
  final String? submitError;
  final bool submitSuccess;

  PayeesState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<PayeeSummary>? payees,
    List<PayeeAccountTypeOption>? accountTypes,
    List<DomesticNetworkOption>? domesticNetworks,
    List<CountryOption>? countries,
    List<PayeeEnumOption>? internationalNetworkTypes,
    List<PayeeEnumOption>? nationalClearingCodeTypes,
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
      countries: countries ?? this.countries,
      internationalNetworkTypes:
          internationalNetworkTypes ?? this.internationalNetworkTypes,
      nationalClearingCodeTypes:
          nationalClearingCodeTypes ?? this.nationalClearingCodeTypes,
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
    final countriesResult = await repository.fetchCountryOptions();
    final internationalNetworkTypesResult =
        await repository.fetchInternationalNetworkTypes();
    final nationalClearingCodeTypesResult =
        await repository.fetchNationalClearingCodeTypes();
    await repository.fetchMaintenance();
    await repository.fetchCustomLimits();
    await repository.fetchBankConfiguration();
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
    final countries = countriesResult is Success<List<CountryOption>>
        ? countriesResult.data ?? const []
        : const <CountryOption>[];
    final internationalNetworkTypes =
        internationalNetworkTypesResult is Success<List<PayeeEnumOption>>
            ? internationalNetworkTypesResult.data ?? const []
            : const <PayeeEnumOption>[];
    final nationalClearingCodeTypes =
        nationalClearingCodeTypesResult is Success<List<PayeeEnumOption>>
            ? nationalClearingCodeTypesResult.data ?? const []
            : const <PayeeEnumOption>[];

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

    // Country fetch failures are non-fatal — the International Payee /
    // Demand Draft screens fall back to an empty picker rather than
    // blocking the whole Manage Payee bootstrap on it.

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
      countries: countries,
      internationalNetworkTypes: internationalNetworkTypes,
      nationalClearingCodeTypes: nationalClearingCodeTypes,
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

  /// International Payee final submit.
  Future<bool> createInternationalPayee({
    required String nickname,
    required String accountNumber,
    required String accountName,
    required String payeeEmail,
    required String network,
    required Map<String, dynamic> bankDetails,
    required Map<String, dynamic> address,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearSubmitError: true,
      submitSuccess: false,
    );

    final result =
        await _ref.read(payeeRepositoryProvider).createInternationalPayee(
              nickname: nickname,
              accountNumber: accountNumber,
              accountName: accountName,
              payeeEmail: payeeEmail,
              network: network,
              bankDetails: bankDetails,
              address: address,
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
        fallback: 'Unable to create international payee.',
      ),
      submitSuccess: false,
    );
    return false;
  }

  /// Shared final submit for Demand Draft Payee (Domestic/International)
  /// and Peer-To-Peer Payee — see [PayeeRepository.submitPayeeGroup].
  Future<bool> submitPayeeGroup({required String name}) async {
    state = state.copyWith(
      isSubmitting: true,
      clearSubmitError: true,
      submitSuccess: false,
    );

    final result =
        await _ref.read(payeeRepositoryProvider).submitPayeeGroup(name: name);
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
        fallback: 'Unable to submit payee.',
      ),
      submitSuccess: false,
    );
    return false;
  }

  /// Domestic Payee IFSC/BIC "Verify". Returns a message to show the user
  /// either way — success text when the lookup returns a usable name/detail
  /// field, otherwise the server's error message.
  Future<({bool success, String message})> verifyNetworkCode({
    required String code,
    required String network,
  }) async {
    final result = await _ref
        .read(payeeRepositoryProvider)
        .verifyNetworkCode(code: code, network: network);
    final l10n = await AppLocalizationsHelper.current();

    if (result is Success<Map<String, dynamic>>) {
      final body = result.data ?? const {};
      final name = firstNonEmptyPayeeField(
        body,
        const ['bankName', 'name', 'branchName', 'description'],
      );
      return (
        success: true,
        message: name != null ? 'Verified: $name' : 'Code verified.',
      );
    }

    return (
      success: false,
      message: result.resolveUserMessage(
        l10n: l10n,
        fallback: 'Verification failed.',
      ),
    );
  }

  /// International Payee "Verify" (National Clearing Code).
  Future<({bool success, String message})> verifyNationalClearingCode({
    required String country,
    required String codeType,
  }) async {
    final result = await _ref
        .read(payeeRepositoryProvider)
        .verifyNationalClearingCode(country: country, codeType: codeType);
    final l10n = await AppLocalizationsHelper.current();

    if (result is Success<Map<String, dynamic>>) {
      final body = result.data ?? const {};
      final name = firstNonEmptyPayeeField(
        body,
        const ['bankName', 'name', 'branchName', 'description'],
      );
      return (
        success: true,
        message: name != null ? 'Verified: $name' : 'Code verified.',
      );
    }

    return (
      success: false,
      message: result.resolveUserMessage(
        l10n: l10n,
        fallback: 'Verification failed.',
      ),
    );
  }

  /// City/location list for the Demand Draft Payee "Draft Payable At" /
  /// "City" pickers — fetched on demand rather than during [refresh] since
  /// it's only needed once Demand Draft Payee is opened.
  Future<List<CityOption>> fetchCities() async {
    final result = await _ref.read(payeeRepositoryProvider).fetchCities();
    return result is Success<List<CityOption>> ? result.data ?? const [] : const [];
  }

  Future<BranchOption?> fetchBranchForCity(String city) async {
    final result =
        await _ref.read(payeeRepositoryProvider).fetchBranchForCity(city);
    return result is Success<BranchOption?> ? result.data : null;
  }

  Future<BranchAddress?> fetchBranchAddress(String branchCode) async {
    final result =
        await _ref.read(payeeRepositoryProvider).fetchBranchAddress(branchCode);
    return result is Success<BranchAddress?> ? result.data : null;
  }

  Future<List<PayeeEnumOption>> fetchAddressTypes() async {
    final result = await _ref.read(payeeRepositoryProvider).fetchAddressTypes();
    return result is Success<List<PayeeEnumOption>>
        ? result.data ?? const []
        : const [];
  }

  Future<List<PartyAddress>> fetchPartyAddresses() async {
    final result =
        await _ref.read(payeeRepositoryProvider).fetchPartyAddresses();
    return result is Success<List<PartyAddress>>
        ? result.data ?? const []
        : const [];
  }
}
