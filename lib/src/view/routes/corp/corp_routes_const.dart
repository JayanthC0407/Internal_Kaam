/// Route names for the Corporate (`corporateuser`) surfaces.
///
/// Kept separate from the shared [RoutesConst] so corporate screens can be
/// added without growing the retail route table. Generation for these names
/// lives in `CorpRoutes.onGenerateRoute`, which the app's main
/// `Routes.onGenerateRoutes` delegates to.
class CorpRoutesConst {
  CorpRoutesConst._();

  static const String corpDashboardScreen = '/corp_dashboard_screen';

  // ── Trade Finance · Letter of Credit ──────────────────────────────────
  static const String lcDetailScreen = '/corp_lc_detail_screen';
  static const String lcInitiateScreen = '/corp_lc_initiate_screen';
  static const String lcAmendScreen = '/corp_lc_amend_screen';
  static const String lcAcceptanceScreen = '/corp_lc_acceptance_screen';
  static const String lcTransferScreen = '/corp_lc_transfer_screen';

  /// Every corporate route name, used by `Routes` to decide whether to
  /// delegate a given settings name to [CorpRoutes].
  static const Set<String> all = {
    corpDashboardScreen,
    lcDetailScreen,
    lcInitiateScreen,
    lcAmendScreen,
    lcAcceptanceScreen,
    lcTransferScreen,
  };
}
