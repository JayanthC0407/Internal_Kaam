import 'package:flutter/material.dart';

import 'package:ubci_bank/src/core/theme/app_radius.dart';
import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/coming_soon_tile.dart';

/// Payments Home. Cross-checked against the real OBDX Payments menu:
///
/// - "Favorites" and "Saved Drafts" are flat, top-level items in the real
///   menu (no submenu arrow) — they live in Quick Actions here.
/// - "Repeat" is not a real top-level item (only "Repeat Transfers -
///   Existing/Adhoc Payee" inside Transfers), so it isn't a Quick Action.
/// - "Payee" is a real submenu (Manage Payees / Add Account Payee / Add
///   Draft Payee / Add Peer To Peer Payee) — routes to [PayeeHubScreen].
/// - "International Low Value Payment" is NOT surfaced here. It's a
///   narrow product that only lives inside the Transfers module. The
///   actual international transfer capability is reached via
///   Transfers → Transfer Money → Adhoc Payee (beneficiary type:
///   International), not from a shortcut on this screen.
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
        child: ListView(
          children: [
            Text(
              'Payments',
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

            // --- Quick Actions ---
            const _SectionHeader('Quick Actions'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.send_rounded,
                    label: 'Transfer',
                    onTap: () => Navigator.of(context)
                        .pushNamed(RoutesConst.transferMoneyScreen),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.people_alt_outlined,
                    label: 'Payee',
                    onTap: () => Navigator.of(context)
                        .pushNamed(RoutesConst.payeeHubScreen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.star_border_rounded,
                    label: 'Favorites',
                    onTap: () => _comingSoon(context, 'Favorites'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.drafts_outlined,
                    label: 'Saved Drafts',
                    onTap: () => _comingSoon(context, 'Saved Drafts'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // --- Payment Services ---
            const _SectionHeader('Payment Services'),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.all(AppSpacing.lg),
                    leading: CircleAvatar(
                      backgroundColor: brand.withValues(alpha: 0.1),
                      child: Icon(Icons.swap_horiz_rounded, color: brand),
                    ),
                    title: const Text('Transfers'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context)
                        .pushNamed(RoutesConst.transfersModuleScreen),
                  ),
                  Divider(height: 1, color: HomeColors.divider(context), indent: 68),
                  ListTile(
                    contentPadding: const EdgeInsets.all(AppSpacing.lg),
                    leading: CircleAvatar(
                      backgroundColor: brand.withValues(alpha: 0.1),
                      child: Icon(Icons.people_alt_outlined, color: brand),
                    ),
                    title: const Text('Payee'),
                    subtitle: const Text('Manage payees, add account/draft/P2P payees'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context)
                        .pushNamed(RoutesConst.payeeHubScreen),
                  ),
                  Divider(height: 1, color: HomeColors.divider(context), indent: 68),
                  const ComingSoonTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'Payment Inquiries',
                    subtitle: 'Payment status and repeat-transfer inquiries',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // --- More ---
            const _SectionHeader('More'),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: [
                  const ComingSoonTile(icon: Icons.description_outlined, title: 'Demand Draft'),
                  Divider(height: 1, color: HomeColors.divider(context), indent: 68),
                  const ComingSoonTile(icon: Icons.dynamic_feed_rounded, title: 'Multiple Transfers'),
                  Divider(height: 1, color: HomeColors.divider(context), indent: 68),
                  const ComingSoonTile(icon: Icons.verified_outlined, title: 'Positive Pay'),
                  Divider(height: 1, color: HomeColors.divider(context), indent: 68),
                  const ComingSoonTile(icon: Icons.groups_outlined, title: 'Debtors'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: HomeColors.textSecondary(context),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final textPrimary = HomeColors.textPrimary(context);

    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            children: [
              Icon(icon, color: brand),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
