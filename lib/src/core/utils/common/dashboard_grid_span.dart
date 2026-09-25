/// Translates OBDX's Oracle JET grid classes into column spans Flutter can
/// lay out with, and packs spans into rows.
///
/// The dashboard configuration stores sizing as a CSS class (`oj-lg-8`,
/// `oj-md-6`, `oj-sm-12`) because that is what the web client renders with.
/// Flutter does not use those classes, but the *intent* — "this widget
/// occupies N of 12 columns" — is exactly what we need.
class DashboardGridSpan {
  DashboardGridSpan._();

  /// Total columns in the Oracle JET grid.
  static const int columns = 12;

  static final RegExp _jetClass = RegExp(r'oj-(?:lg|md|sm|xl)-(\d{1,2})\b');

  /// Columns [style] asks for, or null when it says nothing usable.
  ///
  /// Accepts any `oj-{breakpoint}-{n}` class and ignores the breakpoint
  /// prefix: the caller has already picked the layout array for the current
  /// breakpoint, so the prefix carries no extra information.
  static int? fromStyle(String? style) {
    final raw = style?.trim();
    if (raw == null || raw.isEmpty) return null;

    final match = _jetClass.firstMatch(raw);
    if (match == null) return null;
    return _valid(int.tryParse(match.group(1) ?? ''));
  }

  /// Columns for a catalog `width` entry, e.g. `{'large': '8'}`.
  static int? fromCatalogWidth(String? width) {
    final raw = width?.trim();
    if (raw == null || raw.isEmpty) return null;
    return _valid(int.tryParse(raw));
  }

  /// Marks a style whose span the *user* chose — written by the Personalize
  /// panel's former Half / Full width setting, and still honoured so those
  /// choices keep their size.
  ///
  /// Needed because a saved span alone cannot be trusted — earlier builds
  /// wrote `oj-lg-12` for everything they could not size — so [resolve]
  /// ranks unmarked saved styles last. A plain CSS class, which the web
  /// client's grid ignores.
  static const userSizedClass = 'user-sized';

  /// Whether [style] carries a span the user chose. See [userSizedClass].
  static bool isUserSized(String? style) =>
      (style ?? '').split(RegExp(r'\s+')).contains(userSizedClass);

  /// The span to draw a widget at, from the most to the least authoritative
  /// source:
  ///
  ///  0. [style], when the user chose its span ([isUserSized]).
  ///  1. [preferred] — the size the app declares for a widget it builds
  ///     (the widget registry). Five of Retail's six built widgets, and
  ///     Corporate's Pickup Points, have no catalog entry at all, so
  ///     without this they had no size and drew full width.
  ///  2. [catalogWidth] — the size the bank configured the widget at.
  ///  3. [style] — the saved `oj-*-N` class. Last, not first: it is a copy
  ///     of a size written at save time, and earlier builds wrote
  ///     `oj-lg-12` for every widget they could not size, which then kept
  ///     them full width permanently.
  ///  4. [fallback].
  static int resolve({
    int? preferred,
    String? catalogWidth,
    String? style,
    required int fallback,
  }) {
    final chosen = isUserSized(style) ? fromStyle(style) : null;
    return chosen ??
        _valid(preferred) ??
        fromCatalogWidth(catalogWidth) ??
        fromStyle(style) ??
        fallback;
  }

  /// [style] with its `oj-{prefix}-N` class set to [span], keeping any other
  /// classes. [prefix] is e.g. `oj-lg`.
  static String withSpan(String? style, String prefix, int span) {
    final value = '$prefix-${span.clamp(1, columns)}';
    final raw = style?.trim() ?? '';
    if (raw.isEmpty) return value;

    final ownClass = RegExp('${RegExp.escape(prefix)}-\\d{1,2}\\b');
    if (ownClass.hasMatch(raw)) return raw.replaceFirst(ownClass, value);
    return '$raw $value';
  }

  /// Packs [spans], in order, into rows of [columns], then widens each row's
  /// tiles so the row is exactly full.
  ///
  /// Order is never changed — the user's arrangement is the saved order —
  /// so a row closes as soon as the next tile does not fit. The columns a
  /// row is short by are shared out in proportion to the tiles' spans, so
  /// no row ends in an empty hole: `[4, 4]` becomes `[6, 6]`, a lone `[8]`
  /// becomes `[12]`.
  ///
  /// Returns, per row, the indices into [spans] and each tile's final span.
  static List<List<({int index, int span})>> packRows(List<int> spans) {
    final rows = <List<({int index, int span})>>[];
    var row = <({int index, int span})>[];
    var used = 0;

    void closeRow() {
      if (row.isEmpty) return;
      rows.add(_fill(row, used));
      row = [];
      used = 0;
    }

    for (var i = 0; i < spans.length; i++) {
      final span = spans[i].clamp(1, columns);
      if (used + span > columns) closeRow();
      row.add((index: i, span: span));
      used += span;
    }
    closeRow();
    return rows;
  }

  static List<({int index, int span})> _fill(
    List<({int index, int span})> row,
    int used,
  ) {
    final spare = columns - used;
    if (spare <= 0) return row;

    final widened = [
      for (final tile in row)
        (index: tile.index, span: tile.span + spare * tile.span ~/ used),
    ];
    // Rounding leaves a remainder; hand it out left to right.
    var remainder =
        columns - widened.fold<int>(0, (total, tile) => total + tile.span);
    for (var i = 0; remainder > 0; i = (i + 1) % widened.length) {
      widened[i] = (index: widened[i].index, span: widened[i].span + 1);
      remainder--;
    }
    return widened;
  }

  /// Pixel width for [span] columns inside [available], allowing for
  /// [gap] between adjacent items.
  ///
  /// A full-width span returns [available] exactly, so a 12-column widget
  /// never ends up a fraction narrower than the container through rounding.
  static double widthFor({
    required int span,
    required double available,
    required double gap,
  }) {
    if (span >= columns) return available;
    final clamped = span.clamp(1, columns);
    // Each column carries its share of the gaps that would sit between a
    // full row of 12.
    final totalGaps = gap * (columns - 1);
    final columnWidth = (available - totalGaps) / columns;
    return (columnWidth * clamped) + (gap * (clamped - 1));
  }

  static int? _valid(int? span) =>
      span == null || span < 1 || span > columns ? null : span;
}
