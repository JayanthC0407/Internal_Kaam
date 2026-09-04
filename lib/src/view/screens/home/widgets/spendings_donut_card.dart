import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// "My Spendings" donut chart — replaces the old monthly bar chart.
///
/// Shows total spend for the period, a vs-last-month delta badge and a
/// category legend, matching the redesigned Home screen (web + mobile).
class SpendingsDonutCard extends StatelessWidget {
  const SpendingsDonutCard({
    super.key,
    this.periodLabel = 'This Month',
    this.currencyCode = 'GBP',
  });

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
  static const _totalSpend = 3182.0;
  static const _percentVsLastMonth = 12;

  @override
  Widget build(BuildContext context) {
    final total = MoneyFormat.format(_totalSpend, currencyCode: currencyCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
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
                decoration: BoxDecoration(
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
            ],
          ),
          const SizedBox(height: 18),
          Row(
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
  _DonutPainter({required this.values, required this.colors, required this.progress});

  final List<double> values;
  final List<Color> colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final stroke = size.width * 0.16;
    final radius = (size.width - stroke) / 2;
    const gapRadians = 0.045;

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

  // bottom depth
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
  });

  final List<_SpendCategory> categories;
  final String total;

  @override
  State<_Animated3DDonut> createState() => _Animated3DDonutState();
}

class _Animated3DDonutState extends State<_Animated3DDonut>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
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
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(-0.18)
            ..rotateY(
              0.15 * (1 - _controller.value),
            ),
          child: SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(230, 230),
                  painter: _DonutPainter(
                    values: widget.categories
                        .map((e) => e.amount)
                        .toList(),
                    colors: widget.categories
                        .map((e) => e.color)
                        .toList(),
                    progress: _controller.value,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Spendings',
                      style: TextStyle(
                        fontSize: 11,
                        color: HomeColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.total,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
