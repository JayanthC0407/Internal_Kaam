import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Building blocks the Corporate dashboard widget designs share — the
/// Loans, Term Deposit and Cash Flow widgets are all a header, a row of
/// tinted figure tiles, and a panel below.
///
/// Every piece reads its colours from the theme, so the widgets work in
/// dark mode, and none assumes a width: a widget decides between its web
/// and mobile arrangement with [CorpWidgetLayout.isCompact].

/// Width below which a widget uses its mobile arrangement. Covers phones
/// and a narrow dashboard column alike, so it is measured on the widget,
/// not the screen.
class CorpWidgetLayout {
  const CorpWidgetLayout._();

  static const double compactBelow = 460;

  static bool isCompact(BoxConstraints constraints) =>
      constraints.maxWidth < compactBelow;
}

/// The design's colour families for figure tiles, chips and toggles.
enum CorpTone { blue, green, amber, red, neutral }

class CorpToneColors {
  const CorpToneColors({
    required this.fill,
    required this.border,
    required this.label,
  });

  final Color fill;
  final Color border;

  /// Label text on [fill].
  final Color label;

  static CorpToneColors of(BuildContext context, CorpTone tone) {
    final base = switch (tone) {
      CorpTone.blue => const Color(0xFF0E7F9A),
      CorpTone.green => const Color(0xFF2E9E4F),
      CorpTone.amber => const Color(0xFFB7791F),
      CorpTone.red => const Color(0xFFC0392B),
      CorpTone.neutral => const Color(0xFF52606D),
    };
    if (Theme.of(context).brightness == Brightness.dark) {
      return CorpToneColors(
        fill: base.withValues(alpha: 0.16),
        border: base.withValues(alpha: 0.34),
        label: Color.lerp(base, Colors.white, 0.45)!,
      );
    }
    final (fill, border) = switch (tone) {
      CorpTone.blue => const (Color(0xFFF0FAFD), Color(0xFFD3EFF7)),
      CorpTone.green => const (Color(0xFFF1FAF3), Color(0xFFD9F0DF)),
      CorpTone.amber => const (Color(0xFFFFF8EA), Color(0xFFF6E6C3)),
      CorpTone.red => const (Color(0xFFFFF3F1), Color(0xFFF7DAD5)),
      CorpTone.neutral => const (Color(0xFFF6F8FA), Color(0xFFE4EAEF)),
    };
    return CorpToneColors(fill: fill, border: border, label: base);
  }
}

/// Chart colours from the designs: the deep teal the gauges and bars use,
/// its light tint, the ring track, and a dark accent for a third series.
class CorpChartColors {
  const CorpChartColors._();

  static const Color primary = Color(0xFF1497B0);
  static const Color light = Color(0xFF7FDBF0);
  static const Color deep = Color(0xFF0B4F5E);
  static const Color mint = Color(0xFF2DD4BF);

  /// A figure drawn inside a chart — [deep], lightened on a dark card.
  static Color figure(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? light : deep;

  static Color track(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? primary.withValues(alpha: 0.22)
          : const Color(0xFFD9F4FA);
}

/// The soft panel the designs set charts, timelines and lists on.
Color corpInsetColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? CorpColors.of(context).surfaceSecondary
        : const Color(0xFFF4F8FB);

/// A widget's heading: title, a one-line subtitle, and an optional action
/// on the right. [sample] adds the "Sample data" tag while the widget shows
/// illustrative figures.
class CorpWidgetHeader extends StatelessWidget {
  const CorpWidgetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.sample = false,
    this.compact = false,
  });

  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool sample;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final heading = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 16 : 17,
            fontWeight: FontWeight.w700,
            color: CorpColors.textPrimary(context),
          ),
        ),
        if (sample) const CorpSampleDataTag(),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 12,
                    color: CorpColors.textSecondary(context),
                  ),
                  child: subtitle!,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// Plain-text subtitle for [CorpWidgetHeader].
class CorpSubtitle extends StatelessWidget {
  const CorpSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
}

/// Marks figures as illustrative. Shown on every widget that is not yet
/// connected to live data, so nobody mistakes the design's numbers for
/// their own.
class CorpSampleDataTag extends StatelessWidget {
  const CorpSampleDataTag({super.key});

