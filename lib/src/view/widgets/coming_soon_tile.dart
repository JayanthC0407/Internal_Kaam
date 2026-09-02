import 'package:flutter/material.dart';

import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// A payments-menu row for a feature not implemented yet (Repeat
/// Transfer, Multiple Transfers, Payment Inquiries, Saved Drafts,
/// Favorites, Demand Draft, Positive Pay, Debtors, Other Transfers).
/// Renders identically to a live entry but shows a lightweight
/// "coming soon" notice on tap instead of navigating, so the
/// information architecture is fully visible without implying these are
/// wired up.
class ComingSoonTile extends StatelessWidget {
  const ComingSoonTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool dense;

  void _notify(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = HomeColors.textSecondary(context);
    return ListTile(
      dense: dense,
      contentPadding: dense
          ? const EdgeInsets.symmetric(horizontal: 4)
          : const EdgeInsets.all(16),
      leading: Icon(icon, color: textSecondary),
      title: Text(
        title,
        style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(color: textSecondary)),
      trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
      onTap: () => _notify(context),
    );
  }
}
