import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Opens the Home [Scaffold]'s drawer from a screen embedded inside Home's
/// tab system that (unlike Home itself) has no header row of its own to put
/// a menu button in — e.g. [TransferTabScreen], [TransfersModuleScreen].
///
/// Must only be used where an ancestor `Scaffold` with a `drawer:` is
/// guaranteed — i.e. only when the screen is running `embedded: true`
/// inside `HomeDashboardScreen`'s tab switch, never when it's pushed as its
/// own standalone route (there is no drawer to open there).
///
/// Mirrors the icon used by `MobileDashboardHeaderRow` /
/// `WebDashboardHeaderBar` on Home so it reads as the same control
/// wherever it appears.
class HomeMenuButton extends StatelessWidget {
  const HomeMenuButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.menu_rounded,
            size: 20,
            color: HomeColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