  @override
  Widget build(BuildContext context) {
    final tone = CorpToneColors.of(context, CorpTone.amber);
    return Tooltip(
      message: 'Illustrative figures — live data is not connected yet.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: tone.fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.border),
        ),
        child: Text(
          'Sample data',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: tone.label,
          ),
        ),
      ),
    );
  }
}

/// Tells the user a link has nowhere to go yet, because the widget shows
/// sample data rather than their own records.
void showCorpSampleDataNotice(BuildContext context, String what) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$what will open here once live data is connected.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}

/// One tinted figure: a small coloured label over a bold value.
class CorpStatTile extends StatelessWidget {
  const CorpStatTile({
    super.key,
    required this.label,
    required this.value,
    this.tone = CorpTone.blue,
    this.caption,
    this.valueColor,
    this.valueSize = 17,
  });

  final String label;
  final String value;
  final CorpTone tone;

  /// Optional third line, e.g. "Mar 2027" or "▲ 8.4% vs previous period".
  final Widget? caption;
  final Color? valueColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final colors = CorpToneColors.of(context, tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shrinks rather than truncates on a narrow phone tile —
          // "Outstandi…" says less than a slightly smaller "Outstanding".
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.label,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.w700,
                color: valueColor ?? CorpColors.textPrimary(context),
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 11.5,
                color: CorpColors.textSecondary(context),
              ),
              child: caption!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays [tiles] out as many to a row as fit at [minTileWidth], equal
/// widths, equal heights per row — four across on web, two by two on a
/// phone, without the widget choosing.
class CorpStatRow extends StatelessWidget {
  const CorpStatRow({
    super.key,
    required this.tiles,
    this.minTileWidth = 120,
    this.gap = 10,
    this.maxPerRow,
  });

  final List<Widget> tiles;
  final double minTileWidth;
  final double gap;
  final int? maxPerRow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = ((constraints.maxWidth + gap) / (minTileWidth + gap))
            .floor()
            .clamp(1, math.max(1, tiles.length))
            .toInt();
        final perRow = math.min(fit, maxPerRow ?? tiles.length);
        final rows = <Widget>[];
        for (var start = 0; start < tiles.length; start += perRow) {
          final chunk = tiles.sublist(
            start,
            math.min(start + perRow, tiles.length),
          );
          rows.add(
            // Bounds the stretched row to its tallest tile; see the note
            // in CorpFinancialSummaryWidget.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < chunk.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(child: chunk[i]),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

/// The designs' "View … →" text action.
class CorpWidgetLink extends StatelessWidget {
  const CorpWidgetLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        // A comfortable tap target on a phone.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        // The arrow is an icon: the app font (Rubik) has no "→" glyph.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: CorpColors.brand(context),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: CorpColors.brand(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded panel on [corpInsetColor].
class CorpInsetPanel extends StatelessWidget {
  const CorpInsetPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? corpInsetColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// A headline figure on a tinted panel — the Cash Flow widgets' "Net
/// cashflow +£41.7K". [detail] sits beside the figure, or under it when
/// [stacked] (a phone).
class CorpHighlightPanel extends StatelessWidget {
  const CorpHighlightPanel({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.tone = CorpTone.green,
    this.stacked = false,
  });

  final String label;
  final String value;
  final String? detail;
  final CorpTone tone;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final colors = CorpToneColors.of(context, tone);
    final figure = Text(
      value,
      style: TextStyle(
        fontSize: stacked ? 22 : 26,
        fontWeight: FontWeight.w700,
        color: colors.label,
      ),
    );
    final note = detail == null
        ? null
        : Text(
            detail!,
            style: TextStyle(
              fontSize: 12,
              color: CorpColors.textSecondary(context),
            ),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.label,
            ),
          ),
          const SizedBox(height: 6),
          if (stacked || note == null) ...[
            figure,
            if (note != null) ...[const SizedBox(height: 4), note],
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                figure,
                const SizedBox(width: 18),
                Expanded(child: note),
              ],
            ),
        ],
      ),
    );
  }
}

