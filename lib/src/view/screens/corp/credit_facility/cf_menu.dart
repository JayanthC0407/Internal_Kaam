import 'package:flutter/material.dart';
import 'package:demo_bank/src/view/providers/corp/corp_credit_facility_providers.dart';

/// Credit Facility Management in the corporate side menu, as OBDX lists it
/// (corporate.json 997-1053; nls/menu.js 548-563):
///
/// ```
/// Credit Facility Management
/// ├─ Overview
/// ├─ Credit Facility
/// │  ├─ Facility Summary
/// │  └─ Facility Details
/// └─ Collaterals
///    ├─ Collateral Summary
///    └─ Collateral Details
/// ```
///
/// Only built screens are listed.
enum CfPage {
  /// The module dashboard (`type: MODULE`), directly under the root.
  overview('Overview', Icons.dashboard_outlined, null),
  facilitySummary('Facility Summary', Icons.view_list_rounded, CfMenuGroup.credit),
  facilityDetails('Facility Details', Icons.description_outlined, CfMenuGroup.credit),
  collateralSummary('Collateral Summary', Icons.inventory_2_outlined, CfMenuGroup.collaterals),
  collateralDetails('Collateral Details', Icons.article_outlined, CfMenuGroup.collaterals);

  const CfPage(this.label, this.icon, this.group);

  final String label;
  final IconData icon;
  /// Null for [overview], which is not in a group.
  final CfMenuGroup? group;

  bool allowedBy(CfPermissions p) => switch (this) {
        CfPage.overview => p.overview,
        CfPage.facilitySummary => p.facilitySummary,
        CfPage.facilityDetails => p.facilityDetails,
        CfPage.collateralSummary => p.collateralGroups,
        CfPage.collateralDetails => p.collateralDetails,
      };
}

/// The two groups under Credit Facility Management; [name] is the menu id
/// segment.
enum CfMenuGroup {
  credit('Credit Facility', Icons.request_quote_outlined),
  collaterals('Collaterals', Icons.shield_moon_outlined);

  const CfMenuGroup(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Facility Details tabs (OBDX ids DRAFTS, COVENANTS, UTILIZATION; labels
/// hard-coded in facility-details/hooks.js:162-181).
enum CfDetailTab {
  collateralGroups('Collateral Groups'),
  covenants('Covenants'),
  transactionSummary('Transaction Summary');

  const CfDetailTab(this.label);

  final String label;

  bool allowedBy(CfPermissions p) => switch (this) {
        CfDetailTab.collateralGroups => p.collateralGroups,
        CfDetailTab.covenants => true,
        CfDetailTab.transactionSummary => p.utilization,
      };
}

/// What OBDX opens through `segment-container` (Amend Facility, Add Sub
/// Facility) is not built.
const cfComingSoon = 'This feature will be available soon.';
