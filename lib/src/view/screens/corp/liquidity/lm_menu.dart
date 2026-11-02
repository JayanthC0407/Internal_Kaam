import 'package:flutter/material.dart';
import 'package:demo_bank/src/view/providers/corp/corp_liquidity_providers.dart';

/// Liquidity Management in the corporate side menu, as OBDX lists it
/// (corporate.json 815-843; nls/menu.js 87-93):
///
/// ```
/// Liquidity Management
/// ├─ Overview
/// └─ Charges Inquiry
/// ```
///
/// Only built screens are listed. Simulation, Create
/// Structure, Structure List and Log Monitors are out of scope.
enum LmPage {
  /// The module dashboard (`type: MODULE`).
  overview('Overview', Icons.dashboard_outlined),
  chargesInquiry('Charges Inquiry', Icons.receipt_long_outlined);

  const LmPage(this.label, this.icon);

  final String label;
  final IconData icon;

  bool allowedBy(LmPermissions p) => switch (this) {
        LmPage.overview => p.overview,
        LmPage.chargesInquiry => p.chargesInquiry,
      };
}
