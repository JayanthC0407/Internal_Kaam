import 'package:flutter/material.dart';

import 'package:demo_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';
import 'package:demo_bank/src/view/screens/retail/dashboard_widgets/retail_dashboard_widgets.dart';
import 'package:demo_bank/src/view/screens/retail/dashboard_widgets/retail_widget_registry.dart';

/// Retail's existing Home widgets, by the names a published screen uses in
/// `AppWidget` (CONTRACT-OBDX §4). The same names as the OBDX dashboard
/// (`RetailWidgetRegistry`), plus `retail-accounts`, the accounts card with
/// its tabs.
///
/// Each one is drawn in the same card as on today's Home, and still loads its
/// own data from OBDX through its provider. The Studio preview uses this same
/// map with those providers swapped for sample data.
class RetailAppWidgets {
  const RetailAppWidgets._();

  static const _registry = RetailWidgetRegistry();

  /// Palette names, in the order the Studio lists them. Keep in step with
  /// the platform's `APP_WIDGETS` (dxp-platform `src/seed.js`).
  static const names = <String>[
    'retail-accounts',
    'casa-account-card',
    'loans-account-card',
    'loan-summary',
    'credit-card',
    'recent-account-transactions',
    'spend-summary',
    'quick-links',
    'offers',
  ];

  static final Map<String, Widget Function()> builders = {
    'retail-accounts': () => _tile(
          const DashboardTile(span: 12, framed: false, child: RetailAccountsWidget()),
        ),
    for (final name in names.skip(1))
      name: () {
        final spec = _registry.specs[name];
        return _tile(DashboardTile(
          span: 12,
          minHeight: spec?.minHeight ?? 0,
          title: spec?.title,
          framed: !(spec?.ownCard ?? false),
          child: _registry.build(name),
        ));
      },
  };

  /// One full-width tile on the dashboard's own grid, so the card, its
  /// title and its spacing are exactly those of today's Home.
  static Widget _tile(DashboardTile tile) => DashboardTileGrid(
        layout: DashboardGridLayout.twoColumns,
        collapseBelow: 920,
        tileDecoration: RetailWidgetRegistry.tileDecoration,
        tiles: [tile],
      );
}
