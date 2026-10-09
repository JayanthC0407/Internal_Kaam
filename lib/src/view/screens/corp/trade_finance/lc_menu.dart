import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

/// The Trade Finance menu tree, as the corporate user sees it:
///
/// ```
/// Trade Finance
/// ├─ Letter of Credit
/// │  ├─ Import Letter of Credit
/// │  │  ├─ Initiate Letter of Credit
/// │  │  ├─ Amend Letter of Credit
/// │  │  └─ View Letter of Credit
/// │  └─ Export Letter of Credit
/// │     ├─ View Letter of Credit
/// │     ├─ LC Amendment Acceptance
/// │     ├─ View Bills
/// │     ├─ Initiate Transfer LC
/// │     └─ Amend Transfer LC
/// └─ Bank Guarantee
///    ├─ Inward Bank Guarantee/Stand By LC
///    │  ├─ View Bank Guarantee/Stand By LC
///    │  ├─ View Bank Kafalah/Stand By LC
///    │  ├─ Guarantee/Stand By LC Amend Acceptance
///    │  ├─ Kafalah/Stand By LC Amend Acceptance
///    │  ├─ Initiate Lodge Claim
///    │  └─ Initiate Lodge Claim-Islamic
///    └─ Outward Bank Guarantee/Stand By LC   (placeholder — see below)
/// ```
///
/// Mirrors `TRADE_FINANCE` in the environment's
/// `framework/json/menu/corporate.json`; the Inward Bank Guarantee options
/// and their labels are the OBDX web menu's (`inward_bank_guarantee_api.har`).
/// The sidebar tree renders from this one definition.
///
/// The enum names keep their original `Lc` prefix so existing call sites
/// stay put; they now cover every Trade Finance option, guarantees included.
enum TfMenuSection {
  letterOfCredit('Letter of Credit', Icons.description_outlined),
  bankGuarantee('Bank Guarantee', Icons.verified_user_outlined);

  const TfMenuSection(this.label, this.icon);

  final String label;
  final IconData icon;

  List<LcMenuGroup> get groups =>
      [for (final g in LcMenuGroup.values) if (g.section == this) g];
}

enum LcMenuGroup {
  importLc(
    TfMenuSection.letterOfCredit,
    'Import Letter of Credit',
    Icons.south_west_rounded,
  ),
  exportLc(
    TfMenuSection.letterOfCredit,
    'Export Letter of Credit',
    Icons.north_east_rounded,
  ),
  inwardGuarantee(
    TfMenuSection.bankGuarantee,
    'Inward Bank Guarantee/Stand By LC',
    Icons.call_received_rounded,
  ),

  /// No Outward capture yet, so this group holds a single placeholder
  /// option and is drawn as a plain menu row rather than a folder (see
  /// [isPlaceholder]). Add the real options here once they are captured.
  outwardGuarantee(
    TfMenuSection.bankGuarantee,
    'Outward Bank Guarantee/Stand By LC',
    Icons.call_made_rounded,
  );

  const LcMenuGroup(this.section, this.label, this.icon);

  final TfMenuSection section;
  final String label;
  final IconData icon;

  List<LcMenuAction> get actions =>
      [for (final a in LcMenuAction.values) if (a.group == this) a];

  /// A group whose only option is a placeholder is shown as one menu row
  /// that opens that placeholder, instead of a folder with one child.
  bool get isPlaceholder =>
      actions.length == 1 && actions.single.isPlaceholder;
}

enum LcMenuAction {
  importInitiate(
    LcMenuGroup.importLc,
    'Initiate Letter of Credit',
    Icons.add_circle_outline_rounded,
    'Apply for a new import LC, or continue a saved draft.',
  ),
  importAmend(
    LcMenuGroup.importLc,
    'Amend Letter of Credit',
    Icons.edit_note_rounded,
    'Change the amount, expiry or shipment terms of an active LC.',
  ),
  importView(
    LcMenuGroup.importLc,
    'View Letter of Credit',
    Icons.visibility_outlined,
    'Search your import LCs and see their details.',
  ),
  exportView(
    LcMenuGroup.exportLc,
    'View Letter of Credit',
    Icons.visibility_outlined,
    'LCs issued in your favour as beneficiary.',
  ),
  exportAmendmentAcceptance(
    LcMenuGroup.exportLc,
    'LC Amendment Acceptance',
    Icons.fact_check_outlined,
    'Accept or reject amendments made to your export LCs.',
  ),
  /// View Export Bill (manual ch. 14). Allowed with View Export LC: the
  /// bank's own component name for it was not in any capture.
  exportViewBills(
    LcMenuGroup.exportLc,
    'View Bills',
    Icons.receipt_long_outlined,
    'Bills you have presented under your export LCs.',
  ),
  exportInitiateTransfer(
    LcMenuGroup.exportLc,
    'Initiate Transfer LC',
    Icons.swap_horiz_rounded,
    'Transfer a transferable LC to a second beneficiary.',
  ),
  exportAmendTransfer(
    LcMenuGroup.exportLc,
    'Amend Transfer LC',
    Icons.published_with_changes_rounded,
    'Amend an LC you have transferred.',
  ),

