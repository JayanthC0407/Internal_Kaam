import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_nav_content.dart';

/// Persistent desktop side panel for the corporate dashboard.
///
/// Collapsible, like Retail's `WebNavigationSidebar`: the toggle switches
/// between the full 196px panel (icons + labels) and a 72px icon-only rail,
/// and stays visible in both states so the panel can always be re-expanded.
/// On phone / tablet the same [CorpNavContent] is shown inside a [Drawer]
/// instead — see `CorpDashboardScreen`'s `drawer:`.
class CorpNavigationSidebar extends StatefulWidget {
  const CorpNavigationSidebar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CorpNavDestination selected;
  final ValueChanged<CorpNavDestination> onSelected;

  @override
  State<CorpNavigationSidebar> createState() => _CorpNavigationSidebarState();
}

class _CorpNavigationSidebarState extends State<CorpNavigationSidebar> {
  static const double _expandedWidth = 196;
  static const double _collapsedWidth = 72;

  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: _collapsed ? _collapsedWidth : _expandedWidth,
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        border: Border(
          right: BorderSide(color: CorpColors.cardBorder(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: CorpColors.cardShadow(context),
            blurRadius: 14,
          ),
        ],
      ),
      child: SafeArea(
        child: CorpNavContent(
          selected: widget.selected,
          onSelected: widget.onSelected,
          collapsed: _collapsed,
          toggleButton: _SidebarToggle(
            collapsed: _collapsed,
            onTap: () => setState(() => _collapsed = !_collapsed),
          ),
        ),
      ),
    );
  }
}

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? 'Expand menu' : 'Collapse menu',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              // Matches the design's panel-toggle glyph next to the logo.
              collapsed
                  ? Icons.view_sidebar_outlined
                  : Icons.view_sidebar_rounded,
              size: 20,
              color: CorpColors.navInactive(context),
            ),
          ),
        ),
      ),
    );
  }
}
