import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Segmented currency selector shown wherever loan totals are aggregated
/// (dashboard tracker card, "Loans & Finances" summary banners) — only
/// meaningful once a customer holds loans in more than one currency, since
/// a single currency has nothing to switch between.
class LoanCurrencyTabs extends StatelessWidget {
  const LoanCurrencyTabs({
    super.key,
    required this.currencies,
    required this.selected,
    required this.onChanged,
    this.dense = false,
    this.light = false,
  });

  final List<String> currencies;
  final String selected;
  final ValueChanged<String> onChanged;

  /// Smaller padding/text for tight spaces like the dashboard card.
  final bool dense;

  /// Use light (white-on-brand) styling for placement on a colored/gradient
  /// background, e.g. the outstanding-balance banner.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final height = dense ? 28.0 : 32.0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: currencies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final currency = currencies[index];
          final isSelected = currency == selected;
          return _CurrencyChip(
            label: currency,
            selected: isSelected,
            dense: dense,
            light: light,
            onTap: isSelected
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged(currency);
                  },
          );
        },
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.label,
    required this.selected,
    required this.dense,
    required this.light,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dense;
  final bool light;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final Color border;

    if (light) {
      background = selected ? Colors.white : Colors.white.withValues(alpha: 0.14);
      foreground = selected ? HomeColors.brand(context) : Colors.white;
      border = Colors.white.withValues(alpha: selected ? 0 : 0.4);
    } else {
      background =
          selected ? HomeColors.brand(context) : HomeColors.card(context);
      foreground = selected ? Colors.white : HomeColors.textSecondary(context);
      border = selected ? Colors.transparent : HomeColors.divider(context);
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