  // ── Bank Guarantee · Inward (BG HAR) ────────────────────────────────

  /// `inward-guarantee-list` — BG #37/#44.
  inwardViewGuarantee(
    LcMenuGroup.inwardGuarantee,
    'View Bank Guarantee/Stand By LC',
    Icons.visibility_outlined,
    'Guarantees and standby LCs issued in your favour.',
  ),

  /// `inward-guarantee-list-islamic` — BG #46/#51.
  inwardViewKafalah(
    LcMenuGroup.inwardGuarantee,
    'View Bank Kafalah/Stand By LC',
    Icons.visibility_outlined,
    'Islamic kafalah and standby LCs issued in your favour.',
  ),

  /// `inward-guarantee-amendment` — BG #52/#62.
  inwardAmendAcceptance(
    LcMenuGroup.inwardGuarantee,
    'Guarantee/Stand By LC Amend Acceptance',
    Icons.fact_check_outlined,
    'Approve or reject amendments and cancellations to your guarantees.',
  ),

  /// `inward-guarantee-amendment-islamic` — BG #64/#67.
  inwardAmendAcceptanceKafalah(
    LcMenuGroup.inwardGuarantee,
    'Kafalah/Stand By LC Amend Acceptance',
    Icons.fact_check_outlined,
    'Approve or reject amendments and cancellations to your kafalah.',
  ),

  /// `lodge-claims` — BG #68/#76.
  inwardLodgeClaim(
    LcMenuGroup.inwardGuarantee,
    'Initiate Lodge Claim',
    Icons.request_quote_outlined,
    'Claim payment under a guarantee issued in your favour.',
  ),

  /// `lodge-claims-islamic` — BG #77/#84.
  inwardLodgeClaimIslamic(
    LcMenuGroup.inwardGuarantee,
    'Initiate Lodge Claim-Islamic',
    Icons.request_quote_outlined,
    'Claim payment under a kafalah issued in your favour.',
  ),

  // ── Bank Guarantee · Outward ────────────────────────────────────────

  /// Placeholder until the Outward screens are captured and built.
  outwardOverview(
    LcMenuGroup.outwardGuarantee,
    'Outward Bank Guarantee/Stand By LC',
    Icons.call_made_rounded,
    'Guarantees and standby LCs issued on your behalf.',
  );

  const LcMenuAction(this.group, this.label, this.icon, this.description);

  final LcMenuGroup group;
  final String label;
  final IconData icon;
  final String description;

  /// True for an option that has no screen of its own yet.
  bool get isPlaceholder => this == LcMenuAction.outwardOverview;

  /// Whether the user's `me/components` entitles them to this option.
  bool isAllowed(LcPermissions p) => switch (this) {
        LcMenuAction.importInitiate => p.initiate,
        LcMenuAction.importAmend => p.amend,
        LcMenuAction.importView => p.viewImport,
        LcMenuAction.exportView => p.viewExport,
        LcMenuAction.exportAmendmentAcceptance => p.amendmentAcceptance,
        LcMenuAction.exportViewBills => p.viewExport,
        LcMenuAction.exportInitiateTransfer => p.initiateTransfer,
        LcMenuAction.exportAmendTransfer => p.amendTransfer,
        LcMenuAction.inwardViewGuarantee => p.bgInwardView,
        LcMenuAction.inwardViewKafalah => p.bgInwardViewIslamic,
        LcMenuAction.inwardAmendAcceptance => p.bgInwardAmendAcceptance,
        LcMenuAction.inwardAmendAcceptanceKafalah =>
          p.bgInwardAmendAcceptanceIslamic,
        LcMenuAction.inwardLodgeClaim => p.bgLodgeClaim,
        LcMenuAction.inwardLodgeClaimIslamic => p.bgLodgeClaimIslamic,
        // Shown to anyone with some Trade Finance access, so the menu does
        // not hide Trade Finance entirely only because of this row.
        LcMenuAction.outwardOverview => p.any,
      };
}

extension LcMenuGroupPermissions on LcMenuGroup {
  List<LcMenuAction> allowedActions(LcPermissions p) =>
      [for (final a in actions) if (a.isAllowed(p)) a];
}
