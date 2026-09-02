import 'package:flutter/material.dart';

import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/coming_soon_tile.dart';

/// Transfers module. Consolidates transfer choices into user-oriented
/// journeys.
///
/// "International Low Value Payment" is the real OBDX name for this
/// capability and is only ever shown here — it must not be relabelled
/// "International Transfer" or surfaced outside Transfers, since the
/// broader "international transfer" experience is actually delivered via
/// Adhoc Payee Transfer (beneficiary type: Internal / Domestic /
/// International), not via this module.
class TransfersModuleScreen extends StatelessWidget {
  const TransfersModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final textPrimary = HomeColors.textPrimary(context);
    final brand = HomeColors.brand(context);

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: const Text('Transfers'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.lg),
                  leading: CircleAvatar(
                    backgroundColor: brand.withValues(alpha: 0.1),
                    child: Icon(Icons.send_rounded, color: brand),
                  ),
                  title: const Text('Transfer Money'),
                  subtitle: const Text('Existing or adhoc payee — internal, domestic or international'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pushNamed(
                    RoutesConst.transferMoneyScreen,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ComingSoonTile(
                  icon: Icons.replay_rounded,
                  title: 'Repeat Transfer',
                  subtitle: 'Existing or adhoc payee',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.lg),
                  leading: CircleAvatar(
                    backgroundColor: brand.withValues(alpha: 0.1),
                    child: Icon(Icons.public_rounded, color: brand),
                  ),
                  title: const Text('International Low Value Payment'),
                  subtitle: const Text('Low-value cross-border payment'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pushNamed(
                    RoutesConst.internationalPaymentScreen,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ComingSoonTile(
                  icon: Icons.dynamic_feed_rounded,
                  title: 'Multiple Transfers',
                  subtitle: 'Pay several beneficiaries at once',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ComingSoonTile(
                  icon: Icons.more_horiz_rounded,
                  title: 'Other Transfers',
                  subtitle: 'More transfer options',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
