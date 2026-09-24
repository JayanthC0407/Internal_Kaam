import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_repository_providers.dart';

/// Corporate accounts state for the dashboard.
///
/// The aggregated `account/v1/accounts` call ([CorpAccountsState.summary])
/// is the dashboard's primary load and backs both the Account Summary grid
/// and the Accounts tab. Deposits and Loans are fetched lazily — only when
/// their tab is first opened — and merged into the same summary, so the
/// grid and the card always read one consistent account list.
class CorpAccountsState {
  const CorpAccountsState({
    this.isLoading = false,
    this.summary = CorpAccountsSummary.empty,
    this.errorMessage,
    this.loadingGroups = const <CorpAccountGroup>{},
    this.groupErrors = const <CorpAccountGroup, String>{},
    this.loadedGroups = const <CorpAccountGroup>{},
  });

  final bool isLoading;
  final CorpAccountsSummary summary;

  /// Failure of the primary accounts load.
  final String? errorMessage;

  /// Groups whose own lazy fetch is in flight (Deposits / Loans).
  final Set<CorpAccountGroup> loadingGroups;

  /// Per-group lazy-fetch failures, keyed by group.
  final Map<CorpAccountGroup, String> groupErrors;

  /// Groups whose lazy fetch has completed at least once — distinguishes
  /// "not asked yet" from "asked, and the party genuinely has none".
  final Set<CorpAccountGroup> loadedGroups;

  bool isGroupLoading(CorpAccountGroup group) => loadingGroups.contains(group);
  bool isGroupLoaded(CorpAccountGroup group) => loadedGroups.contains(group);
  String? groupError(CorpAccountGroup group) => groupErrors[group];

  CorpAccountsState copyWith({
    bool? isLoading,
    CorpAccountsSummary? summary,
    String? errorMessage,
    Set<CorpAccountGroup>? loadingGroups,
    Map<CorpAccountGroup, String>? groupErrors,
    Set<CorpAccountGroup>? loadedGroups,
    bool clearError = false,
  }) {
    return CorpAccountsState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loadingGroups: loadingGroups ?? this.loadingGroups,
      groupErrors: groupErrors ?? this.groupErrors,
      loadedGroups: loadedGroups ?? this.loadedGroups,
    );
  }
}

class CorpAccountsNotifier extends StateNotifier<CorpAccountsState> {
  CorpAccountsNotifier(this._ref) : super(const CorpAccountsState());

  final Ref _ref;
  bool _loadedOnce = false;

  /// Shared in-flight load, so concurrent `ensureLoaded()` callers (the
  /// dashboard's own post-frame preload and the summary grid's) all await
  /// the same completed fetch instead of one reading empty state.
  Future<void>? _pendingLoad;
  final Map<CorpAccountGroup, Future<void>> _pendingGroupLoads = {};

  Future<void> ensureLoaded() {
    if (_loadedOnce) return Future.value();
    return _pendingLoad ??= refresh().whenComplete(() {
      _pendingLoad = null;
    });
  }

  Future<void> refresh() async {
    final generation = SessionGeneration.current;
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _ref.read(corpAccountsRepositoryProvider).fetchAccounts();

    if (!SessionGeneration.isCurrent(generation) || !mounted) return;

    if (result is Success<CorpAccountsSummary>) {
      _loadedOnce = true;
      state = CorpAccountsState(
        isLoading: false,
        summary: result.data ?? CorpAccountsSummary.empty,
        // A refresh replaces the aggregated list, so any previously merged
        // lazy groups have to be re-fetched rather than silently kept.
        loadedGroups: const <CorpAccountGroup>{},
      );
      return;
    }

    // The session-expiry interceptor is already redirecting to login —
    // don't also flash an inline error on the way out.
    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    final l10n = await AppLocalizationsHelper.current();
    _loadedOnce = true;
    state = state.copyWith(
      isLoading: false,
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.errorAccountsLoadFailed,
      ),
    );
  }

  /// Loads [group] once, on first view of its tab. Deposits and Loans have
  /// dedicated list endpoints; CASA already arrives with [refresh].
  Future<void> ensureGroupLoaded(CorpAccountGroup group) {
    if (group == CorpAccountGroup.casa || group == CorpAccountGroup.other) {
      return ensureLoaded();
    }
    if (state.isGroupLoaded(group)) return Future.value();
    final pending = _pendingGroupLoads[group];
    if (pending != null) return pending;

    final load = _loadGroup(group).whenComplete(() {
      _pendingGroupLoads.remove(group);
    });
    _pendingGroupLoads[group] = load;
    return load;
  }

  Future<void> refreshGroup(CorpAccountGroup group) {
    if (group == CorpAccountGroup.casa || group == CorpAccountGroup.other) {
      return refresh();
    }
    _pendingGroupLoads.remove(group);
    state = state.copyWith(
      loadedGroups: {...state.loadedGroups}..remove(group),
    );
    return ensureGroupLoaded(group);
  }

  Future<void> _loadGroup(CorpAccountGroup group) async {
    final generation = SessionGeneration.current;
    state = state.copyWith(
      loadingGroups: {...state.loadingGroups, group},
      groupErrors: {...state.groupErrors}..remove(group),
    );

    final repository = _ref.read(corpAccountsRepositoryProvider);
    final result = switch (group) {
      CorpAccountGroup.deposit => await repository.fetchDeposits(),
      CorpAccountGroup.loan => await repository.fetchLoans(),
      _ => null,
    };

    if (!SessionGeneration.isCurrent(generation) || !mounted) return;

    if (result == null) {
      state = state.copyWith(
        loadingGroups: {...state.loadingGroups}..remove(group),
      );
      return;
    }

    if (result is Success<List<CorpAccount>>) {
      state = state.copyWith(
        summary: state.summary.mergeGroup(group, result.data ?? const []),
        loadingGroups: {...state.loadingGroups}..remove(group),
        loadedGroups: {...state.loadedGroups, group},
      );
      return;
    }

    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(
        loadingGroups: {...state.loadingGroups}..remove(group),
      );
      return;
    }

    final l10n = await AppLocalizationsHelper.current();
    state = state.copyWith(
      loadingGroups: {...state.loadingGroups}..remove(group),
      loadedGroups: {...state.loadedGroups, group},
      groupErrors: {
        ...state.groupErrors,
        group: result.resolveUserMessage(
          l10n: l10n,
          fallback: l10n.errorAccountsLoadFailed,
        ),
      },
    );
  }
}

final corpAccountsProvider =
    StateNotifierProvider<CorpAccountsNotifier, CorpAccountsState>(
  (ref) => CorpAccountsNotifier(ref),
);
