import 'package:flutter/material.dart';

import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/home_menu_button.dart';

/// Payee module hub — mirrors the real OBDX "Payee" submenu: Manage
/// Payees, Add Account Payee, Add Draft Payee, Add Peer To Peer Payee.
/// All four now have real screens wired up.
class PayeeHubScreen extends StatelessWidget {
  const PayeeHubScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onManagePayeesTap,
    this.onAddAccountPayeeTap,
    this.onAddDraftPayeeTap,
    this.onAddPeerToPeerPayeeTap,
  });

  /// When true, runs as a Home tab (see [HomeDashboardScreen]) instead of a
  /// pushed full screen, so the drawer (mobile/tablet) / persistent sidebar
  /// (desktop) stays visible instead of being covered by a full-page route.
  final bool embedded;

  /// Returns to the Transfer tab. Only meaningful (and only supplied) when
  /// [embedded] — a pushed route just pops normally instead.
  final VoidCallback? onBack;

  /// Each opens the corresponding screen as another embedded Home tab
  /// instead of pushing a route — same reasoning as [onBack]. All four
  /// fall back to pushing their route when not supplied (e.g. if this
  /// screen is ever used outside Home's tabs).
  final VoidCallback? onManagePayeesTap;
  final VoidCallback? onAddAccountPayeeTap;
  final VoidCallback? onAddDraftPayeeTap;
  final VoidCallback? onAddPeerToPeerPayeeTap;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final textPrimary = HomeColors.textPrimary(context);
    final brand = HomeColors.brand(context);

    // Grabbed before building this screen's own Scaffold below, so it
    // resolves to the ambient Home Scaffold (drawer) when embedded — the
    // Scaffold being built here would otherwise shadow it.
    final homeScaffold = embedded ? Scaffold.maybeOf(context) : null;

    final items = <_PayeeHubItem>[
      _PayeeHubItem(
        icon: Icons.manage_accounts_outlined,
        title: 'Manage Payees',
        subtitle: 'View, search and manage saved payees',
        route: RoutesConst.payeesScreen,
        onTap: onManagePayeesTap,
      ),
      _PayeeHubItem(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Add Account Payee',
        subtitle: 'Add a same-bank account payee',
        route: RoutesConst.addBankAccountPayeeScreen,
        onTap: onAddAccountPayeeTap,
      ),
      _PayeeHubItem(
        icon: Icons.description_outlined,
        title: 'Add Draft Payee',
        subtitle: 'Add a payee for demand drafts',
        route: RoutesConst.addDemandDraftPayeeScreen,
        onTap: onAddDraftPayeeTap,
      ),
      _PayeeHubItem(
        icon: Icons.swap_horizontal_circle_outlined,
        title: 'Add Peer To Peer Payee',
        subtitle: 'Add a mobile-number or wallet payee',
        route: RoutesConst.addPeerToPeerPayeeScreen,
        onTap: onAddPeerToPeerPayeeTap,
      ),
    ];

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: const Text('Payee'),
        backgroundColor: HomeColors.bg(context),
        foregroundColor: textPrimary,
        elevation: 0,
        // A plain AppBar only auto-adds a back arrow when there's a route
        // to pop — embedded swaps tab content instead of pushing a route,
        // so without this, embedded left no way back to the Transfer tab.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: embedded ? onBack : () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (embedded && !responsive.isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: HomeMenuButton(
                onTap: () => homeScaffold?.openDrawer(),
              ),
            ),
        ],
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
          child: SingleChildScrollView(
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
                      onTap: items[i].onTap ??
                          () => Navigator.of(context).pushNamed(items[i].route),
                    ),
                  ],
                ],
              ),
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final VoidCallback? onTap;
}
