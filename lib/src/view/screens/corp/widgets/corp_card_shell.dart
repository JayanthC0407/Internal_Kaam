import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_card_surface.dart';

/// The white, rounded, cyan-outlined panel every corporate dashboard card
/// sits in. Kept as one widget so all three panels share identical radius,
/// border and shadow — the design's cards are visually interchangeable.
class CorpCardShell extends StatelessWidget {
  const CorpCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DashboardCardSurface(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CorpColors.cardBorder(context)),
        boxShadow: [
          BoxShadow(
            color: CorpColors.cardShadow(context),
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Card title row — a heading with an optional trailing action, used by the
/// Quick Links and Account Summary panels.
class CorpCardHeader extends StatelessWidget {
  const CorpCardHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
