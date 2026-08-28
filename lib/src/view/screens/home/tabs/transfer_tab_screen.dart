import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_radius.dart';
import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

class TransferTabScreen extends StatelessWidget {
  const TransferTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final textPrimary = HomeColors.textPrimary(context);
    final textSecondary = HomeColors.textSecondary(context);
    final brand = HomeColors.brand(context);

    return SafeArea(
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
              'Transfer',
              style: TextStyle(
                color: textPrimary,
                fontSize: responsive.fontScale(phone: 28, tablet: 32),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Manage payees and transfer money securely.',
              style: TextStyle(color: textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppSpacing.lg),
                leading: CircleAvatar(
                  backgroundColor: brand.withValues(alpha: 0.1),
                  child: Icon(Icons.people_alt_outlined, color: brand),
                ),
                title: const Text('Payees'),
                subtitle: const Text('View, search and add bank account payees'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pushNamed(
                  RoutesConst.payeesScreen,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: brand),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Fund transfer screens can be connected here using the same OBDX session and API layer.',
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
