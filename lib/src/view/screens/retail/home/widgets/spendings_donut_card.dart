import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_card_surface.dart';

/// "My Spendings" donut chart — replaces the old monthly bar chart.
///
/// Shows total spend for the period, a vs-last-month delta badge and a
/// category legend, matching the redesigned Home screen (web + mobile).
class SpendingsDonutCard extends StatelessWidget {
  const SpendingsDonutCard({
    super.key,
    this.periodLabel = 'This Month',
    this.currencyCode = 'GBP',
    this.stacked = false,
    this.onOpen,
  });

  /// Phone Home design: thin ring on top, "+12% vs Last Month" under it
  /// and a two-column legend; a chevron in the header.
  final bool stacked;

  /// The header chevron (stacked layout).
  final VoidCallback? onOpen;

  final String periodLabel;
  final String currencyCode;

  // TODO: replace with live spend-by-category data once an
  // insights/spendings API is wired up; kept as static demo data so the
  // component matches the design while the backend integration lands.
  static const _categories = <_SpendCategory>[
    _SpendCategory('Food & Dining', 1120, Color(0xFFFFC94A)),
    _SpendCategory('Travel', 636, Color(0xFFFF9F5A)),
    _SpendCategory('Shop', 604, Color(0xFF29C7E8)),
    _SpendCategory('Entertain', 445, Color(0xFFE64FCB)),
    _SpendCategory('Bill & Utilities', 254, Color(0xFF3B7DFF)),
    _SpendCategory('Others', 123, Color(0xFFB9C0C7)),
  ];
  /// Phone design colours, legend order (two columns). Demo amounts in the
  /// reference's proportions (still static until a spendings API exists);
  /// they add up to the same 3,182 total.
  static const _designLegend = <_SpendCategory>[
    _SpendCategory('Food & Dining', 820, Color(0xFF1EC3E0)),
    _SpendCategory('Travel', 560, Color(0xFFFFA347)),
    _SpendCategory('Shop', 230, Color(0xFFA78BFA)),
    _SpendCategory('Entertain', 480, Color(0xFFE85BD6)),
    _SpendCategory('Bill & Utilities', 300, Color(0xFFF472B6)),
    _SpendCategory('Others', 792, Color(0xFFFDE047)),
  ];

  /// Same data in the design's ring order (clockwise from the top):
  /// cyan, purple, pinks, orange, yellow.
  static final _designRing = <_SpendCategory>[
    _designLegend[0],
    _designLegend[2],
    _designLegend[3],
    _designLegend[4],
    _designLegend[1],
    _designLegend[5],
  ];

  static const _totalSpend = 3182.0;
  static const _percentVsLastMonth = 12;

  @override
  Widget build(BuildContext context) {
    final total = MoneyFormat.format(_totalSpend, currencyCode: currencyCode);

    return DashboardCardSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: HomeColors.brandLight(context).withValues(alpha: 0.30),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Spendings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: stacked
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: HomeColors.textSecondary(context),
                        ),
                      )
                    : BoxDecoration(
                        color: HomeColors.backgroundSecondary(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      periodLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HomeColors.textSecondary(context),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: HomeColors.textSecondary(context),
                    ),
                  ],
                ),
              ),
              if (stacked && onOpen != null)
                IconButton(
                  tooltip: 'My Spendings',
                  onPressed: onOpen,
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (stacked) ..._stackedBody(context, total) else Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Expanded(
      flex: 5,
      child: Center(
        child: _Animated3DDonut(
          categories: _categories,
          total: total,
        ),
      ),
    ),

    const SizedBox(width: 20),

    Expanded(
      flex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: HomeColors.success(context)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+$_percentVsLastMonth%',
              style: TextStyle(
                color: HomeColors.success(context),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'vs Last Month',
            style: TextStyle(
              fontSize: 12,
              color: HomeColors.textSecondary(context),
            ),
          ),

          const SizedBox(height: 18),

          ..._categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LegendDot(
                color: c.color,
                label: c.label,
                context: context,
              ),
            ),
          ),
        ],
      ),
    ),
  ],
),

        ],
      ),
    );
  }
}

