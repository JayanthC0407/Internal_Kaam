import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/app_nav_content.dart';

enum WebPayeeDestination { manage, add, addDemandDraft, addPeerToPeer }

/// "Accounts" ▸ CASA / Loans — both are one-shot navigations (they push a
/// full screen rather than swapping embedded dashboard content), so unlike
/// [WebPayeeDestination] there's no need to track which one stays "selected"
/// across rebuilds; see [AppNavContent] for the expand/collapse-only state.
enum WebAccountsDestination { casa, loans }

/// Persistent desktop side panel. On mobile/tablet the same menu content
/// ([AppNavContent]) is shown inside a [Drawer] instead — see
/// [HomeDashboardScreen]'s `drawer:`. [BottomNav] remains the dedicated
/// mobile bottom bar and is unrelated to this widget.
///
/// Collapsible: a toggle button pinned at the top switches between the full
/// 236px panel (icons + labels) and a 76px icon-only rail. The toggle stays
/// visible in both states so the panel can always be re-expanded.
class WebNavigationSidebar extends StatefulWidget {
  const WebNavigationSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.selectedAccountsDestination,
    this.selectedPayeeDestination,
    this.onPayeeSelected,
    this.onAccountsSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final WebPayeeDestination? selectedPayeeDestination;
  final WebAccountsDestination? selectedAccountsDestination;
  final ValueChanged<WebPayeeDestination>? onPayeeSelected;
  final ValueChanged<WebAccountsDestination>? onAccountsSelected;

  @override
  State<WebNavigationSidebar> createState() => _WebNavigationSidebarState();
}

class _WebNavigationSidebarState extends State<WebNavigationSidebar> {
  static const double _expandedWidth = 236;
  static const double _collapsedWidth = 76;

  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: _collapsed ? _collapsedWidth : _expandedWidth,
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        border: Border(
          right: BorderSide(color: HomeColors.divider(context)),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            AppNavContent(
              selectedIndex: widget.selectedIndex,
              onSelected: widget.onSelected,
              selectedAccountsDestination: widget.selectedAccountsDestination,
              selectedPayeeDestination: widget.selectedPayeeDestination,
              onPayeeSelected: widget.onPayeeSelected,
              onAccountsSelected: widget.onAccountsSelected,
              collapsed: _collapsed,
            ),
            Positioned(
              top: 22,
              left: _collapsed ? 0 : null,
              right: _collapsed ? 0 : 8,
              child: _collapsed
                  ? Center(
                      child: _ToggleButton(
                        collapsed: _collapsed,
                        onTap: () => setState(() => _collapsed = !_collapsed),
                      ),
                    )
                  : _ToggleButton(
                      collapsed: _collapsed,
                      onTap: () => setState(() => _collapsed = !_collapsed),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? 'Expand menu' : 'Collapse menu',
      child: Material(
        color: HomeColors.brand(context).withValues(alpha: 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              collapsed
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              size: 18,
              color: HomeColors.brand(context),
            ),
          ),
        ),
      ),
    );
  }
}
