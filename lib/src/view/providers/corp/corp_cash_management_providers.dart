import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/corp/corp_pickup_point.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_cash_management_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_cash_management_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';

final obdxCorpCashManagementApiProvider = Provider(
  (ref) => ObdxCorpCashManagementApi(ref.watch(obdxDioClientProvider)),
);

final corpCashManagementRepositoryProvider = Provider(
  (ref) => CorpCashManagementRepository(
    cashManagementApi: ref.watch(obdxCorpCashManagementApiProvider),
  ),
);

class CorpPickupPointsState {
  const CorpPickupPointsState({
    this.isLoading = false,
    this.points = const <CorpPickupPoint>[],
    this.errorMessage,
  });

  final bool isLoading;
  final List<CorpPickupPoint> points;
  final String? errorMessage;

  CorpPickupPointsState copyWith({
    bool? isLoading,
    List<CorpPickupPoint>? points,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CorpPickupPointsState(
      isLoading: isLoading ?? this.isLoading,
      points: points ?? this.points,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns the data for the `pickup-point-collections` dashboard widget.
///
/// Deliberately separate from `corpAccountsProvider`: this is the first
/// dashboard widget with its own data source, and it loads on mount rather
/// than as part of the dashboard's primary load. That is the pattern every
/// future personalizable widget should follow — a widget the user has
/// switched off must not cost a request.
class CorpPickupPointsNotifier extends StateNotifier<CorpPickupPointsState> {
  CorpPickupPointsNotifier(this._ref) : super(const CorpPickupPointsState());

  final Ref _ref;
  bool _loadedOnce = false;
  Future<void>? _pendingLoad;

  Future<void> ensureLoaded() {
    if (_loadedOnce) return Future.value();
    return _pendingLoad ??= refresh().whenComplete(() {
      _pendingLoad = null;
    });
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _ref
        .read(corpCashManagementRepositoryProvider)
        .fetchPickupPoints();

    if (!mounted) return;

    if (result is Success<List<CorpPickupPoint>>) {
      _loadedOnce = true;
      state = CorpPickupPointsState(
        isLoading: false,
        points: result.data ?? const [],
      );
      return;
    }

    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    final l10n = await AppLocalizationsHelper.current();
    if (!mounted) return;
    _loadedOnce = true;
    state = state.copyWith(
      isLoading: false,
      errorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: 'Could not load pickup points.',
      ),
    );
  }
}

final corpPickupPointsProvider =
    StateNotifierProvider<CorpPickupPointsNotifier, CorpPickupPointsState>(
  (ref) => CorpPickupPointsNotifier(ref),
);