extension on SpendingsDonutCard {
  /// Donut, change vs last month, two-column legend (phone design).
  List<Widget> _stackedBody(BuildContext context, String total) => [
        Center(
          child: _Animated3DDonut(
            categories: SpendingsDonutCard._designRing,
            // Design shows the whole amount ("3,182").
            total: total.replaceAll(RegExp(r'\.00$'), ''),
            thin: true,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: HomeColors.success(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${SpendingsDonutCard._percentVsLastMonth}%',
                    style: TextStyle(
                      color: HomeColors.success(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: HomeColors.success(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'vs Last Month',
              style: TextStyle(
                fontSize: 12.5,
                color: HomeColors.textSecondary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            runSpacing: 10,
            children: [
              for (final c in SpendingsDonutCard._designLegend)
                SizedBox(
                  width: constraints.maxWidth / 2,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.color, width: 2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          c.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: HomeColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ];
}

class _SpendCategory {
  const _SpendCategory(this.label, this.amount, this.color);

  final String label;
  final double amount;
  final Color color;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.context,
  });

  final Color color;
  final String label;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: HomeColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.progress,
    this.thin = false,
  });

  /// Thin flat ring (phone design) instead of the thick 3D one.
  final bool thin;

  final List<double> values;
  final List<Color> colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final stroke = size.width * (thin ? 0.055 : 0.16);
    final radius = (size.width - stroke) / 2;
    final gapRadians = thin ? 0.16 : 0.045;

    var startAngle = -1.5707963267948966; // -90deg
for (var i = 0; i < values.length; i++) {
  final sweep =
      (((values[i] / total) * (2 * 3.141592653589793)) - gapRadians) *
      progress;

final paint = Paint()
  ..color = colors[i]
  ..style = PaintingStyle.stroke
  ..strokeWidth = stroke
  ..strokeCap = StrokeCap.round;

  // bottom depth (3D look only)
  if (!thin) {
  canvas.drawArc(
    Rect.fromCircle(
      center: center.translate(0, 8),
      radius: radius,
    ),
    startAngle,
    sweep < 0 ? 0 : sweep,
    false,
    Paint()
      ..color = colors[i].withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round,
  );
  }

  // actual bright donut
  canvas.drawArc(
    Rect.fromCircle(
      center: center,
      radius: radius,
    ),
    startAngle,
    sweep < 0 ? 0 : sweep,
    false,
    paint,
  );

  startAngle +=
      (values[i] / total) * (2 * 3.141592653589793);
}
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors || oldDelegate.progress != progress;
  }
}

class _Animated3DDonut extends StatefulWidget {
  const _Animated3DDonut({
    required this.categories,
    required this.total,
    this.thin = false,
  });

  final bool thin;

  final List<_SpendCategory> categories;
  final String total;

  @override
  State<_Animated3DDonut> createState() => _Animated3DDonutState();
}

class _Animated3DDonutState extends State<_Animated3DDonut>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  /// The draw-in animation plays once per app run. Home is rebuilt every
  /// time the user comes back to it, and replaying 1.8 s of animation
  /// each time made the cards look like they were still loading.
  static bool _playedOnce = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (_playedOnce) {
      _controller.value = 1;
    } else {
      _playedOnce = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform(
          alignment: Alignment.center,
          transform: widget.thin
              ? Matrix4.identity()
              : (Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(-0.18)
                ..rotateY(
                  0.15 * (1 - _controller.value),
                )),
          child: SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(230, 230),
                  painter: _DonutPainter(
                    thin: widget.thin,
                    values: widget.categories
                        .map((e) => e.amount)
                        .toList(),
                    colors: widget.categories
                        .map((e) => e.color)
                        .toList(),
                    progress: _controller.value,
                  ),
                ),
                // Fits inside the ring's hole — long amounts shrink instead
                // of running over the ring.
                SizedBox(
                  width: widget.thin ? 170 : 112,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Spendings',
                      style: TextStyle(
                        fontSize: widget.thin ? 13 : 11,
                        color: HomeColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.total,
                      style: TextStyle(
                        fontSize: widget.thin ? 28 : 22,
                        fontWeight: widget.thin ? FontWeight.w700 : FontWeight.w800,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
