import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';

/// Shared building blocks for the corporate dashboard widgets.
///
/// The Term Deposit and Loan designs are the same handful of pieces in
/// different arrangements — a heading with a subtitle, a row of tinted stat
/// tiles, a donut or gauge, a list of rows, a footer with a link. They live
/// here so the four widgets stay short and, more importantly, so the tiles
/// line up pixel-for-pixel across widgets sitting side by side on the grid.
///
/// Every piece is theme-derived: the designs' pastel tiles are the theme's
/// accent colours at low alpha rather than fixed hex values, so they hold up
/// in dark mode instead of turning into pale blocks with unreadable text.

/// The tint a stat tile is drawn in. Maps to the design's blue / green /
/// amber / neutral tiles.
enum CorpStatTone { info, positive, warning, neutral }

extension CorpStatToneColors on CorpStatTone {
  /// The saturated colour — used for the tile's label, and for the donut
  /// and gauge strokes.
  Color accent(BuildContext context) {
    final colors = AppColors.of(context);
    switch (this) {
      case CorpStatTone.info:
        return colors.brand;
      case CorpStatTone.positive:
        return colors.success;
      case CorpStatTone.warning:
        return colors.warning;
      case CorpStatTone.neutral:
        return colors.textSecondary;
    }
  }

  /// The tile's fill. Low-alpha accent over the card, which reads as the
  /// design's pastel in light mode and as a subtle wash in dark mode.
  Color fill(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return accent(context).withValues(alpha: isDark ? 0.16 : 0.08);
  }

  Color border(BuildContext context) =>
      accent(context).withValues(alpha: 0.22);
}

/// Widget heading — bold title over a muted subtitle, as every design has.
class CorpWidgetHeading extends StatelessWidget {
  const CorpWidgetHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? subtitle;

  /// Right-aligned control (the Installments Due segmented toggle).
  final Widget? trailing;

  /// Phone sizing — smaller type, as the mobile designs use.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle?.trim();

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w700,
            color: CorpColors.textPrimary(context),
          ),
        ),
        if (subtitleText != null && subtitleText.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 12.5,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );

    if (trailing == null) return heading;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        const SizedBox(width: 12),
        trailing!,
      ],
    );
  }
}

/// One tinted figure — "Total TD balance / £680K".
class CorpStatTile extends StatelessWidget {
  const CorpStatTile({
    super.key,
    required this.label,
    required this.value,
    this.tone = CorpStatTone.info,
    this.compact = false,
  });

  final String label;
  final String value;
  final CorpStatTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: tone.fill(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              color: tone.accent(context),
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 16 : 19,
                fontWeight: FontWeight.w700,
                color: CorpColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stat tiles laid out as the designs do: across in one row when there
/// is room, wrapped onto two per line on a phone.
///
/// [Wrap] rather than a [Row] of [Expanded]s because the tile count varies
/// per widget (three on Loan Summary, four on TD Overview) and the mobile
/// designs wrap rather than shrink.
class CorpStatTileRow extends StatelessWidget {
  const CorpStatTileRow({
    super.key,
    required this.tiles,
    this.spacing = 12,
  });

  final List<CorpStatTile> tiles;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Below this a four-across row leaves no room for the figures, so
        // the tiles go two per line — matching the mobile designs.
        final perRow = width < 340
            ? 1
            : width < 520
                ? math.min(2, tiles.length)
                : tiles.length;

        if (perRow >= tiles.length) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  Expanded(child: tiles[i]),
                ],
              ],
            ),
          );
        }

        final tileWidth =
            (width - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

/// Muted caption on the left, action link on the right — the footer every
/// design ends with ("Total maturity value • £710K … View TD accounts →").
class CorpWidgetFooter extends StatelessWidget {
  const CorpWidgetFooter({
    super.key,
    this.caption,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String? caption;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final captionText = caption?.trim();
    final action = actionLabel?.trim();

    return Row(
      children: [
        if (captionText != null && captionText.isNotEmpty)
          Expanded(
            child: Text(
              captionText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                color: CorpColors.textSecondary(context),
              ),
            ),
          )
        else
          const Spacer(),
        if (action != null && action.isNotEmpty) ...[
          const SizedBox(width: 10),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action,
                    style: TextStyle(
                      fontSize: compact ? 11.5 : 12.5,
                      fontWeight: FontWeight.w700,
                      color: CorpColors.brand(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: compact ? 13 : 14,
                    color: CorpColors.brand(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Small rounded label — the date chips on TD Overview and the
/// "Due soon" / "Upcoming" status pills on Installments Due.
class CorpPill extends StatelessWidget {
  const CorpPill({
    super.key,
    required this.label,
    this.tone = CorpStatTone.info,
  });

  final String label;
  final CorpStatTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.fill(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tone.accent(context),
        ),
      ),
    );
  }
}

/// A slice of [CorpDonutChart].
class CorpDonutSlice {
  const CorpDonutSlice({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;
}

/// The ring on Loan Portfolio and TD Summary: proportional slices around a
/// centred caption.
///
/// Drawn with a [CustomPainter] rather than a charting package because the
/// app has no chart dependency and this is a ring with a hole — adding one
/// for a single shape would be a heavier change than the shape itself.
class CorpDonutChart extends StatelessWidget {
  const CorpDonutChart({
    super.key,
    required this.slices,
    required this.centerValue,
    this.centerLabel,
    this.size = 140,
    this.strokeWidth = 18,
  });

  final List<CorpDonutSlice> slices;
  final String centerValue;
  final String? centerLabel;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final label = centerLabel?.trim();

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          slices: slices,
          strokeWidth: strokeWidth,
          trackColor: CorpColors.divider(context),
        ),
        child: Center(
          child: Padding(
            // Keeps the caption inside the hole rather than under the ring.
            padding: EdgeInsets.all(strokeWidth + 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerValue,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: CorpColors.textPrimary(context),
                    ),
                  ),
                ),
                if (label != null && label.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.strokeWidth,
    required this.trackColor,
  });

  final List<CorpDonutSlice> slices;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);

    // No data: draw the empty ring so the widget keeps its shape rather
    // than collapsing to blank space while the list is still loading.
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = trackColor,
      );
      return;
    }

    // -90° so the first slice starts at twelve o'clock, as in the designs.
    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = slice.color,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.slices.length != slices.length ||
      _valuesDiffer(oldDelegate.slices, slices);

  static bool _valuesDiffer(
    List<CorpDonutSlice> a,
    List<CorpDonutSlice> b,
  ) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i].value != b[i].value || a[i].color != b[i].color) return true;
    }
    return false;
  }
}

