/// Corporate (`corporateuser`) endpoint paths.
///
/// Every path here was taken from the Corporate "LOGIN to DASHBOARD" HAR
/// capture; the entry number of the capture is noted against each one so the
/// exact request/response shape stays traceable. Retail paths remain in
/// `ApiConst` — this class only adds what the corporate flow needs, it does
/// not shadow or replace it (host, headers, auth and locale handling are all
/// still shared through `ObdxDioClient` / `ApiConst`).
class CorpApiConst {
  CorpApiConst._();

  /// Aggregated account list + per-product-group summary.
  /// `GET /digx-common/account/v1/accounts` — capture entry #68.
  ///
  /// Unlike Retail's `dda/v1/demandDeposit`, this returns every product
  /// group the corporate user can see in one call, plus a `summary.items[]`
  /// roll-up already converted to the bank's calculation currency.
  static const String accountsApi = '/digx-common/account/v1/accounts';

  /// Demand-deposit (CASA) list — capture entry #38. Same payload shape as
  /// [accountsApi] but CASA-only; kept as a fallback for hosts where the
  /// aggregated endpoint is not enabled for corporate users.
  static const String demandDepositApi = '/digx-common/dda/v1/demandDeposit';

  /// Term / recurring deposits — capture entry #61.
  /// `GET /digx-common/td/v1/deposit?module=CON&module=ISL`
  static const String depositsApi = '/digx-common/td/v1/deposit';

  /// Loans & finances. Not exercised by the capture (the captured corporate
  /// party holds no loans — `summary.items[]` reports `accountType: LON,
  /// count: 0`), but it is the same `digx-common` list endpoint the Retail
  /// flow already uses successfully, so the Loans tab calls it directly.
  static const String loansApi = '/digx-common/loan/v1/loan';

  /// Corporate party behind the logged-in user — capture entry #12.
  static const String partyApi = '/digx-common/user/v1/me/party';

  /// Bank-wide configuration (calculation currency, enabled modules) —
  /// capture entry #7.
  static const String bankConfigurationApi =
      '/digx-common/common/v1/bankConfiguration';

  /// Unread-message badge count for the header bell — capture entry #10.
  /// `GET /digx-common/collaboration/v1/mailbox/count?msgFlag=T`
  static const String mailboxCountApi =
      '/digx-common/collaboration/v1/mailbox/count';

  /// Deposit modules requested by digx-ui on the corporate dashboard
  /// (conventional + Islamic) — capture entry #61 sends both.
  static const List<String> depositModules = ['CON', 'ISL'];

  // ── Personalized-dashboard widgets ────────────────────────────────────
  //
  // Entry numbers below refer to `Home_widgets(corp).har`, the capture of
  // the corporate Home page with its dashboard widgets loaded.

  /// Currency master (code + description) behind the Currency Exposure
  /// widget — capture entry #39. Supplies display names only; the exposure
  /// figures themselves are derived from [accountsApi].
  static const String currencyApi = '/digx-common/common/v1/currency';

  /// Cash-management pickup and delivery points — capture entry #45.
  ///
  /// digx-ui sends a `queryParams` JSON filter; the captured calls use
  /// `serviceType EQUALS P` with `collection` of `CASH` or `PAPERBASE`.
  static const String pickupAndDeliveryPointsApi =
      '/digx-cms/cms/v1/cashmanagement/collections/maintenances/pickupAndDeliveryPoints';

  /// Cheque collections aggregated by pickup point — capture entry #51.
  /// Returned `aggregatedData` is empty for the captured party, so the
  /// widget must render without it.
  static const String chequeAggregatorApi =
      '/digx-cms/cms/v1/aggregator/resource/cheques';

  /// Collection types the pickup-point capture requests.
  static const List<String> pickupCollectionTypes = ['CASH', 'PAPERBASE'];

  // ── Personalized dashboard ────────────────────────────────────────────

  /// Dashboard configuration — `widgets(corp).har` entry #3.
  ///
  /// `class` and `value` are **not** constants: they come from the user's
  /// own `me` response (`dashboardResponse.dashboardDTOs[]`). For the
  /// captured corporate user that is `CUSTOM` / `custom`, but a user with
  /// no personalized dashboard resolves to their factory `USER_TYPE` one.
  ///
  /// Shares a path with `ApiConst.dashboardModulesApi`, which the
  /// first-time Login Flow Wizard probes with `class=USER_TYPE&value=Customer`
  /// purely to detect a 428. Different parameters, different purpose —
  /// deliberately kept as separate call sites.
  static const String dashboardModulesApi =
      '/digx-admin/config/v1/dashboards/modules';

  /// Personalization save — `widgets(corp).har` entry #4.
  /// `PUT /digx-admin/config/v1/dashboards/user/{dashboardId}`
  static String dashboardUserApi(String dashboardId) =>
      '/digx-admin/config/v1/dashboards/user/${Uri.encodeComponent(dashboardId)}';

  /// Authorization set — `Home_widgets(corp).har` entry #6. Returns
  /// `authorizedUIComponents` (~2500 names spanning the whole app, not just
  /// dashboard widgets) plus `defaultDashboards`.
  static const String meComponentsApi = '/digx-common/user/v1/me/components';

  /// The widget catalog, served by the environment alongside the menu JSON
  /// the web client fetches (`framework/json/menu/corporate.json`, capture
  /// entry #15).
  ///
  /// Preferred over the bundled asset because the environment's catalog is
  /// richer: the real Personalize screen lists whole modules the shipped
  /// file lacks (Purchase Order Management, Reconciliation) and 8 cash
  /// management widgets against the file's 2.
  static const String moduleComponentsPath =
      '/framework/json/moduleComponents.json';

  /// Bundled fallback, used only when [moduleComponentsPath] cannot be
  /// fetched. Known to lag the environment — see above.
  static const String moduleComponentsAsset =
      'assets/corp/module_components.json';
}
