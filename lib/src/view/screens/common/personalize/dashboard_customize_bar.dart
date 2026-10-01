import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// "My dashboard · Customize" — the phone's way into Personalize Dashboard.
///
/// Wider screens reach Personalize from the top bar's settings menu; a
/// phone's header has no room for that menu (Retail's has none at all), so
/// the entry point sits right above the widgets it changes. Shared by both
/// dashboards.
class DashboardCustomizeBar extends StatelessWidget {
  const DashboardCustomizeBar({super.key, required this.onCustomize});

  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            // TODO(l10n): add to the ARB files.
            'My dashboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onCustomize,
          style: TextButton.styleFrom(
            foregroundColor: colors.brand,
            // A comfortable touch target without looking like a big button.
            minimumSize: const Size(48, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text(
            'Customize',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
