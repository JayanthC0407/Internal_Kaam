/// Endpoint paths for the personalized dashboard, shared by every user type.
///
/// These used to live in `CorpApiConst`, which made the common dashboard
/// engine depend on the Corporate tree. Nothing here is Corporate-specific:
/// the same endpoints serve Retail and Corporate, differing only in the
/// `class`/`value` each user's own `me` response supplies.
///
/// Entry numbers refer to `widgets(corp).har` and `Home_widgets(corp).har`,
/// the captures the request and response shapes were taken from.
class DashboardApiConst {
  DashboardApiConst._();

  /// Dashboard configuration — `widgets(corp).har` entry #3.
  ///
  /// `class` and `value` are **not** constants: they come from the user's
  /// own `me` response (`dashboardResponse.dashboardDTOs[]`).
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
  /// file lacks.
  static const String moduleComponentsPath =
      '/framework/json/moduleComponents.json';

  /// Bundled fallback, used only when [moduleComponentsPath] cannot be
  /// fetched. Known to lag the environment.
  static const String moduleComponentsAsset =
      'assets/dashboard/module_components.json';
}
