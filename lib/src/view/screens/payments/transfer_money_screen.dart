import 'package:flutter/material.dart';

import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/home_menu_button.dart';

/// "Transfer Money → Who are you sending money to?" Both branches
/// converge on the same Payment Details → Review → Authentication →
/// Submit → Confirmation flow; this screen only decides how the
/// beneficiary gets captured. Adhoc Payee additionally supports
/// Internal, Domestic, and International beneficiary types — that's
/// where the actual international transfer capability lives (see
/// [AdhocPayeeTransferScreen]), separate from the "International Low
/// Value Payment" product under Transfers.
class TransferMoneyScreen extends StatelessWidget {
  const TransferMoneyScreen({super.key, this.embedded = false, this.onBack});

  /// When true, runs as a Home tab (see [HomeDashboardScreen]) instead of a
  /// pushed full screen, so the drawer (mobile/tablet) / persistent sidebar
  /// (desktop) stays visible instead of being covered by a full-page route.
  final bool embedded;

  /// Returns to the Transfers tab. Only meaningful (and only supplied) when
  /// [embedded] — a pushed route just pops normally instead.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final textPrimary = HomeColors.textPrimary(context);
    final textSecondary = HomeColors.textSecondary(context);
    final brand = HomeColors.brand(context);

    // Grabbed before building this screen's own Scaffold below, so it
    // resolves to the ambient Home Scaffold (drawer) when embedded — the
    // Scaffold being built here would otherwise shadow it.
    final homeScaffold = embedded ? Scaffold.maybeOf(context) : null;

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: const Text('Transfer Money'),
        backgroundColor: HomeColors.bg(context),
        foregroundColor: textPrimary,
        elevation: 0,
        // A plain AppBar only auto-adds a back arrow when there's a route
        // to pop — embedded swaps tab content instead of pushing a route,
        // so without this, embedded left no way back to Transfers.
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
          child: ListView(
            children: [
              Text(
                'Who are you sending money to?',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: responsive.fontScale(phone: 20, tablet: 24),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose a saved payee or enter beneficiary details for a one-time transfer.',
                style: TextStyle(color: textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.lg),
                  leading: CircleAvatar(
                    backgroundColor: brand.withValues(alpha: 0.1),
                    child: Icon(Icons.person_outline_rounded, color: brand),
                  ),
                  title: const Text('Existing Payee'),
                  subtitle: const Text('Send to a payee you\'ve already added'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pushNamed(
                    RoutesConst.internalPaymentScreen,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.lg),
                  leading: CircleAvatar(
                    backgroundColor: brand.withValues(alpha: 0.1),
                    child: Icon(Icons.person_add_alt_1_rounded, color: brand),
                  ),
                  title: const Text('Adhoc Payee'),
                  subtitle: const Text('Internal, domestic or international — enter beneficiary details for a one-time transfer'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pushNamed(
                    RoutesConst.adhocPayeeTransferScreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
