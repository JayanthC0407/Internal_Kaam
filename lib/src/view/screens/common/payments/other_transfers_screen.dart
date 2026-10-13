import 'package:flutter/material.dart';

import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';

/// "Other Transfers" — transfer types beside payee transfers. Between My
/// Accounts is live; demand drafts and peer-to-peer exist on the OBDX
/// server (`/payments/drafts`, `/payments/transfers/peerToPeer`) but are not
/// built in the app yet.
class OtherTransfersScreen extends StatelessWidget {
  const OtherTransfersScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onOwnAccountTap,
  });

  final bool embedded;
  final VoidCallback? onBack;

  /// Opens Between My Accounts inside the dashboard when embedded.
  final VoidCallback? onOwnAccountTap;

  @override
  Widget build(BuildContext context) {
    return PayMenuPage(
      title: 'Other Transfers',
      subtitle: 'More ways to move money',
      onBack: embedded ? onBack : null,
      tiles: [
        PayOptionTile(
          horizontal: true,
          icon: Icons.sync_alt_rounded,
          title: 'My Accounts',
          subtitle: 'Move money between your own accounts',
          onTap: onOwnAccountTap ??
              () => Navigator.of(context).pushNamed(RoutesConst.ownAccountTransferScreen),
        ),
        const PayOptionTile(
          horizontal: true,
          comingSoon: true,
          icon: Icons.receipt_long_outlined,
          title: 'Demand Draft',
          subtitle: 'Issue a domestic or international draft',
          onTap: null,
        ),
        const PayOptionTile(
          horizontal: true,
          comingSoon: true,
          icon: Icons.alternate_email_rounded,
          title: 'Peer To Peer',
          subtitle: 'Pay someone by email or mobile number',
          onTap: null,
        ),
      ],
    );
  }
}
