import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';

/// One set of bars in a [CorpBarChart] — inflow, say.
@immutable
class CorpBarSeries {
  const CorpBarSeries({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;

  /// One value per group, non-negative.
  final List<double> values;
}

/// Grouped vertical bars, one group per label, with an optional line
/// through the groups (the Cash Flow Trend's surplus / deficit).
///
/// Built for the dashboard's widths rather than a fixed size:
///  - bars keep a readable minimum width; when the groups do not fit, the
///    plot scrolls sideways and the value axis stays put beside it;
///  - labels thin themselves out instead of overlapping;
///  - tapping (or clicking) a group shows its figures above the plot,
///    which is how a phone user reads exact values.
class CorpBarChart extends StatefulWidget {
  const CorpBarChart({
    super.key,
    required this.labels,
    required this.series,
    required this.valueLabel,
    this.detailLabels,
    this.line,
    this.lineLabel = 'Net',
    this.height = 220,
    this.showAxis = true,
    this.minGroupWidth = 22,
  });

  /// Short label under each group.
  final List<String> labels;

  /// Longer label for a group in the tapped-group caption; defaults to
  /// [labels].
  final List<String>? detailLabels;
  final List<CorpBarSeries> series;

  /// Values for the line, one per group; may be negative.
  final List<double>? line;
  final String lineLabel;

  /// Formats a value for the axis and the caption.
  final String Function(double value) valueLabel;
  final double height;
  final bool showAxis;
  final double minGroupWidth;

  static const lineColor = Color(0xFF7B8794);

  @override
  State<CorpBarChart> createState() => _CorpBarChartState();
}

class _CorpBarChartState extends State<CorpBarChart> {
  int? _selected;

  @override
  void didUpdateWidget(CorpBarChart old) {
    super.didUpdateWidget(old);
    // A new period or grouping: the old index means something else now.
    if (old.labels.length != widget.labels.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.labels.length;
    if (count == 0) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No figures for this period.',
            style: TextStyle(
              fontSize: 12.5,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ),
      );
    }

    final scale = _Scale.of([
      for (final s in widget.series) ...s.values,
      ...?widget.line,
    ]);
    // Painted text does not inherit the app's font; take it from the
    // ambient style.
    final textStyle = DefaultTextStyle.of(context).style.copyWith(
          fontSize: 10.5,
          color: CorpColors.textSecondary(context),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caption(
          index: _selected,
          label: _selected == null
              ? null
              : (widget.detailLabels ?? widget.labels)[_selected!],
          series: widget.series,
          line: widget.line,
          lineLabel: widget.lineLabel,
          valueLabel: widget.valueLabel,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showAxis)
                SizedBox(
                  width: _axisWidth(scale, textStyle),
                  child: CustomPaint(
                    painter: _AxisPainter(
                      scale: scale,
                      valueLabel: widget.valueLabel,
                      style: textStyle,
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fits =
                        constraints.maxWidth / count >= widget.minGroupWidth;
                    final width = fits
                        ? constraints.maxWidth
                        : count * widget.minGroupWidth;
                    final plot = GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final index =
                            (details.localPosition.dx / (width / count))
                                .floor()
                                .clamp(0, count - 1)
                                .toInt();
                        setState(() {
                          _selected = _selected == index ? null : index;
                        });
                      },
                      child: CustomPaint(
                        size: Size(width, widget.height),
                        painter: _BarsPainter(
                          labels: widget.labels,
                          series: widget.series,
                          line: widget.line,
                          scale: scale,
                          selected: _selected,
                          grid: CorpColors.divider(context),
                          highlight: CorpColors.tableRowHover(context),
                          style: textStyle,
                        ),
                      ),
                    );
                    if (fits) return plot;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: width, child: plot),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final s in widget.series)
              CorpLegendDot(color: s.color, label: s.label),
            if (widget.line != null)
              CorpLegendDot(
                color: CorpBarChart.lineColor,
                label: widget.lineLabel,
              ),
          ],
        ),
      ],
    );
  }

  /// Wide enough for the longest tick label, so none wraps.
  double _axisWidth(_Scale scale, TextStyle style) {
    var widest = 0.0;
    for (final t in scale.ticks) {
      final painter = TextPainter(
        text: TextSpan(text: widget.valueLabel(t), style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
    }
    return widest + 8;
  }
}

/// The figures for the tapped group, or a hint when none is.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.index,
    required this.label,
    required this.series,
    required this.line,
    required this.lineLabel,
    required this.valueLabel,
  });

  final int? index;
  final String? label;
  final List<CorpBarSeries> series;
  final List<double>? line;
  final String lineLabel;
  final String Function(double) valueLabel;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 11.5,
      color: CorpColors.textSecondary(context),
    );
    final i = index;
    if (i == null) {
      return Text('Tap a bar to see its figures', style: muted);
    }
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        Text(
          label!,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: CorpColors.textPrimary(context),
          ),
        ),
        for (final s in series)
          Text('${s.label} ${valueLabel(s.values[i])}', style: muted),
        if (line != null)
          Text('$lineLabel ${valueLabel(line![i])}', style: muted),
      ],
    );
  }
}

