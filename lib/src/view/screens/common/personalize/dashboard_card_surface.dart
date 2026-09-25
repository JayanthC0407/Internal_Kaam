import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// The one card style every tile on a personalized dashboard shares.
///
/// Each dashboard widget was built with its own card — different corner
/// radii, borders, shadows and padding, Retail's and Corporate's styled
/// differently again — so a grid of them looked assembled rather than
/// designed. On a personalized dashboard the grid draws this card around
/// every tile instead, and the widgets' own cards step aside (see
/// [DashboardCardSurface]).
class DashboardTileStyle {
  const DashboardTileStyle._();

  static const double radius = 14;
  static const EdgeInsets padding = EdgeInsets.all(16);

  static BoxDecoration decoration(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: colors.cardBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark ? colors.divider : colors.brand.withValues(alpha: 0.22),
      ),
      boxShadow: [
        BoxShadow(
          color: colors.brandLight.withValues(alpha: isDark ? 0.14 : 0.22),
          blurRadius: 14,
        ),
      ],
    );
  }

  static TextStyle titleStyle(BuildContext context) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.of(context).textPrimary,
      );
}

/// Marks its subtree as sitting inside a dashboard grid tile, which already
/// draws the card.
class DashboardTileScope extends InheritedWidget {
  const DashboardTileScope({super.key, required super.child});

  /// Whether [context] is inside a tile's card.
  static bool isInTile(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DashboardTileScope>() != null;

  @override
  bool updateShouldNotify(DashboardTileScope oldWidget) => false;
}

/// A dashboard widget's own card: a [Container] with [decoration] and
/// [padding] — except inside a grid tile, where it is just [child], because
/// the tile draws the shared card around it.
///
/// Used for the outermost container of every widget the dashboards place,
/// so the same widget keeps its own look on the fixed layouts (the original
/// Retail home, the Corporate defaults) and takes the shared one in the
/// personalized grid, with no card inside a card.
class DashboardCardSurface extends StatelessWidget {
  const DashboardCardSurface({
    super.key,
    required this.child,
    this.decoration,
    this.padding,
    this.width,
  });

  final Widget child;
  final Decoration? decoration;
  final EdgeInsetsGeometry? padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (DashboardTileScope.isInTile(context)) return child;
    return Container(
      width: width,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}
