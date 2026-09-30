import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';

/// The Trade Finance menu tree, as the corporate user sees it:
///
/// ```
/// Trade Finance
/// └─ Letter of Credit
///    ├─ Import Letter of Credit
///    │  ├─ Initiate Letter of Credit
///    │  ├─ Amend Letter of Credit
///    │  └─ View Letter of Credit
///    └─ Export Letter of Credit
///       ├─ View Letter of Credit
///       ├─ LC Amendment Acceptance
///       ├─ Initiate Transfer LC
///       └─ Amend Transfer LC
/// ```
///
/// Mirrors `TRADE_FINANCE → letter-of-credit` in the environment's
/// `framework/json/menu/corporate.json`. The sidebar tree and the Trade
/// Finance landing page both render from this one definition.
enum LcMenuGroup {
  importLc('Import Letter of Credit', Icons.south_west_rounded),
  exportLc('Export Letter of Credit', Icons.north_east_rounded);

  const LcMenuGroup(this.label, this.icon);

  final String label;
  final IconData icon;

  List<LcMenuAction> get actions =>
      [for (final a in LcMenuAction.values) if (a.group == this) a];
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
  );

  const LcMenuAction(this.group, this.label, this.icon, this.description);

  final LcMenuGroup group;
  final String label;
  final IconData icon;
  final String description;

  /// Whether the user's `me/components` entitles them to this option.
  bool isAllowed(LcPermissions p) => switch (this) {
        LcMenuAction.importInitiate => p.initiate,
        LcMenuAction.importAmend => p.amend,
        LcMenuAction.importView => p.viewImport,
        LcMenuAction.exportView => p.viewExport,
        LcMenuAction.exportAmendmentAcceptance => p.amendmentAcceptance,
        LcMenuAction.exportInitiateTransfer => p.initiateTransfer,
        LcMenuAction.exportAmendTransfer => p.amendTransfer,
      };

  /// Breadcrumb from the module root down to this option.
  List<String> get breadcrumb =>
      ['Trade Finance', 'Letter of Credit', group.label, label];
}

extension LcMenuGroupPermissions on LcMenuGroup {
  List<LcMenuAction> allowedActions(LcPermissions p) =>
      [for (final a in actions) if (a.isAllowed(p)) a];
}
