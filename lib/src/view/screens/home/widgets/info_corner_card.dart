import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

class _InfoItem {
  const _InfoItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const _kInfoItems = [
  _InfoItem(Icons.star_border_rounded, 'Rates'),
  _InfoItem(Icons.calendar_month_outlined, 'Holiday Calendar'),
  _InfoItem(Icons.calculate_outlined, 'Calculator'),
  _InfoItem(Icons.menu_book_outlined, 'Manual'),
];

/// "Info Corner" strip at the bottom of the Home dashboard Overview tab.
/// Placeholder actions, matching the "coming soon" pattern used elsewhere.
class InfoCornerCard extends StatelessWidget {
  const InfoCornerCard({super.key});

  void _handleTap(BuildContext context, String label) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label \u00b7 ${l10n.featureComingSoon}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Info Corner',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _kInfoItems
                .map(
                  (item) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _handleTap(context, item.label),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 22,
                            color: HomeColors.brand(context),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: HomeColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