/// The three-quarter arc on Loan Summary, filled to [progress] with the
/// percentage in the middle.
class CorpProgressGauge extends StatelessWidget {
  const CorpProgressGauge({
    super.key,
    required this.progress,
    this.size = 150,
    this.strokeWidth = 14,
    this.caption,
  });

  /// 0..1. Null renders the empty track and "—", which is what a host that
  /// sent no sanctioned amount should produce.
  final double? progress;

  final double size;
  final double strokeWidth;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final value = progress;
    final captionText = caption?.trim();

    return SizedBox(
      width: size,
      height: size * 0.78,
      child: CustomPaint(
        painter: _GaugePainter(
          progress: value ?? 0,
          strokeWidth: strokeWidth,
          fillColor: CorpColors.brand(context),
          trackColor: CorpColors.brand(context).withValues(alpha: 0.16),
        ),
        child: Align(
          alignment: const Alignment(0, 0.35),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value == null ? '—' : '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: CorpColors.brand(context),
                ),
              ),
              if (captionText != null && captionText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  captionText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.strokeWidth,
    required this.fillColor,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color fillColor;
  final Color trackColor;

  /// Opens at the bottom: starts at 135° and sweeps 270°, the shape the
  /// design draws.
  static const double _startAngle = math.pi * 0.75;
  static const double _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height / 0.78);
    final rect = Rect.fromLTWH(
      (size.width - diameter) / 2 + strokeWidth / 2,
      strokeWidth / 2,
      diameter - strokeWidth,
      diameter - strokeWidth,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, track);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle * clamped,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = fillColor,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.trackColor != trackColor;
}

/// Loading / empty / error body a widget shows in place of its content,
/// sized so the tile does not jump when the real content arrives.
class CorpWidgetPlaceholder extends StatelessWidget {
  const CorpWidgetPlaceholder({
    super.key,
    required this.height,
    this.isLoading = false,
    this.message,
  });

  final double height;
  final bool isLoading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  message ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Date formats the widget designs use.
///
/// Built per call with the widget's own locale rather than held as static
/// [DateFormat]s, so the month names follow the app's language switch
/// instead of being fixed to whatever locale was active at startup.
class CorpWidgetDate {
  const CorpWidgetDate._();

  /// `15 Oct 2026` — the full date on "Next maturity" and the row captions.
  static String full(DateTime? date, {String? locale, String placeholder = '—'}) {
    if (date == null) return placeholder;
    return DateFormat('dd MMM yyyy', locale).format(date);
  }

  /// `15 Oct` — the maturity chips and "Next payment" tile.
  static String short(DateTime? date, {String? locale, String placeholder = '—'}) {
    if (date == null) return placeholder;
    return DateFormat('dd MMM', locale).format(date);
  }

  /// `September 2026` — the widget subtitles.
  static String monthYear(DateTime? date, {String? locale}) {
    if (date == null) return '';
    return DateFormat('MMMM yyyy', locale).format(date);
  }

  /// `Sep 2026` — the mobile subtitles, which have less room.
  static String shortMonthYear(DateTime? date, {String? locale}) {
    if (date == null) return '';
    return DateFormat('MMM yyyy', locale).format(date);
  }

  /// The locale to format in, taken from the widget tree.
  static String localeOf(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag();
}

/// Palette for the donut slices — the design's teal ramp, ordered so the
/// largest slice gets the strongest colour.
class CorpChartPalette {
  const CorpChartPalette._();

  static List<Color> of(BuildContext context) {
    final colors = AppColors.of(context);
    return [
      colors.brand,
      colors.accentCyan,
      colors.brandDark,
      colors.info,
      colors.success,
      colors.warning,
    ];
  }

  /// [of] cycled, so a portfolio with more products than colours still
  /// draws every slice.
  static Color at(BuildContext context, int index) {
    final palette = of(context);
    return palette[index % palette.length];
  }
}
