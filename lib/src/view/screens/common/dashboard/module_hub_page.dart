import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/home_menu_button.dart';

/// One page for a whole OBDX module, laid out like the Payments hub
/// (transfer_tab_screen.dart): a header, the module's functions as tiles,
/// and the OBDX items the app does not offer yet under "Coming soon"
/// (beside the tiles on wide screens, below them on a phone). The side menu
/// has a single entry, no dropdown, that opens it.
class ModuleHubPage extends StatelessWidget {
  const ModuleHubPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tiles,
    this.comingSoon = const [],
  });

  final String title;
  final String subtitle;

  /// [PayOptionTile]s, in the OBDX menu order.
  final List<Widget> tiles;

  /// OBDX menu items not built yet: icon and OBDX label.
  final List<(IconData, String)> comingSoon;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final wide = width >= kPayWideFlow;
          final phone = width < 600;
          final pad = phone ? 16.0 : 32.0;

          final grid = PayGrid(columns: phone ? 2 : 3, children: tiles);
          final soon = comingSoon.isEmpty ? null : _ComingSoon(items: comingSoon);

          return ListView(
            padding: EdgeInsets.fromLTRB(pad, phone ? 16 : 22, pad, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          // The desktop sidebar is always there; smaller
                          // layouts reach the drawer from here.
                          if (!responsive.isDesktop) ...[
                            HomeMenuButton(onTap: () => Scaffold.of(context).openDrawer()),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: HomeColors.textPrimary(context),
                                    fontSize: phone ? 26 : 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(subtitle, style: TextStyle(color: HomeColors.textSecondary(context))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (wide && soon != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: grid),
                            const SizedBox(width: 24),
                            SizedBox(width: 340, child: soon),
                          ],
                        )
                      else ...[
                        grid,
                        if (soon != null) ...[const SizedBox(height: 24), soon],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.items});

  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) => PaySection(
        title: AppLocalizations.of(context).moduleComingSoon,
        icon: Icons.schedule_rounded,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (icon, label) in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: HomeColors.bg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: HomeColors.divider(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: HomeColors.textSecondary(context)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