/// The value range the plot covers, rounded out to tidy ticks.
class _Scale {
  const _Scale(this.min, this.max, this.step);

  factory _Scale.of(List<double> values) {
    var lo = 0.0;
    var hi = 0.0;
    for (final v in values) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    if (hi == lo) hi = lo + 1;
    // About five intervals: close enough to the data not to waste room
    // below zero for a small deficit.
    final step = _niceStep((hi - lo) / 5);
    return _Scale(
      (lo / step).floorToDouble() * step,
      (hi / step).ceilToDouble() * step,
      step,
    );
  }

  final double min;
  final double max;
  final double step;

  /// 1, 2, 2.5 or 5 times a power of ten.
  static double _niceStep(double raw) {
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
    for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (raw <= m * magnitude) return m * magnitude.toDouble();
    }
    return 10.0 * magnitude;
  }

  Iterable<double> get ticks sync* {
    for (var t = min; t <= max + step / 2; t += step) {
      yield t;
    }
  }

  double y(double value, double top, double height) =>
      top + (max - value) / (max - min) * height;
}

/// Space under the plot for the group labels.
const double _labelBand = 20;
const double _plotTop = 6;

class _AxisPainter extends CustomPainter {
  _AxisPainter({
    required this.scale,
    required this.valueLabel,
    required this.style,
  });

  final _Scale scale;
  final String Function(double) valueLabel;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _labelBand - _plotTop;
    for (final t in scale.ticks) {
      final painter = TextPainter(
        text: TextSpan(text: valueLabel(t), style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 6);
      final y = scale.y(t, _plotTop, plotHeight);
      painter.paint(
        canvas,
        Offset(size.width - 6 - painter.width, y - painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      old.scale.max != scale.max || old.scale.min != scale.min;
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.labels,
    required this.series,
    required this.line,
    required this.scale,
    required this.selected,
    required this.grid,
    required this.highlight,
    required this.style,
  });

  final List<String> labels;
  final List<CorpBarSeries> series;
  final List<double>? line;
  final _Scale scale;
  final int? selected;
  final Color grid;
  final Color highlight;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final count = labels.length;
    final plotHeight = size.height - _labelBand - _plotTop;
    final groupWidth = size.width / count;
    double y(double v) => scale.y(v, _plotTop, plotHeight);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final t in scale.ticks) {
      canvas.drawLine(Offset(0, y(t)), Offset(size.width, y(t)), gridPaint);
    }

    if (selected != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            selected! * groupWidth,
            _plotTop,
            groupWidth,
            plotHeight,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = highlight,
      );
    }

    // Bars: a quarter of each group is gap; each bar at most 28 wide.
    final n = series.length;
    final barGap = math.min(4.0, groupWidth * 0.06);
    final barWidth = math.min(
      28.0,
      (groupWidth * 0.75 - barGap * (n - 1)) / n,
    );
    final groupSpan = barWidth * n + barGap * (n - 1);
    final zero = y(0);
    for (var i = 0; i < count; i++) {
      var x = i * groupWidth + (groupWidth - groupSpan) / 2;
      for (final s in series) {
        final top = y(s.values[i]);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(x, math.min(top, zero), x + barWidth, zero),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          Paint()..color = s.color,
        );
        x += barWidth + barGap;
      }
    }

    final points = line;
    if (points != null && points.length == count) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final p = Offset((i + 0.5) * groupWidth, y(points[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = CorpBarChart.lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final dot = Paint()..color = CorpBarChart.lineColor;
      for (var i = 0; i < count; i++) {
        canvas.drawCircle(
          Offset((i + 0.5) * groupWidth, y(points[i])),
          2.5,
          dot,
        );
      }
    }

    // Labels, skipping some when they would collide.
    final painters = [
      for (final l in labels)
        TextPainter(
          text: TextSpan(text: l, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final widest = painters.fold<double>(0, (w, p) => math.max(w, p.width));
    final every = math.max(1, ((widest + 6) / groupWidth).ceil());
    for (var i = 0; i < count; i += every) {
      final p = painters[i];
      // Centred on the group, but kept inside the plot at either end.
      final x = ((i + 0.5) * groupWidth - p.width / 2)
          .clamp(0.0, math.max(0.0, size.width - p.width))
          .toDouble();
      p.paint(canvas, Offset(x, size.height - _labelBand + 4));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.labels != labels ||
      old.series != series ||
      old.line != line ||
      old.selected != selected ||
      old.grid != grid;
}
