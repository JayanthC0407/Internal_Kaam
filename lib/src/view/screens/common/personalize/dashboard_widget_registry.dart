import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_grid_span.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_widget_labels.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_card_surface.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';

/// How a widget the app builds sits on the dashboard grid.
///
/// Declared by the app, per widget, because the catalog cannot be relied
/// on for it: most of the widgets this app builds have no catalog entry at
/// all, and those that do were sized for the web client's content.
class DashboardWidgetSpec {
  const DashboardWidgetSpec({
    required this.large,
    int? medium,
    this.minHeight = 0,
    this.title,
    this.ownCard = false,
  }) : medium = medium ?? large;

  /// The widget draws its own card, and keeps it on the grid instead of
  /// taking the grid's. Retail sets this so a personalized dashboard looks
  /// exactly like its fixed home, whose cards differ slightly per widget.
  final bool ownCard;

  /// Columns of 12 on a desktop-width dashboard.
  final int large;

  /// Columns of 12 on a tablet-width one. Phones always use the full width.
  final int medium;

  /// See [DashboardTileHeight].
  final double minHeight;

  /// Heading for the tile's card, for a widget that draws none of its own.
  final String? title;

  int spanFor(DashboardBreakpoint breakpoint) => switch (breakpoint) {
        DashboardBreakpoint.small => DashboardGridSpan.columns,
        DashboardBreakpoint.medium => medium,
        DashboardBreakpoint.large || DashboardBreakpoint.defaultLayout => large,
      };
}

/// Maps an OBDX `componentName` to a Flutter widget.
///
/// An OBDX component name does not imply a Flutter implementation — the web
/// side resolves each to an Oracle JET component we have no equivalent of.
/// This registry is the bridge, and adding a widget to a dashboard is
/// therefore: a catalog entry (which the host owns) + a registry entry +
/// the widget itself.
///
/// One implementation per user type, because the same `componentName` can
/// legitimately mean different things — a Retail `financial-summary` is not
/// a Corporate `account-financial-summary`, and neither user type should be
/// able to build the other's widgets.
abstract class DashboardWidgetRegistry {
  const DashboardWidgetRegistry();

  /// Builders keyed by `componentName`. Each takes no arguments and reads
  /// its own providers, so a widget can be constructed from a name alone.
  Map<String, Widget Function()> get builders;

  /// Grid size for each built widget, keyed like [builders]. Every builder
  /// should have one — a test enforces it.
  Map<String, DashboardWidgetSpec> get specs;

  /// Size for a component with no spec: the catalog's most common width
  /// rather than the full row, so an unimplemented or newly added widget
  /// does not push everything else onto its own line.
  static const fallbackSpec = DashboardWidgetSpec(large: 4, medium: 6);

  /// The span [componentName] is drawn at on [breakpoint] — see
  /// [DashboardGridSpan.resolve] for the order sources are consulted in.
  int spanFor(
    String componentName, {
    required DashboardBreakpoint breakpoint,
    DashboardWidgetCatalog? catalog,
    String? style,
  }) {
    if (breakpoint == DashboardBreakpoint.small) {
      return DashboardGridSpan.columns;
    }
    return DashboardGridSpan.resolve(
      preferred: specs[componentName]?.spanFor(breakpoint),
      catalogWidth:
          catalog?.byName(componentName)?.widthFor(breakpoint.catalogWidthKey),
      style: style,
      fallback: fallbackSpec.spanFor(breakpoint),
    );
  }

  /// [spanFor] as a save callback — the sizes a save writes are the ones
  /// the dashboard draws.
  DashboardSpanResolver spanResolver({
    required DashboardBreakpoint breakpoint,
    DashboardWidgetCatalog? catalog,
  }) =>
      (componentName, style) => spanFor(
            componentName,
            breakpoint: breakpoint,
            catalog: catalog,
            style: style,
          );

  /// The grid tile for a saved layout [item]. [draggable] lets it be held
  /// and dropped elsewhere on the dashboard (see
  /// [DashboardTileGrid.onMove]); pinned components never are.
  DashboardTile tileFor(
    DashboardLayoutItem item, {
    required DashboardBreakpoint breakpoint,
    DashboardWidgetCatalog? catalog,
    bool draggable = false,
  }) {
    final spec = specs[item.componentName];
    final canDrag = draggable && !pinnedComponents.contains(item.componentName);
    return DashboardTile(
      span: spanFor(
        item.componentName,
        breakpoint: breakpoint,
        catalog: catalog,
        style: item.style,
      ),
      minHeight: spec?.minHeight ?? 0,
      title: spec?.title,
      framed: !(spec?.ownCard ?? false),
      dragId: canDrag ? item.componentName : null,
      child: build(item.componentName),
    );
  }

  /// Components the dashboard always draws in a fixed place, whatever the
  /// saved order says — they cannot be moved or resized in the Personalize
  /// panel.
  Set<String> get pinnedComponents => const {};

  Set<String> get implementedComponents => builders.keys.toSet();

  bool isImplemented(String componentName) =>
      builders.containsKey(componentName);

  /// Builds [componentName], or a placeholder naming it when unimplemented.
  ///
  /// A placeholder rather than nothing: the user chose to put this widget
  /// on their dashboard, and silently dropping it would make the Personalize
  /// panel look broken. It also keeps the saved configuration honest — the
  /// component stays in the layout and still round-trips to the web client,
  /// which *can* render it.
  Widget build(String componentName) {
    final builder = builders[componentName];
    if (builder != null) return builder();
    return UnavailableDashboardWidget(componentName: componentName);
  }
}

/// Shown in place of a widget this app does not implement yet.
class UnavailableDashboardWidget extends StatelessWidget {
  const UnavailableDashboardWidget({super.key, required this.componentName});

  final String componentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ?? theme.hintColor;
    final label = DashboardWidgetLabels.forComponent(componentName);

    return DashboardCardSurface(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: muted.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.widgets_outlined, size: 19, color: muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Not available in this app yet',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
