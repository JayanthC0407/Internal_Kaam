/// Translates OBDX's Oracle JET grid classes into column spans Flutter can
/// lay out with.
///
/// The dashboard configuration stores sizing as a CSS class (`oj-lg-8`,
/// `oj-md-6`, `oj-sm-12`) because that is what the web client renders with.
/// Flutter does not use those classes, but the *intent* — "this widget
/// occupies N of 12 columns" — is exactly what we need, and honouring it
/// keeps a dashboard personalized on the web looking the same here.
class CorpGridSpan {
  CorpGridSpan._();

  /// Total columns in the Oracle JET grid.
  static const int columns = 12;

  /// Columns [style] asks for, or null when it says nothing usable.
  ///
  /// Accepts any `oj-{breakpoint}-{n}` class and ignores the breakpoint
  /// prefix: the caller has already picked the layout array for the current
  /// breakpoint, so the prefix carries no extra information.
  static int? fromStyle(String? style) {
    final raw = style?.trim();
    if (raw == null || raw.isEmpty) return null;

    final match = RegExp(r'oj-(?:lg|md|sm|xl)-(\d{1,2})\b').firstMatch(raw);
    if (match == null) return null;

    final span = int.tryParse(match.group(1) ?? '');
    if (span == null || span < 1 || span > columns) return null;
    return span;
  }

  /// Columns for a catalog `width` entry, e.g. `{'large': '8'}`.
  static int? fromCatalogWidth(String? width) {
    final raw = width?.trim();
    if (raw == null || raw.isEmpty) return null;
    final span = int.tryParse(raw);
    if (span == null || span < 1 || span > columns) return null;
    return span;
  }

  /// Resolves a span from the stored style first, then the catalog width,
  /// then [fallback] — full width, which is what OBDX's own "short form"
  /// catalog entries imply on small screens.
  static int resolve({
    String? style,
    String? catalogWidth,
    int fallback = columns,
  }) {
    return fromStyle(style) ?? fromCatalogWidth(catalogWidth) ?? fallback;
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
}
