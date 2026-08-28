import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/web_navigation_sidebar.dart'
    show WebPayeeDestination;

/// The actual navigation menu — logo, destination list, Payee submenu,
/// security footer. Single source of truth for "what's in the app's main
/// nav", rendered two different ways depending on screen size:
///  - Mobile / tablet (no side panel): inside a [Drawer], opened via the
///    hamburger icon wired into [TopHeroSection] / the wide-tablet header.
///  - Desktop (persistent side panel): inside [WebNavigationSidebar], which
///    just adds the fixed/collapsible-width column chrome around this.
///
/// [BottomNav] is unrelated to this widget and keeps driving the mobile
/// bottom bar (home/insights/transfer/rewards/more) exactly as before.
class AppNavContent extends StatefulWidget {
  const AppNavContent({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.selectedPayeeDestination,
    this.onPayeeSelected,
    this.showLogo = true,
    this.collapsed = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final WebPayeeDestination? selectedPayeeDestination;
  final ValueChanged<WebPayeeDestination>? onPayeeSelected;

  /// The drawer variant can hide the logo block if the [Drawer] already has
  /// its own header — kept `true` by default so it matches the sidebar.
  final bool showLogo;

  /// Icon-only rail mode, used by the collapsed desktop [WebNavigationSidebar].
  /// Never `true` for the mobile [Drawer] — a collapsed drawer defeats the
  /// point of a drawer.
  final bool collapsed;

  static const _logoAsset = 'assets/images/demobank_logo.png';

  @override
  State<AppNavContent> createState() => _AppNavContentState();
}

class _AppNavContentState extends State<AppNavContent> {
  bool _payeeExpanded = false;

  @override
  void initState() {
    super.initState();
    _payeeExpanded = widget.selectedPayeeDestination != null;
  }

  @override
  void didUpdateWidget(covariant AppNavContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPayeeDestination != oldWidget.selectedPayeeDestination &&
        widget.selectedPayeeDestination != null) {
      _payeeExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final collapsed = widget.collapsed;
    final destinations = [
      (l10n.home, Icons.home_rounded),
      (l10n.insights, Icons.pie_chart_outline_rounded),
      (l10n.transfer, Icons.swap_horiz_rounded),
      (l10n.rewards, Icons.card_giftcard_rounded),
      (l10n.more, Icons.more_horiz_rounded),
    ];
    final showPayee = widget.onPayeeSelected != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(collapsed ? 10 : 16, 22, collapsed ? 10 : 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showLogo && !collapsed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    AppNavContent._logoAsset,
                    width: 166,
                    height: 72,
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.home,
                    style: TextStyle(
                      color: HomeColors.textSecondary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
          if (collapsed) const SizedBox(height: 44),
          for (var i = 0; i < destinations.length; i++) ...[
            _NavDestination(
              label: destinations[i].$1,
              icon: destinations[i].$2,
              selected: widget.selectedIndex == i,
              collapsed: collapsed,
              onTap: () => widget.onSelected(i),
            ),
            const SizedBox(height: 6),
          ],
          if (showPayee) ...[
            _NavDestination(
              label: 'Payee',
              icon: Icons.people_alt_outlined,
              selected: widget.selectedPayeeDestination != null,
              collapsed: collapsed,
              trailing: collapsed
                  ? null
                  : Icon(
                      _payeeExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: widget.selectedPayeeDestination != null
                          ? Colors.white
                          : HomeColors.textSecondary(context),
                    ),
              onTap: collapsed
                  ? () => widget.onPayeeSelected!(WebPayeeDestination.manage)
                  : () => setState(() => _payeeExpanded = !_payeeExpanded),
            ),
            if (_payeeExpanded && !collapsed) ...[
              const SizedBox(height: 3),
              _SubDestination(
                label: 'Manage Payee',
                icon: Icons.manage_accounts_outlined,
                selected:
                    widget.selectedPayeeDestination == WebPayeeDestination.manage,
                onTap: () => widget.onPayeeSelected!(WebPayeeDestination.manage),
              ),
              const SizedBox(height: 3),
              _SubDestination(
                label: 'Add Account Payee',
                icon: Icons.person_add_alt_1_outlined,
                selected:
                    widget.selectedPayeeDestination == WebPayeeDestination.add,
                onTap: () => widget.onPayeeSelected!(WebPayeeDestination.add),
              ),
            ],
            const SizedBox(height: 6),
          ],
          const Spacer(),
          if (collapsed)
            Center(
              child: Tooltip(
                message: l10n.security,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: HomeColors.brand(context).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: HomeColors.brand(context).withValues(alpha: 0.13),
                    ),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: HomeColors.brand(context),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: HomeColors.brand(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: HomeColors.brand(context).withValues(alpha: 0.13),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: HomeColors.brand(context),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      l10n.security,
                      style: TextStyle(
                        color: HomeColors.textSecondary(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubDestination extends StatelessWidget {
  const _SubDestination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final foreground = selected ? brand : HomeColors.textSecondary(context);
    return Material(
      color: selected ? brand.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.only(left: 28, right: 12, top: 9, bottom: 9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final foreground = selected ? Colors.white : HomeColors.textSecondary(context);
    final background = selected ? brand : Colors.transparent;
    final iconWidget = Icon(icon, size: 21, color: foreground);

    if (collapsed) {
      return Tooltip(
        message: label,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(child: iconWidget),
            ),
          ),
        ),
      );
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
