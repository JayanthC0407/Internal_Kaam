import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import '../home_colors.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double _barHeight = 64;
  static const double _fabSize = 56;
  static const double _fabLift = 18;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final colors = (
      brand: HomeColors.brand(context),
      card: HomeColors.card(context),
      divider: HomeColors.divider(context),
      inactive: HomeColors.navInactive(context),
    );

    Widget item({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final active = selectedIndex == index;
      final color = active ? colors.brand : colors.inactive;
      return Expanded(
        child: InkWell(
          onTap: () => onSelected(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: colors.card,
      elevation: 8,
      shadowColor: const Color(0x14000000),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: _barHeight + _fabLift,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _barHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    border: Border(
                      top: BorderSide(color: colors.divider),
                    ),
                  ),
                  child: Row(
                    children: [
                      item(
                        index: 0,
                        icon: Icons.home_rounded,
                        label: l10n.home,
                      ),
                      item(
                        index: 1,
                        icon: Icons.pie_chart_outline_rounded,
                        label: l10n.insights,
                      ),
                      const SizedBox(width: _fabSize),
                      item(
                        index: 3,
                        icon: Icons.card_giftcard_rounded,
                        label: l10n.rewards,
                      ),
                      item(
                        index: 4,
                        icon: Icons.more_horiz_rounded,
                        label: l10n.more,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Center(
                  child: Material(
                    color: colors.brand,
                    shape: const CircleBorder(),
                    elevation: 4,
                    shadowColor: colors.brand.withValues(alpha: 0.2),
                    child: InkWell(
                      onTap: () => onSelected(2),
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: _fabSize,
                        height: _fabSize,
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
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
