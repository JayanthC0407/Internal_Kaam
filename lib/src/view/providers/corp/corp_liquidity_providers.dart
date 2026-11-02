import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/corp/liquidity_charges_models.dart';
import 'package:ubci_bank/src/core/models/corp/liquidity_overview_models.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_liquidity_api.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_liquidity_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';

/// Liquidity Management (docs/obdx/features/liquidity-management.md).

final obdxCorpLiquidityApiProvider = Provider((ref) => ObdxCorpLiquidityApi(ref.watch(obdxDioClientProvider)));

final corpLiquidityRepositoryProvider =
    Provider((ref) => CorpLiquidityRepository(api: ref.watch(obdxCorpLiquidityApiProvider)));

/// Which Liquidity Management screens the user may open, by OBDX
/// component name (`me/components`). An empty set allows all, as for the
/// other corporate menus.
class LmPermissions {
  const LmPermissions({this.overview = true, this.chargesInquiry = true});

  /// Overview: OBDX lists a `type: MODULE` entry only when its name is in
  /// `me/components` → `defaultDashboards` (dashboard.js:316-317).
  final bool overview;

  /// `lm-charges-inquiry` (UIAuthorization.json:84-89).
  final bool chargesInquiry;

  bool get any => overview || chargesInquiry;
}

final lmPermissionsProvider = Provider<LmPermissions>((ref) {
  final authorized = ref.watch(personalizationProvider).authorized;
  return LmPermissions(
    overview: authorized.isEmpty || authorized.defaultDashboards.contains(LmOverviewWidget.module),
    chargesInquiry: authorized.isEmpty || authorized.contains('lm-charges-inquiry'),
  );
});

/// Charges Inquiry's options and maintained period; never fails.
final lmChargeSetupProvider = FutureProvider.autoDispose<LmChargeSetup>(
  (ref) => ref.read(corpLiquidityRepositoryProvider).fetchChargeSetup(),
);

// ------------------------------------------------------------------ Overview

/// "Today" for the sweep windows: the device date at midnight (OBDX uses
/// the server date, `DomUtil.getDate()`).
final lmTodayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// The Overview's widgets for [breakpoint]: the server layout
/// (`dashboards/modules?class=MODULE&value=liquidity-management`), else its
/// default layout, else all six in `moduleComponents.json` order. As OBDX's
/// container does, a widget the user's `me/components` does not list is
/// dropped (an empty set drops none). The class is always `MODULE`
/// `[UNKNOWN]` (card §2).
final lmOverviewLayoutProvider =
    FutureProvider.autoDispose.family<List<LmOverviewWidget>, DashboardBreakpoint>((ref, breakpoint) async {
  final authorized = ref.watch(personalizationProvider).authorized;
  final result = await ref
      .read(dashboardRepositoryProvider)
      .fetchConfig(dashboardClass: 'MODULE', dashboardClassValue: LmOverviewWidget.module);
  var widgets = LmOverviewWidget.values;
  if (result is Success<DashboardConfig> && result.data != null) {
    final config = result.data!;
    final names = config.selectedComponentsAt(breakpoint);
    widgets = LmOverviewWidget.fromLayout(
        names.isNotEmpty ? names : config.selectedComponentsAt(DashboardBreakpoint.defaultLayout));
  }
  return [for (final w in widgets) if (authorized.isEmpty || authorized.contains(w.componentName)) w];
});

final lmPositionByCurrencyProvider = FutureProvider.autoDispose<LmBalances>(
  (ref) async => _data(await ref.read(corpLiquidityRepositoryProvider).fetchPositionByCurrency()),
);

final lmRegionBalancesProvider = FutureProvider.autoDispose<LmBalances>(
  (ref) async => _data(await ref.read(corpLiquidityRepositoryProvider).fetchRegionBalances()),
);

final lmAssetsBalancesProvider = FutureProvider.autoDispose<LmBalances>(
  (ref) async => _data(await ref.read(corpLiquidityRepositoryProvider).fetchAssetsBalances()),
);

/// Position By Region converted into a currency.
final lmRegionPositionsProvider = FutureProvider.autoDispose.family<LmRegionPositions, String>((ref, currency) async {
  final data = await ref.watch(lmRegionBalancesProvider.future);
  final rates = await ref.read(corpLiquidityRepositoryProvider).fetchRates(data.accounts, currency);
  return LmRegionPositions.of(data.accounts, rates, currency);
});

/// Assets & Liabilities converted into a currency.
final lmAssetsLiabilitiesProvider = FutureProvider.autoDispose.family<LmAssetsLiabilities, String>((ref, currency) async {
  final data = await ref.watch(lmAssetsBalancesProvider.future);
  final rates = await ref.read(corpLiquidityRepositoryProvider).fetchRates(data.accounts, currency);
  return LmAssetsLiabilities.of(data.accounts, rates, currency);
});

/// The two Top 5 widgets' currency choice (same request for both).
final lmSweepCurrenciesProvider = FutureProvider.autoDispose<LmBalances>(
  (ref) => ref.read(corpLiquidityRepositoryProvider).fetchSweepCurrencies(),
);

typedef LmTopSweepsKey = ({String currency, bool cross});

final lmTopSweepsProvider = FutureProvider.autoDispose.family<List<LmSweepLog>, LmTopSweepsKey>((ref, key) async {
  final today = ref.watch(lmTodayProvider);
  return _data(
      await ref.read(corpLiquidityRepositoryProvider).fetchTopSweeps(key.currency, cross: key.cross, today: today));
});

final lmStructuresProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) => ref.read(corpLiquidityRepositoryProvider).fetchStructures(),
);

final lmSweepMonitorProvider = FutureProvider.autoDispose.family<List<LmSweepLog>, LmSweepStatus>((ref, status) async {
  final today = ref.watch(lmTodayProvider);
  return _data(await ref.read(corpLiquidityRepositoryProvider).fetchSweepMonitor(status, today: today));
});

T _data<T>(ResponseHandler<T> result) {
  if (result is Success<T> && result.data != null) return result.data as T;
  throw LmLoadError(result is Error<T> ? result.error : null);
}

/// Load failure; [message] is OBDX's text when the server sent one.
class LmLoadError implements Exception {
  const LmLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'LmLoadError';
}
