import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_credit_facility_providers.dart';

/// Credit Facility Management in the corporate side menu, as OBDX lists it
/// (corporate.json 997-1053; nls/menu.js 548-563):
///
/// ```
/// Credit Facility Management
/// └─ Credit Facility
///    ├─ Facility Summary
///    └─ Facility Details
/// ```
///
/// Only built screens are listed; Overview and Collaterals follow.
enum CfPage {
  facilitySummary('Facility Summary', Icons.view_list_rounded),
  facilityDetails('Facility Details', Icons.description_outlined);

  const CfPage(this.label, this.icon);

  final String label;
  final IconData icon;

  /// The menu group the page sits under.
  static const creditFacilityGroup = 'Credit Facility';

  bool allowedBy(CfPermissions p) => switch (this) {
        CfPage.facilitySummary => p.facilitySummary,
        CfPage.facilityDetails => p.facilityDetails,
      };
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
