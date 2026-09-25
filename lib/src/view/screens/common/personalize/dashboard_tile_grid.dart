import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_grid_span.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_widget_labels.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_card_surface.dart';

/// Minimum tile heights, so a row of small widgets does not look stunted.
///
/// Minimums, not fixed heights: a row grows to its tallest tile (see
/// [DashboardTileGrid]), so no content is ever clipped to fit a class.
class DashboardTileHeight {
  const DashboardTileHeight._();

  /// Shortcut grids, offers.
  static const double compact = 160;

  /// Summaries, charts, short lists.
  static const double standard = 280;
}

/// One widget on a dashboard, with the number of grid columns it spans.
class DashboardTile {
  const DashboardTile({
    required this.span,
    required this.child,
    this.minHeight = 0,
    this.framed = true,
    this.title,
    this.dragId,
  });

  /// The component this tile shows, when it can be dragged to another
  /// place on the dashboard — see [DashboardTileGrid.onMove]. Null for
  /// pinned content and status cards.
  final String? dragId;

  /// Columns out of [DashboardGridSpan.columns] the tile asks for. The grid
  /// may widen it to fill its row.
  final int span;
  final Widget child;

  /// See [DashboardTileHeight].
  final double minHeight;

  /// Whether the grid draws the shared card around [child]. False for
  /// status content — loading, errors — that is not a widget.
  final bool framed;

  /// Heading drawn by the shared card, for widgets that have none of their
  /// own (the bare account and loan lists).
  final String? title;
}

/// How [DashboardTileGrid] arranges its tiles.
enum DashboardGridLayout {
  /// 12-column rows. Tiles fill rows in their saved order; a row short of
  /// 12 widens its tiles to fill it, and every tile in a row takes the
  /// height of the tallest, so cards line up top and bottom.
  rows,

  /// Two equal columns that each stack at their own pace, tiles placed
  /// left, right, left, … in their saved order. This is the fixed Retail
  /// home's arrangement: its cards differ a lot in height (a short loan
  /// tracker beside a long transactions list), so equal-height rows would
  /// stretch the short ones into mostly empty cards.
  ///
  /// A full-width tile (span 12) — Corporate's Account Summary table —
  /// spans both columns: the tiles before it finish their two columns,
  /// it sits across the whole width, and two columns resume below it.
  twoColumns,
}

/// Lays dashboard tiles out — see [DashboardGridLayout].
///
/// Below [collapseBelow] logical pixels of width, every tile takes the full
/// width, one per line, whatever its span.
///
/// Shared by both dashboards so a personalized layout has the same
/// proportions whichever user type is viewing it.
class DashboardTileGrid extends StatelessWidget {
  const DashboardTileGrid({
    super.key,
    required this.tiles,
    this.gap = 20,
    this.layout = DashboardGridLayout.rows,
    this.collapseBelow = 0,
    this.tileDecoration,
    this.onMove,
  });

  final List<DashboardTile> tiles;
  final double gap;
  final DashboardGridLayout layout;
  final double collapseBelow;

  /// Called when a tile with a [DashboardTile.dragId] is held, dragged and
  /// dropped on another such tile, with both ids. Null turns dragging off.
  final void Function(String dragged, String target)? onMove;

