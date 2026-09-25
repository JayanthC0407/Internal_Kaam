import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// One entry of a dashboard's side menu.
///
/// The menu itself — [DashboardNavigationSidebar] on desktop, [DashboardNavDrawer]
/// below it — is shared by Retail and Corporate, so both look and behave
/// the same. What differs per user type is only this list: each dashboard
/// builds its own items (`RetailNav.items`, `CorpNavDestination.navItems`).
class DashboardNavItem {
  const DashboardNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.children = const [],
  });

  /// Passed back to `onSelected`. Unique across the whole menu, children
  /// included.
  final String id;
  final String label;
  final IconData icon;

  /// Sub-items. An item with children is a group: tapping it opens and
  /// closes the group rather than selecting anything.
  final List<DashboardNavItem> children;

  bool get isGroup => children.isNotEmpty;

  /// Whether [selectedId] is this item or one of its children.
  bool contains(String? selectedId) =>
      selectedId != null &&
      (id == selectedId || children.any((child) => child.id == selectedId));
}

/// A non-interactive note pinned to the bottom of the menu — Retail's
/// "Security" badge.
class DashboardNavFooter {
  const DashboardNavFooter({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The menu's palette, from the shared [AppColors] theme extension — the
/// Corporate design's tokens (`CorpColors`), which the shared menu follows.
class _NavColors {
  const _NavColors._();

  static AppColors _of(BuildContext context) => AppColors.of(context);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color card(BuildContext context) => _of(context).cardBg;
  static Color brand(BuildContext context) => _of(context).brand;
  static Color textPrimary(BuildContext context) => _of(context).textPrimary;
  static Color textSecondary(BuildContext context) =>
      _of(context).textSecondary;
  static Color navInactive(BuildContext context) => _of(context).navInactive;

  /// Cyan-tinted 1px outline.
  static Color border(BuildContext context) => _isDark(context)
      ? _of(context).divider
      : _of(context).brand.withValues(alpha: 0.22);

  static Color shadow(BuildContext context) =>
      _of(context).brandLight.withValues(alpha: _isDark(context) ? 0.14 : 0.22);

  /// Fill behind the selected row.
  static Color selectedBg(BuildContext context) =>
      _of(context).brand.withValues(alpha: _isDark(context) ? 0.20 : 0.10);
}

/// The persistent desktop side menu, collapsible to an icon rail.
///
/// A panel toggle beside the logo switches between the full panel (icons
/// and labels) and the rail; it stays visible in both, so the panel can
/// always be re-expanded.
class DashboardNavigationSidebar extends StatefulWidget {
  const DashboardNavigationSidebar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.footer,
  });

  final List<DashboardNavItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final DashboardNavFooter? footer;

  @override
  State<DashboardNavigationSidebar> createState() =>
      _DashboardNavigationSidebarState();
}

class _DashboardNavigationSidebarState
    extends State<DashboardNavigationSidebar> {
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
        color: _NavColors.card(context),
        border: Border(right: BorderSide(color: _NavColors.border(context))),
        boxShadow: [
          BoxShadow(color: _NavColors.shadow(context), blurRadius: 14),
        ],
      ),
      child: SafeArea(
        child: DashboardNavContent(
          items: widget.items,
          selectedId: widget.selectedId,
          onSelected: widget.onSelected,
          footer: widget.footer,
          collapsed: _collapsed,
          toggleButton: _PanelToggle(
            collapsed: _collapsed,
            onTap: () => setState(() => _collapsed = !_collapsed),
          ),
        ),
      ),
    );
  }
}

/// The same menu in a [Drawer], for widths without the persistent sidebar.
/// Choosing an item closes the drawer before [onSelected] runs.
class DashboardNavDrawer extends StatelessWidget {
  const DashboardNavDrawer({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.footer,
  });

  final List<DashboardNavItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final DashboardNavFooter? footer;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _NavColors.card(context),
      child: SafeArea(
        child: DashboardNavContent(
          items: items,
          selectedId: selectedId,
          footer: footer,
          onSelected: (id) {
            Navigator.of(context).pop();
            onSelected(id);
          },
        ),
      ),
    );
  }
}

/// The menu itself — logo, items, footer — for [DashboardNavigationSidebar]
/// and [DashboardNavDrawer].
///
/// The Corporate design: the selected entry has a tinted fill and a brand
/// accent bar on its leading edge.
class DashboardNavContent extends StatefulWidget {
  const DashboardNavContent({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.footer,
    this.collapsed = false,
    this.toggleButton,
  });

  final List<DashboardNavItem> items;

  /// The selected item's id, a child's included. Null selects nothing —
  /// for a screen the menu has no entry for.
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final DashboardNavFooter? footer;

  /// Icon-only rail mode, for the collapsed sidebar.
  final bool collapsed;

