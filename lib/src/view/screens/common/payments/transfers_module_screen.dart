import 'package:flutter/material.dart';

import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/common/payments/network_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';

/// The OBDX "Transfers" menu: its seven items, in the bank's order and
/// under the bank's names.
///
/// Each item calls back when [embedded] in the dashboard (so the side menu
/// stays), and otherwise pushes its own screen.
class TransfersModuleScreen extends StatelessWidget {
  const TransfersModuleScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onTransferTap,
    this.onOtherTransfersTap,
    this.onMultipleTransfersTap,
  });

  final bool embedded;
  final VoidCallback? onBack;

  /// Opens a payee transfer in [NetworkTransferMode] inside the dashboard.
  final ValueChanged<NetworkTransferMode>? onTransferTap;
  final VoidCallback? onOtherTransfersTap;
  final VoidCallback? onMultipleTransfersTap;

  @override
  Widget build(BuildContext context) {
    void transfer(NetworkTransferMode mode) {
      final tap = onTransferTap;
      if (tap != null) return tap(mode);
      Navigator.of(context).pushNamed(RoutesConst.networkTransferScreen, arguments: mode);
    }

    return PayMenuPage(
      title: 'Transfers',
      subtitle: 'Every way to send money',
      onBack: embedded ? onBack : null,
      tiles: [
        PayOptionTile(
          horizontal: true,
          icon: Icons.person_outline_rounded,
          title: 'Transfers - Existing Payee',
          subtitle: 'Pay a saved payee — within the bank, domestic or international',
          onTap: () => transfer(NetworkTransferMode.existingPayee),
        ),
        PayOptionTile(
          horizontal: true,
          icon: Icons.person_add_alt_1_outlined,
          title: 'Transfers - Adhoc Payee',
          subtitle: "Pay someone you haven't saved as a payee",
          onTap: () => transfer(NetworkTransferMode.adhocPayee),
        ),
        PayOptionTile(
          horizontal: true,
          icon: Icons.event_repeat_rounded,
          title: 'Repeat Transfers - Existing Payee',
          subtitle: 'Pay a saved payee on a schedule',
          onTap: () => transfer(NetworkTransferMode.repeatExistingPayee),
        ),
        PayOptionTile(
          horizontal: true,
          icon: Icons.update_rounded,
          title: 'Repeat Transfers - Adhoc Payee',
          subtitle: 'Pay someone new on a schedule',
          onTap: () => transfer(NetworkTransferMode.repeatAdhocPayee),
        ),
        PayOptionTile(
          horizontal: true,
          icon: Icons.more_horiz_rounded,
          title: 'Other Transfers',
          subtitle: 'Between your accounts and more',
          onTap: onOtherTransfersTap ??
              () => Navigator.of(context).pushNamed(RoutesConst.otherTransfersScreen),
        ),
        PayOptionTile(
          horizontal: true,
          icon: Icons.public_rounded,
          title: 'International Low Value Payment',
          subtitle: 'Fast, low-value payment abroad over SWIFT gpi',
          onTap: () => transfer(NetworkTransferMode.internationalLowValue),
        ),
        PayOptionTile(
          horizontal: true,
          icon: Icons.dynamic_feed_rounded,
          title: 'Multiple Transfers',
          subtitle: 'Pay several payees from one account',
          onTap: onMultipleTransfersTap ??
              () => Navigator.of(context).pushNamed(RoutesConst.multipleTransfersScreen),
        ),
      ],
    );
  }
}
