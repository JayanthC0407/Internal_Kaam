import 'package:flutter/material.dart';

import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// "Transfer Money → Who are you sending money to?" Both branches
/// converge on the same Payment Details → Review → Authentication →
/// Submit → Confirmation flow; this screen only decides how the
/// beneficiary gets captured. Adhoc Payee additionally supports
/// Internal, Domestic, and International beneficiary types — that's
/// where the actual international transfer capability lives (see
/// [AdhocPayeeTransferScreen]), separate from the "International Low
/// Value Payment" product under Transfers.
class TransferMoneyScreen extends StatelessWidget {
  const TransferMoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final textPrimary = HomeColors.textPrimary(context);
    final textSecondary = HomeColors.textSecondary(context);
    final brand = HomeColors.brand(context);

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: const Text('Transfer Money'),
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