  /// The card drawn around framed tiles. Defaults to
  /// [DashboardTileStyle.decoration].
  final BoxDecoration Function(BuildContext context)? tileDecoration;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < collapseBelow;
        if (layout == DashboardGridLayout.twoColumns && !singleColumn) {
          return _buildColumns();
        }
        return _buildRows(singleColumn: singleColumn);
      },
    );
  }

  Widget _frame(DashboardTile tile) {
    final framed = _TileFrame(tile: tile, decoration: tileDecoration);
    final id = tile.dragId;
    if (id == null) return framed;
    // Wrapped even while [onMove] is null (say, mid-save), with dragging
    // switched off inside: adding and removing the wrapper would rebuild
    // the widget beneath and lose its state, such as a carousel's page.
    return _DraggableTile(
      key: ValueKey('dashboard-tile:$id'),
      id: id,
      label: tile.title ?? DashboardWidgetLabels.forComponent(id),
      onMove: onMove,
      child: framed,
    );
  }

  Widget _buildRows({required bool singleColumn}) {
    final rows = DashboardGridSpan.packRows([
      for (final tile in tiles)
        singleColumn ? DashboardGridSpan.columns : tile.span,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: gap),
          _DashboardGridRow(
            spans: [for (final cell in rows[r]) cell.span],
            gap: gap,
            minHeight: rows[r]
                .map((cell) => tiles[cell.index].minHeight)
                .fold<double>(0, math.max),
            children: [
              for (final cell in rows[r]) _frame(tiles[cell.index]),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildColumns() {
    Widget sized(DashboardTile tile) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: tile.minHeight),
          child: _frame(tile),
        );

    Widget column(List<DashboardTile> segment, int parity) {
      final placed = [
        for (var i = parity; i < segment.length; i += 2) segment[i],
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < placed.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            sized(placed[i]),
          ],
        ],
      );
    }

    Widget columns(List<DashboardTile> segment) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: column(segment, 0)),
            SizedBox(width: gap),
            Expanded(child: column(segment, 1)),
          ],
        );

    // Runs of half-width tiles become two-column blocks; a full-width tile
    // ends the run and spans both columns.
    final blocks = <Widget>[];
    var segment = <DashboardTile>[];
    void flush() {
      if (segment.isEmpty) return;
      blocks.add(columns(segment));
      segment = [];
    }

    for (final tile in tiles) {
      if (tile.span >= DashboardGridSpan.columns) {
        flush();
        blocks.add(sized(tile));
      } else {
        segment.add(tile);
      }
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          blocks[i],
        ],
      ],
    );
  }
}

/// A tile that can be held and dropped on another — the dashboard's own
/// drag-and-drop arrangement.
///
/// Press and hold (a long press, with a mouse too) lifts the tile: a card
/// with its name follows the pointer, the tile fades where it was, and the
/// tile under the pointer is outlined where it would land. A plain tap or
/// swipe still reaches the widget, so its buttons and carousels keep
/// working.
///
/// Dragging near the top or bottom of the dashboard scrolls it, so a widget
/// can be moved to a place that is off screen when the drag starts.
class _DraggableTile extends StatefulWidget {
  const _DraggableTile({
    super.key,
    required this.id,
    required this.label,
    required this.onMove,
    required this.child,
  });

  final String id;
  final String label;

  /// Null while dragging is off.
  final void Function(String dragged, String target)? onMove;
  final Widget child;

  @override
  State<_DraggableTile> createState() => _DraggableTileState();
}

class _DraggableTileState extends State<_DraggableTile> {
  /// How close to the top or bottom edge, in logical pixels, the pointer
  /// has to come before the dashboard starts scrolling.
  static const double _edgeZone = 72;

  /// Scroll speed — the value [ReorderableListView] uses.
  static const double _velocityScalar = 50;

  EdgeDraggingAutoScroller? _autoScroller;

