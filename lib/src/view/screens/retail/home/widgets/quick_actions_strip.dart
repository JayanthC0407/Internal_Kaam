import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// Phone Home "Quick Actions": four fixed white tiles with a brand icon and
/// a label under each, on the light Home page. Not customisable.
///
/// A tile only OPENS the start screen of its normal banking flow — it
/// never carries an amount, a payee or a submit action, so every review,
/// OTP and approval step still runs. Scan & Pay, Bill and Saving are not
/// built yet and say "Coming soon".
class QuickActionsStrip extends StatelessWidget {
  const QuickActionsStrip({super.key, this.onTransfer});

  /// Opens Transfer.
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void comingSoon(String label) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label · ${l10n.featureComingSoon}')),
      );
    }

    final tiles = <(IconData, String, VoidCallback)>[
      (
        Icons.currency_exchange_rounded,
        l10n.transfer,
        onTransfer ?? () => comingSoon(l10n.transfer),
      ),
      (
        Icons.qr_code_scanner_rounded,
        l10n.qaScanPay,
        () => comingSoon(l10n.qaScanPay),
      ),
      (Icons.receipt_long_rounded, l10n.qaBill, () => comingSoon(l10n.qaBill)),
      (Icons.savings_outlined, l10n.qaSaving, () => comingSoon(l10n.qaSaving)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.qaTitle,
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (icon, label, onTap) in tiles)
              Expanded(
                child: _QuickActionTile(icon: icon, label: label, onTap: onTap),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final brand = colors.brand;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: brand.withValues(alpha: 0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: brand.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: brand, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
