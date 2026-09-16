import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';

/// The corporate dashboard's main navigation destinations, in the order the
/// design lists them.
///
/// Only [home] has a built surface today; every other destination renders
/// the corporate shell's own placeholder panel (see
/// `CorpDashboardScreen._buildDestination`) so the sidebar, header and
/// session handling stay live while those modules are built out.
enum CorpNavDestination {
  loan('Loan', Icons.savings_outlined),
  home('Home', Icons.home_outlined),
  accounts('Accounts', Icons.account_balance_outlined),
  transfer('Transfer', Icons.swap_horiz_rounded),
  bill('Bill', Icons.receipt_long_outlined),
  statements('Statements', Icons.description_outlined),
  creditCard('Credit Card', Icons.credit_card_outlined),
  insurance('Insurance', Icons.shield_outlined);

  const CorpNavDestination(this.label, this.icon);

  // TODO(l10n): move these labels into AppLocalizations once translated
  // strings exist for every supported locale (the Retail nav has the same
  // pending TODO for its own product labels).
  final String label;
  final IconData icon;
}

/// The navigation menu itself — brand logo + destination list. Single
/// source of truth for the corporate nav, rendered two ways depending on
/// viewport: inside [CorpNavigationSidebar] on desktop, and inside a
/// [Drawer] on phone / tablet.
class CorpNavContent extends StatelessWidget {
  const CorpNavContent({
    super.key,
    required this.selected,
    required this.onSelected,
    this.collapsed = false,
    this.showLogo = true,
    this.toggleButton,
  });

  final CorpNavDestination selected;
  final ValueChanged<CorpNavDestination> onSelected;

  /// Icon-only rail mode for the collapsed desktop sidebar.
  final bool collapsed;

  final bool showLogo;

  /// The sidebar's collapse/expand control, laid out inline next to the
  /// logo (or centred above the icons when collapsed). `null` omits it,
  /// which is what the [Drawer] wants.
  final Widget? toggleButton;

  static const _logoAsset = 'assets/images/demobank_logo.png';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        collapsed ? 10 : 14,
        18,
        collapsed ? 10 : 14,
        18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLogo && !collapsed)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Image.asset(
                      _logoAsset,
                      height: 52,
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (toggleButton != null) ...[
                    const SizedBox(width: 6),
                    SizedBox(height: 52, child: Center(child: toggleButton)),
                  ],
                ],
              ),
            ),
          if (collapsed) ...[
            if (toggleButton != null) ...[
              Center(child: toggleButton),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 40),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final destination in CorpNavDestination.values) ...[
                    _CorpNavRow(
                      destination: destination,
                      selected: destination == selected,
                      collapsed: collapsed,
                      onTap: () => onSelected(destination),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single nav row. The design marks the active destination with a tinted
/// fill plus a brand accent bar on the leading edge (rather than Retail's
/// fully-filled pill), so the corporate nav gets its own row widget.
class _CorpNavRow extends StatelessWidget {
  const _CorpNavRow({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final CorpNavDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    final foreground =
        selected ? brand : CorpColors.textSecondary(context);
    final background =
        selected ? CorpColors.navSelectedBg(context) : Colors.transparent;
    final icon = Icon(destination.icon, size: 20, color: foreground);

    final row = Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 12,
            vertical: 12,
          ),
          child: collapsed
              ? Center(child: icon)
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? CorpColors.textPrimary(context)
                              : foreground,
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    final accented = Stack(
      children: [
        row,
        if (selected)
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: brand,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );

    if (!collapsed) return accented;
    return Tooltip(message: destination.label, child: accented);
  }
}
