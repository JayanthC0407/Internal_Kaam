import 'package:flutter/material.dart';

import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Payee module hub — mirrors the real OBDX "Payee" submenu: Manage
/// Payees, Add Account Payee, Add Draft Payee, Add Peer To Peer Payee.
/// All four now have real screens wired up.
class PayeeHubScreen extends StatelessWidget {
  const PayeeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final textPrimary = HomeColors.textPrimary(context);
    final brand = HomeColors.brand(context);

    final items = <_PayeeHubItem>[
      _PayeeHubItem(
        icon: Icons.manage_accounts_outlined,
        title: 'Manage Payees',
        subtitle: 'View, search and manage saved payees',
        route: RoutesConst.payeesScreen,
      ),
      _PayeeHubItem(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Add Account Payee',
        subtitle: 'Add a same-bank account payee',
        route: RoutesConst.addBankAccountPayeeScreen,
      ),
      _PayeeHubItem(
        icon: Icons.description_outlined,
        title: 'Add Draft Payee',
        subtitle: 'Add a payee for demand drafts',
        route: RoutesConst.addDemandDraftPayeeScreen,
      ),
      _PayeeHubItem(
        icon: Icons.swap_horizontal_circle_outlined,
        title: 'Add Peer To Peer Payee',
        subtitle: 'Add a mobile-number or wallet payee',
        route: RoutesConst.addPeerToPeerPayeeScreen,
      ),
    ];

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: const Text('Payee'),
        backgroundColor: HomeColors.bg(context),
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 900,
          padding: EdgeInsets.fromLTRB(
            responsive.isPhone ? AppSpacing.lg : AppSpacing.xxxl,
            AppSpacing.xl,
            responsive.isPhone ? AppSpacing.lg : AppSpacing.xxxl,
            AppSpacing.xxxl,
          ),
          child: Card(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: HomeColors.divider(context), indent: 68),
                  ListTile(
                    contentPadding: const EdgeInsets.all(AppSpacing.lg),
                    leading: CircleAvatar(
                      backgroundColor: brand.withValues(alpha: 0.1),
                      child: Icon(items[i].icon, color: brand),
                    ),
                    title: Text(items[i].title),
                    subtitle: Text(items[i].subtitle),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pushNamed(items[i].route),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayeeHubItem {
  const _PayeeHubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