  /// The sidebar's collapse control, beside the logo (or above the icons
  /// when collapsed). Null omits it, which is what the drawer wants.
  final Widget? toggleButton;

  static const logoAsset = 'assets/images/demobank_logo.png';

  @override
  State<DashboardNavContent> createState() => _DashboardNavContentState();
}

class _DashboardNavContentState extends State<DashboardNavContent> {
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _expandSelectedGroup();
  }

  @override
  void didUpdateWidget(covariant DashboardNavContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != oldWidget.selectedId) _expandSelectedGroup();
  }

  /// Opens the group holding the selected item, so it is visible.
  void _expandSelectedGroup() {
    for (final item in widget.items) {
      if (item.isGroup &&
          item.id != widget.selectedId &&
          item.contains(widget.selectedId)) {
        _expanded.add(item.id);
      }
    }
  }

  void _onItemTap(DashboardNavItem item) {
    if (!item.isGroup) {
      widget.onSelected(item.id);
      return;
    }
    if (widget.collapsed) {
      // No room to open a group in the rail — go to its first entry.
      widget.onSelected(item.children.first.id);
      return;
    }
    setState(() {
      if (!_expanded.remove(item.id)) _expanded.add(item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    final toggle = widget.toggleButton;
    final footer = widget.footer;

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
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Image.asset(
                      DashboardNavContent.logoAsset,
                      height: 52,
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (toggle != null) ...[
                    const SizedBox(width: 6),
                    SizedBox(height: 52, child: Center(child: toggle)),
                  ],
                ],
              ),
            )
          else if (toggle != null) ...[
            Center(child: toggle),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 40),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in widget.items) ...[
                    _NavRow(
                      label: item.label,
                      icon: item.icon,
                      selected: item.contains(widget.selectedId),
                      collapsed: collapsed,
                      expanded: item.isGroup && !collapsed
                          ? _expanded.contains(item.id)
                          : null,
                      onTap: () => _onItemTap(item),
                    ),
                    if (item.isGroup &&
                        !collapsed &&
                        _expanded.contains(item.id))
                      for (final child in item.children) ...[
                        const SizedBox(height: 2),
                        _SubNavRow(
                          label: child.label,
                          icon: child.icon,
                          selected: child.id == widget.selectedId,
                          onTap: () => widget.onSelected(child.id),
                        ),
                      ],
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            _NavFooter(footer: footer, collapsed: collapsed),
          ],
        ],
      ),
    );
  }
}

/// A top-level menu row: tinted, with an accent bar, when selected.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.expanded,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  /// For a group: whether it is open (null for a plain item, or collapsed).
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final brand = _NavColors.brand(context);
    final foreground = selected ? brand : _NavColors.textSecondary(context);
    final background =
        selected ? _NavColors.selectedBg(context) : Colors.transparent;
    final iconWidget = Icon(icon, size: 20, color: foreground);
    final isOpen = expanded;

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
              ? Center(child: iconWidget)
              : Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? _NavColors.textPrimary(context)
                              : foreground,
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isOpen != null)
                      Icon(
                        isOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: foreground,
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

    return collapsed ? Tooltip(message: label, child: accented) : accented;
  }
}

/// A row inside an open group, indented under its parent's label: brand
/// text on a light tint when selected.
class _SubNavRow extends StatelessWidget {
  const _SubNavRow({
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
    final brand = _NavColors.brand(context);
    final foreground = selected ? brand : _NavColors.textSecondary(context);
    return Material(
      color: selected
          ? _NavColors.selectedBg(context).withValues(alpha: 0.06)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.only(left: 30, right: 8, top: 9, bottom: 9),
          child: Row(
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.5,
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

/// The footer note, in the menu's outlined style.
class _NavFooter extends StatelessWidget {
  const _NavFooter({required this.footer, required this.collapsed});

  final DashboardNavFooter footer;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final brand = _NavColors.brand(context);
    final decoration = BoxDecoration(
      color: _NavColors.selectedBg(context),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _NavColors.border(context)),
    );

    if (collapsed) {
      return Center(
        child: Tooltip(
          message: footer.label,
          child: Container(
            width: 40,
            height: 40,
            decoration: decoration,
            child: Icon(footer.icon, size: 18, color: brand),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: decoration,
      child: Row(
        children: [
          Icon(footer.icon, size: 18, color: brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              footer.label,
              style: TextStyle(
                color: _NavColors.textSecondary(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The panel glyph beside the logo that collapses and expands the sidebar.
class _PanelToggle extends StatelessWidget {
  const _PanelToggle({required this.collapsed, required this.onTap});

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
              collapsed
                  ? Icons.view_sidebar_outlined
                  : Icons.view_sidebar_rounded,
              size: 20,
              color: _NavColors.navInactive(context),
            ),
          ),
        ),
      ),
    );
  }
}