/// A small coloured pill — "Active", "Due soon", "Upcoming".
class CorpStatusChip extends StatelessWidget {
  const CorpStatusChip({super.key, required this.label, required this.tone});

  final String label;
  final CorpTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = CorpToneColors.of(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.label,
        ),
      ),
    );
  }
}

/// How [CorpSegmentedToggle] marks the selected segment.
enum CorpToggleStyle {
  /// A light tint with brand text.
  tinted,

  /// Solid brand with white text — the TD Summary's phone switch.
  solid,
}

/// Two or more pill segments, one selected — the designs' Upcoming /
/// Overdue and Tabular / Graphical switches. [expand] stretches the
/// segments across the available width, as on a phone.
class CorpSegmentedToggle<T> extends StatelessWidget {
  const CorpSegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.expand = false,
    this.style = CorpToggleStyle.tinted,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand;
  final CorpToggleStyle style;

  @override
  Widget build(BuildContext context) {
    final selected = CorpToneColors.of(context, CorpTone.blue);
    final segments = [
      for (final entry in options.entries)
        _segment(context, entry.key, entry.value, selected),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CorpColors.cardBorder(context)),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final segment in segments)
            expand ? Expanded(child: segment) : segment,
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    T key,
    String label,
    CorpToneColors selected,
  ) {
    final isSelected = key == value;
    final solid = style == CorpToggleStyle.solid;
    final fill = solid ? CorpColors.brand(context) : selected.fill;
    final outline = solid ? CorpColors.brand(context) : selected.border;
    final selectedText = solid ? Colors.white : CorpColors.brand(context);
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: isSelected ? null : () => onChanged(key),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          // Stretched segments share a phone's width, so they give up
          // padding first and then shrink their label, never wrap it.
          padding: EdgeInsets.symmetric(
            horizontal: expand ? 6 : 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? fill : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? outline : Colors.transparent,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? selectedText
                    : CorpColors.textSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A coloured dot with a label — chart legends.
class CorpLegendDot extends StatelessWidget {
  const CorpLegendDot({
    super.key,
    required this.color,
    required this.label,
    this.value,
  });

  final Color color;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: CorpColors.textPrimary(context),
          ),
        ),
        if (value != null) ...[
          const SizedBox(width: 6),
          Text(
            value!,
            style: TextStyle(
              fontSize: 12.5,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// An open ring filled to [progress] (0–1), with [center] inside — the
/// Loan Summary's repayment gauge.
class CorpGauge extends StatelessWidget {
  const CorpGauge({
    super.key,
    required this.progress,
    required this.center,
    this.size = 120,
    this.strokeWidth = 12,
  });

  final double progress;
  final Widget center;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GaugePainter(
          progress: progress.clamp(0.0, 1.0),
          color: CorpChartColors.primary,
          track: CorpChartColors.track(context),
          strokeWidth: strokeWidth,
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  // Open at the bottom: from 7:30 round to 4:30.
  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _start, _sweep, false, stroke(track));
    if (progress > 0) {
      canvas.drawArc(rect, _start, _sweep * progress, false, stroke(color));
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// One slice of a [CorpDonut].
class CorpDonutSegment {
  const CorpDonutSegment({required this.value, required this.color});

  final double value;
  final Color color;
}

/// A ring split into [segments] by value, with [center] inside — the Loan
/// Portfolio mix and the TD maturity composition.
class CorpDonut extends StatelessWidget {
  const CorpDonut({
    super.key,
    required this.segments,
    required this.center,
    this.size = 140,
    this.strokeWidth = 16,
  });

  final List<CorpDonutSegment> segments;
  final Widget center;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DonutPainter(
          segments: segments,
          strokeWidth: strokeWidth,
          track: CorpChartColors.track(context),
        ),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.track,
  });

  final List<CorpDonutSegment> segments;
  final double strokeWidth;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
      return;
    }
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = math.pi * 2 * segment.value / total;
      canvas.drawArc(rect, start, sweep, false, paint..color = segment.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments || old.track != track;
}

/// A table widget's search box, filter menu and download button — the
/// Loan and Finance Summary's and the TD Summary's. Labelled buttons on
/// web; icons beside a full-width search box when [iconsOnly].
///
/// [filters] maps each filter value to its menu label; the `null` entry,
/// when present, is "no filter" and shows the button as plain "Filter".
class CorpTableTools<T> extends StatelessWidget {
  const CorpTableTools({
    super.key,
    required this.controller,
    required this.hint,
    required this.filter,
    required this.filters,
    required this.iconsOnly,
    required this.onSearch,
    required this.onFilter,
    required this.onDownload,
    this.filterTooltip = 'Filter',
  });

  final TextEditingController controller;
  final String hint;
  final T? filter;
  final Map<T?, String> filters;
  final bool iconsOnly;
  final VoidCallback onSearch;
  final ValueChanged<T?> onFilter;
  final VoidCallback onDownload;
  final String filterTooltip;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: CorpColors.cardBorder(context)),
    );
    final search = TextField(
      controller: controller,
      onChanged: (_) => onSearch(),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: CorpColors.textSecondary(context),
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: border,
        enabledBorder: border,
      ),
    );

    final filterMenu = PopupMenuButton<T?>(
      tooltip: filterTooltip,
      initialValue: filter,
      onSelected: onFilter,
      itemBuilder: (context) => [
        for (final entry in filters.entries)
          PopupMenuItem<T?>(value: entry.key, child: Text(entry.value)),
      ],
      child: _ToolButton(
        icon: Icons.filter_list_rounded,
        label: filter == null ? 'Filter' : (filters[filter] ?? 'Filter'),
        iconOnly: iconsOnly,
        active: filter != null,
      ),
    );
    final download = Tooltip(
      message: 'Download',
      child: InkWell(
        onTap: onDownload,
        borderRadius: BorderRadius.circular(10),
        child: _ToolButton(
          icon: Icons.download_rounded,
          label: 'Download',
          iconOnly: iconsOnly,
        ),
      ),
    );

    if (iconsOnly) {
      return Row(
        children: [
          Expanded(child: search),
          const SizedBox(width: 8),
          filterMenu,
          const SizedBox(width: 8),
          download,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 220, child: search),
        const SizedBox(width: 8),
        filterMenu,
        const SizedBox(width: 8),
        download,
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.iconOnly,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool iconOnly;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? CorpColors.brand(context) : CorpColors.textPrimary(context);
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? 10 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? CorpColors.brand(context)
              : CorpColors.cardBorder(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          if (!iconOnly) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when a search or filter leaves a table empty.
class CorpNoMatch extends StatelessWidget {
  const CorpNoMatch({
    super.key,
    required this.onClear,
    this.message = 'No accounts match your search.',
  });

  final VoidCallback onClear;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CorpInsetPanel(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 12.5,
              color: CorpColors.textSecondary(context),
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ),
    );
  }
}

/// The currency a widget's figures are in, for everything below it.
///
/// Live widgets put one around the design widget with the accounts'
/// currency; without one — the sample figures — amounts show in £, the
/// designs' currency.
class CorpCurrency extends InheritedWidget {
  const CorpCurrency({super.key, required this.symbol, required super.child});

  /// The prefix amounts are written with: `£`, `\$`, or a code and a space
  /// (`AED `) — see [CorpFigures.symbolFor].
  final String symbol;

  static const String sampleSymbol = '£';

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CorpCurrency>()?.symbol ??
      sampleSymbol;

  @override
  bool updateShouldNotify(CorpCurrency old) => old.symbol != symbol;
}

/// What a live widget shows while its figures are not there to show:
/// loading, a failure with Retry, or nothing to report. One card for every
/// widget, titled with the widget's own name, so a dashboard of them reads
/// the same whatever state each is in.
class CorpWidgetStatusCard extends StatelessWidget {
  const CorpWidgetStatusCard.loading({super.key, required this.title})
      : message = null,
        icon = null,
        onRetry = null,
        isLoading = true;

  const CorpWidgetStatusCard.error({
    super.key,
    required this.title,
    required String this.message,
    required VoidCallback this.onRetry,
  })  : icon = Icons.cloud_off_rounded,
        isLoading = false;

  const CorpWidgetStatusCard.empty({
    super.key,
    required this.title,
    required String this.message,
    this.icon = Icons.inbox_outlined,
  })  : onRetry = null,
        isLoading = false;

  final String title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpWidgetHeader(title: title),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator(strokeWidth: 2.4)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 28,
                          color: CorpColors.navInactive(context),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: CorpColors.textSecondary(context),
                          ),
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: onRetry,
                            child: const Text('Retry'),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short money and date text in the designs' style.
class CorpFigures {
  const CorpFigures._();

  /// The prefix [compact] and [full] write amounts in [currencyCode] with:
  /// the familiar sign for the common currencies, the code otherwise
  /// (`AED 824K`), and nothing when there is no code — never a guess.
  static String symbolFor(String? currencyCode) {
    final code = currencyCode?.trim().toUpperCase() ?? '';
    return switch (code) {
      'GBP' => '£',
      'USD' => '\$',
      'EUR' => '€',
      '' => '',
      _ => '$code ',
    };
  }

  /// `£824K`, `£12.8K`, `£1.20M`, `£8.42B` — abbreviated amounts for
  /// figure tiles, where the full value would not fit.
  ///
  /// Thousands from 100K up are whole unless [precise], which keeps one
  /// decimal (`£128.1K`) where the difference matters — a deposit's
  /// maturity value against its principal.
  static String compact(
    double amount, {
    String symbol = '£',
    bool precise = false,
  }) {
    final sign = amount < 0 ? '-' : '';
    final value = amount.abs();
    String body;
    // Three significant figures for millions and billions: £1.20M,
    // £46.0M, £409M.
    String sig(double v) => v.toStringAsFixed(v < 10 ? 2 : (v < 100 ? 1 : 0));
    if (value >= 1e9) {
      body = '${sig(value / 1e9)}B';
    } else if (value >= 1e6) {
      body = '${sig(value / 1e6)}M';
    } else if (value >= 1e5 && !precise) {
      body = '${(value / 1e3).toStringAsFixed(0)}K';
    } else if (value >= 1e3) {
      body = '${_trimZero((value / 1e3).toStringAsFixed(1))}K';
    } else {
      body = value.toStringAsFixed(0);
    }
    return '$sign$symbol$body';
  }

  /// `+£41.7K` / `-£3.2K` — a movement, always signed.
  static String signedCompact(double amount, {String symbol = '£'}) =>
      amount < 0
          ? compact(amount, symbol: symbol)
          : '+${compact(amount, symbol: symbol)}';

  /// `£50,000` — the whole amount, grouped.
  static String full(double amount, {String symbol = '£'}) {
    final digits = amount.abs().toStringAsFixed(0);
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '${amount < 0 ? '-' : ''}$symbol$grouped';
  }

  /// `7.25%`.
  static String percent(double value, {int decimals = 2}) =>
      '${value.toStringAsFixed(decimals)}%';

  /// [percent], or `—` when the host gave no rate.
  static String percentOr(double? value, {int decimals = 2}) =>
      value == null ? '—' : percent(value, decimals: decimals);

  /// [date], or `—` when there is none.
  static String dateOr(DateTime? d) => d == null ? '—' : date(d);

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  static String _month(DateTime d) => _months[d.month - 1];
  static String _shortMonth(DateTime d) => _month(d).substring(0, 3);
  static String _day(DateTime d) => d.day.toString().padLeft(2, '0');

  /// `28 Sep`.
  static String dayMonth(DateTime d) => '${_day(d)} ${_shortMonth(d)}';

  /// `28 Sep 2026`.
  static String date(DateTime d) => '${dayMonth(d)} ${d.year}';

  /// `September 2026`.
  static String monthYear(DateTime d) => '${_month(d)} ${d.year}';

  /// `Sep 2026`.
  static String shortMonthYear(DateTime d) => '${_shortMonth(d)} ${d.year}';

  /// `4Y 8M` — a tenure in months.
  static String tenure(int months) {
    final years = months ~/ 12;
    final rest = months % 12;
    if (years == 0) return '${rest}M';
    if (rest == 0) return '${years}Y';
    return '${years}Y ${rest}M';
  }

  static String _trimZero(String s) =>
      s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