  void _onDragUpdate(DragUpdateDetails details) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    if (_autoScroller?.scrollable != scrollable) {
      _autoScroller?.stopAutoScroll();
      _autoScroller = EdgeDraggingAutoScroller(
        scrollable,
        velocityScalar: _velocityScalar,
      );
    }
    // The scroller moves the page while this band reaches past the
    // viewport's edge: a band [_edgeZone] either side of the pointer does
    // that exactly when the pointer is within [_edgeZone] of an edge.
    _autoScroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(
        center: details.globalPosition,
        width: 1,
        height: _edgeZone * 2,
      ),
    );
  }

  void _stopAutoScroll() => _autoScroller?.stopAutoScroll();

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final move = widget.onMove;
    final id = widget.id;
    final child = widget.child;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => move != null && details.data != id,
      onAcceptWithDetails: (details) => move?.call(details.data, id),
      builder: (context, candidates, rejected) {
        final isTarget = candidates.isNotEmpty;
        return LongPressDraggable<String>(
          data: id,
          maxSimultaneousDrags: move == null ? 0 : 1,
          onDragUpdate: _onDragUpdate,
          onDragEnd: (_) => _stopAutoScroll(),
          onDraggableCanceled: (_, __) => _stopAutoScroll(),
          onDragCompleted: _stopAutoScroll,
          feedback: _DragFeedback(label: widget.label),
          childWhenDragging: Opacity(opacity: 0.35, child: child),
          child: Stack(
            // Passthrough, so the tile still fills a row's height.
            fit: StackFit.passthrough,
            children: [
              child,
              if (isTarget)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(
                          DashboardTileStyle.radius + 2,
                        ),
                        border: Border.all(color: brand, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// What follows the pointer while a tile is dragged.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.label});

  static const double width = 300;

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(DashboardTileStyle.radius),
      color: theme.cardColor,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DashboardTileStyle.radius),
          border: Border.all(color: theme.colorScheme.primary, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.open_with_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardTileStyle.titleStyle(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card around a framed tile — see [DashboardTileStyle].
class _TileFrame extends StatelessWidget {
  const _TileFrame({required this.tile, this.decoration});

  final DashboardTile tile;
  final BoxDecoration Function(BuildContext context)? decoration;

  @override
  Widget build(BuildContext context) {
    if (!tile.framed) return tile.child;

    final title = tile.title;
    return Container(
      padding: DashboardTileStyle.padding,
      decoration: (decoration ?? DashboardTileStyle.decoration).call(context),
      child: DashboardTileScope(
        child: title == null
            ? tile.child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: DashboardTileStyle.titleStyle(context)),
                  const SizedBox(height: 14),
                  tile.child,
                ],
              ),
      ),
    );
  }
}

/// One grid row: children at fixed column widths, all as tall as the
/// tallest.
///
/// A render object rather than `IntrinsicHeight` + `Row`: intrinsic sizing
/// is not supported by several of the dashboard widgets (a `LayoutBuilder`
/// or a `GridView` anywhere inside throws) and is expensive besides. This
/// lays each child out at its natural height, then again at the row's.
class _DashboardGridRow extends MultiChildRenderObjectWidget {
  const _DashboardGridRow({
    required this.spans,
    required this.gap,
    required this.minHeight,
    required super.children,
  });

  final List<int> spans;
  final double gap;
  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDashboardGridRow(spans: spans, gap: gap, minHeight: minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDashboardGridRow renderObject,
  ) {
    renderObject
      ..spans = spans
      ..gap = gap
      ..minHeight = minHeight;
  }
}

class _GridRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDashboardGridRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GridRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridRowParentData> {
  _RenderDashboardGridRow({
    required List<int> spans,
    required double gap,
    required double minHeight,
  })  : _spans = spans,
        _gap = gap,
        _minHeight = minHeight;

  List<int> _spans;
  set spans(List<int> value) {
    if (listEquals(_spans, value)) return;
    _spans = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  double _minHeight;
  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridRowParentData) {
      child.parentData = _GridRowParentData();
    }
  }

  /// Width of each child, left to right. A full row's last child takes
  /// whatever is left, so rounding can never leave a sliver or push the
  /// row wider than [available].
  List<double> _widths(double available) {
    final columnWidth = (available - _gap * (DashboardGridSpan.columns - 1)) /
        DashboardGridSpan.columns;
    final isFull = _spans.fold<int>(0, (total, span) => total + span) >=
        DashboardGridSpan.columns;

    final widths = <double>[];
    var x = 0.0;
    for (var i = 0; i < _spans.length; i++) {
      final span = _spans[i];
      final isLast = i == _spans.length - 1;
      final width = isLast && isFull
          ? available - x
          : columnWidth * span + _gap * (span - 1);
      widths.add(math.max(0, width));
      x += width + _gap;
    }
    return widths;
  }

  @override
  void performLayout() {
    assert(
      constraints.hasBoundedWidth,
      'DashboardTileGrid needs a bounded width.',
    );
    final available = constraints.maxWidth;
    final widths = _widths(available);

    // Pass 1: natural heights.
    var height = _minHeight;
    var child = firstChild;
    var i = 0;
    while (child != null && i < widths.length) {
      child.layout(
        BoxConstraints.tightFor(width: widths[i]),
        parentUsesSize: true,
      );
      height = math.max(height, child.size.height);
      child = childAfter(child);
      i++;
    }

    // Pass 2: everyone at least the row's height.
    //
    // A minimum, deliberately not a tight height: a child given tight
    // constraints becomes a relayout boundary, so when its content later
    // grew — an accounts card whose data arrived — it re-laid itself out
    // at the old height without telling the row, and overflowed. With a
    // loose maximum, growth reaches this row, which measures again.
    child = firstChild;
    i = 0;
    var x = 0.0;
    var rowHeight = height;
    while (child != null) {
      final width = i < widths.length ? widths[i] : 0.0;
      child.layout(
        BoxConstraints(minWidth: width, maxWidth: width, minHeight: height),
        parentUsesSize: true,
      );
      rowHeight = math.max(rowHeight, child.size.height);
      (child.parentData! as _GridRowParentData).offset = Offset(x, 0);
      x += width + _gap;
      child = childAfter(child);
      i++;
    }

    size = constraints.constrain(Size(available, rowHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
