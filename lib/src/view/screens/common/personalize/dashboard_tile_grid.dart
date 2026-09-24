import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_grid_span.dart';

/// One widget on a dashboard, with the number of grid columns it spans.
class DashboardTile {
  const DashboardTile({required this.span, required this.child});

  /// Columns out of [DashboardGridSpan.columns].
  final int span;
  final Widget child;
}

/// Lays dashboard tiles out on OBDX's 12-column grid.
///
/// Uses a [Wrap] rather than a fixed Row/Column so a row fills up and
/// overflows naturally — matching how the web grid reflows, and meaning the
/// dashboard never overflows horizontally however the user arranges it.
///
/// Shared by both dashboards so a personalized layout has the same
/// proportions whichever user type is viewing it.
class DashboardTileGrid extends StatelessWidget {
  const DashboardTileGrid({
    super.key,
    required this.tiles,
    required this.available,
    this.gap = 20,
  });

  final List<DashboardTile> tiles;

  /// Width the grid has to fill.
  final double available;

  final double gap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        for (final tile in tiles)
          SizedBox(
            width: DashboardGridSpan.widthFor(
              span: tile.span,
              available: available,
              gap: gap,
            ),
            child: tile.child,
          ),
      ],
    );
  }
}
