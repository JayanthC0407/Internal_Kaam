import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/casa_account_detail.dart';
import 'package:ubci_bank/src/core/models/casa_transaction.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/accounts_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/network_providers.dart';

final accountsRepositoryProvider = Provider(
  (ref) => AccountsRepository(
    accountsApi: ref.watch(obdxAccountsApiProvider),
  ),
);

class CasaAccountsState {
  const CasaAccountsState({
    this.isLoading = false,
    this.summary,
    this.errorMessage,
    this.accountsIncludingClosed,
  });

  final bool isLoading;
  final CasaAccountsSummary? summary;
  final String? errorMessage;

  /// API-03 result (ACTIVE/DORMANT/CLOSED) — kept separate from [summary]
  /// (API-01, ACTIVE/DORMANT only) so list/dashboard surfaces never show
  /// closed accounts by default.
  final CasaAccountsSummary? accountsIncludingClosed;

  CasaAccountsState copyWith({
    bool? isLoading,
    CasaAccountsSummary? summary,
    String? errorMessage,
    CasaAccountsSummary? accountsIncludingClosed,
    bool clearError = false,
    bool clearSummary = false,
  }) {
    return CasaAccountsState(
      isLoading: isLoading ?? this.isLoading,
      summary: clearSummary ? null : (summary ?? this.summary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      accountsIncludingClosed:
          accountsIncludingClosed ?? this.accountsIncludingClosed,
    );
  }
}

class CasaAccountsNotifier extends StateNotifier<CasaAccountsState> {
  CasaAccountsNotifier(this._ref) : super(const CasaAccountsState());

  final Ref _ref;
  bool _loadedOnce = false;

  // Concurrent `ensureLoaded()` callers (e.g. the dashboard's own
  // post-frame preload racing the Recent Transactions widget's own
  // preload) used to just check `state.isLoading` and bail out
  // immediately if a fetch was already in flight — the second caller
  // would then read the still-empty `state` before the first fetch had
  // resolved, which is why "Recent Transactions" could render empty on
  // the very first load. Sharing the in-flight future instead makes
  // every caller await the *same* completed load.
  Future<void>? _pendingLoad;

  Future<void> ensureLoaded() {
    if (_loadedOnce) return Future.value();
    return _pendingLoad ??= refresh().whenComplete(() {
      _pendingLoad = null;
    });
  }

  /// API-03 — silently refreshes the cached account list to include CLOSED
  /// accounts, as observed in the doc's transaction-history flow. Fire and
  /// forget: never surfaces its own loading/error state since it's a
  /// background supporting call, not the primary list load.
  Future<void> refreshIncludingClosed() async {
    final result = await _ref
        .read(accountsRepositoryProvider)
        .fetchCasaAccountsIncludingClosed();
    if (result is Success<CasaAccountsSummary> && result.data != null) {
      state = state.copyWith(accountsIncludingClosed: result.data);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result =
        await _ref.read(accountsRepositoryProvider).fetchCasaAccounts();
    final l10n = await AppLocalizationsHelper.current();

    if (result is Success<CasaAccountsSummary>) {
      _loadedOnce = true;
      state = CasaAccountsState(
        isLoading: false,
        summary: result.data ??
            const CasaAccountsSummary(accounts: [], totalsByCurrency: {}),
      );
      return;
    }

    // Session expiry interceptor is redirecting — skip inline error.
    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    _loadedOnce = true;
    state = state.copyWith(
      isLoading: false,
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.errorAccountsLoadFailed,
      ),
    );
  }
}

final casaAccountsProvider =
    StateNotifierProvider<CasaAccountsNotifier, CasaAccountsState>(
  (ref) => CasaAccountsNotifier(ref),
);

class CasaAccountDetailState {
  const CasaAccountDetailState({
    this.isLoading = false,
    this.detail,
    this.errorMessage,
  });

  final bool isLoading;
  final CasaAccountDetail? detail;
  final String? errorMessage;

  CasaAccountDetailState copyWith({
    bool? isLoading,
    CasaAccountDetail? detail,
    String? errorMessage,
    bool clearError = false,
    bool clearDetail = false,
  }) {
    return CasaAccountDetailState(
      isLoading: isLoading ?? this.isLoading,
      detail: clearDetail ? null : (detail ?? this.detail),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CasaAccountDetailNotifier extends StateNotifier<CasaAccountDetailState> {
  CasaAccountDetailNotifier(this._ref, this.accountId)
      : super(const CasaAccountDetailState());

  final Ref _ref;
  final String accountId;

  Future<void> load() async {
    if (accountId.trim().isEmpty) {
      final l10n = await AppLocalizationsHelper.current();
      state = CasaAccountDetailState(
        errorMessage: l10n.errorAccountDetailLoadFailed,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearDetail: true,
    );
    final result = await _ref
        .read(accountsRepositoryProvider)
        .fetchCasaAccountDetail(accountId);
    final l10n = await AppLocalizationsHelper.current();

    if (result is Success<CasaAccountDetail>) {
      state = CasaAccountDetailState(
        isLoading: false,
        detail: result.data,
      );
      return;
    }

    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.errorAccountDetailLoadFailed,
      ),
    );
  }
}

final casaAccountDetailProvider = StateNotifierProvider.autoDispose
    .family<CasaAccountDetailNotifier, CasaAccountDetailState, String>(
  (ref, accountId) => CasaAccountDetailNotifier(ref, accountId),
);

class CasaTransactionsState {
  const CasaTransactionsState({
    this.isLoading = false,
    this.result,
    this.query = const CasaTransactionQuery(),
    this.errorMessage,
  });

  final bool isLoading;
  final CasaTransactionsResult? result;
  final CasaTransactionQuery query;
  final String? errorMessage;

  CasaTransactionsState copyWith({
    bool? isLoading,
    CasaTransactionsResult? result,
    CasaTransactionQuery? query,
    String? errorMessage,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return CasaTransactionsState(
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      query: query ?? this.query,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CasaTransactionsNotifier extends StateNotifier<CasaTransactionsState> {
  CasaTransactionsNotifier(this._ref, this.accountId)
      : super(const CasaTransactionsState());

  final Ref _ref;
  final String accountId;

  Future<void> load({CasaTransactionQuery? query}) async {
    if (accountId.trim().isEmpty) {
      final l10n = await AppLocalizationsHelper.current();
      state = CasaTransactionsState(
        errorMessage: l10n.errorTransactionsLoadFailed,
        query: query ?? state.query,
      );
      return;
    }

    final nextQuery = query ?? state.query;
    state = state.copyWith(
      isLoading: true,
      query: nextQuery,
      clearError: true,
    );
    final result = await _ref
        .read(accountsRepositoryProvider)
        .fetchCasaTransactions(accountId, query: nextQuery);
    final l10n = await AppLocalizationsHelper.current();

    if (result is Success<CasaTransactionsResult>) {
      state = CasaTransactionsState(
        isLoading: false,
        query: nextQuery,
        result: result.data ??
            const CasaTransactionsResult(transactions: []),
      );
      return;
    }

    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.errorTransactionsLoadFailed,
      ),
    );
  }
}

final casaTransactionsProvider = StateNotifierProvider.autoDispose
    .family<CasaTransactionsNotifier, CasaTransactionsState, String>(
  (ref, accountId) => CasaTransactionsNotifier(ref, accountId),
);

// Recent-transactions state for the dashboard's "Recent Transactions"
// widget now lives in recent_transactions_widget_providers.dart
// (RecentTransactionsWidgetNotifier / recentTransactionsWidgetProvider),
// which supports switching between account categories (CASA, Loans, ...)
// rather than always showing the primary CASA account.
