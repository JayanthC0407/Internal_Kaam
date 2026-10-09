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

  /// View Export LC — the tabbed detail of one export LC.
  static const String exportLcDetailScreen = '/corp_export_lc_detail_screen';

  /// View Export Bill — one export bill.
  static const String exportBillDetailScreen =
      '/corp_export_bill_detail_screen';

  // ── Trade Finance · Bank Guarantee ─────────────────────────────────────

  /// One inward guarantee / kafalah.
  static const String bgDetailScreen = '/corp_bg_detail_screen';

  /// One amendment awaiting acceptance (read-only).
  static const String bgAmendmentScreen = '/corp_bg_amendment_screen';

  /// Review and send an approve / reject decision.
  static const String bgAcceptanceReviewScreen =
      '/corp_bg_acceptance_review_screen';

  /// Lodge a claim under one guarantee.
  static const String bgClaimScreen = '/corp_bg_claim_screen';

  /// Every corporate route name, used by `Routes` to decide whether to
  /// delegate a given settings name to [CorpRoutes].
  static const Set<String> all = {
    corpDashboardScreen,
    lcDetailScreen,
    lcInitiateScreen,
    lcAmendScreen,
    lcAcceptanceScreen,
    lcTransferScreen,
    exportLcDetailScreen,
    exportBillDetailScreen,
    bgDetailScreen,
    bgAmendmentScreen,
    bgAcceptanceReviewScreen,
    bgClaimScreen,
  };
}
