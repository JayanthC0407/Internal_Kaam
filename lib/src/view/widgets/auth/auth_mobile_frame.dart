import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';

/// Phone layout of every sign-in screen (designer mock): brand gradient
/// with a faint logomark, the white Demobank logo, a large white title and
/// subtitle, and a white card whose top edge dips in a gentle wave.
///
/// Used by the Login screen and by [AuthFormShell] (OTP, login steps,
/// alternate login, forgot credentials, registration) on phones.
class AuthMobileFrame extends StatelessWidget {
  const AuthMobileFrame({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// Top-right control — the "?" help badge or a back button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppGradients.primary(context)),
      child: Stack(
        children: [
          // The mock's fading leaf pattern, behind everything (full bleed).
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: AuthLeafPatternPainter()),
            ),
          ),
          SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: 10,
              width: 220,
              height: 220,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.08,
                  child: SvgPicture.asset(
                    'assets/images/figma/brand_logomark.svg',
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const AuthWhiteLogo(),
                                const Spacer(),
                                if (trailing != null) trailing!,
                              ],
                            ),
                            const SizedBox(height: 28),
                            if (title != null)
                              Text(
                                title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  color: Color(0xEBFFFFFF),
                                  fontSize: 15,
                                  height: 1.45,
                                ),
                              ),
                            ],
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        // Soft shadow behind the clipped wave card (a
                        // rounded box starting below the wave's dip).
                        child: Stack(
                          children: [
                            Positioned.fill(
                              top: 16,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.16),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ClipPath(
                              clipper: const AuthWaveCardClipper(),
                              child: ColoredBox(
                                color: colors.cardBg,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    44,
                                    22,
                                    26,
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 24 + MediaQuery.paddingOf(context).bottom,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }
}

/// Background pattern from the sign-in mocks: leaf shapes tiled along
/// each cell's diagonals, so four leaves meet at every cell centre and
/// corner (the overlapping-circle look). A touch darker than the gradient,
/// and transparent in places: each leaf has its own strength, soft patches
/// across the screen fade out, it is clear behind the title and strongest
/// towards the bottom. Pure paint — no image asset.
class AuthLeafPatternPainter extends CustomPainter {
  const AuthLeafPatternPainter({this.cell = 64, this.strength = 1});

  /// Width / height of one pattern cell.
  final double cell;

  /// 1 = the mock's intensity; lower for a subtler background.
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final half = cell / 2;
    final random = math.Random(11); // same look on every frame
    final paint = Paint()..style = PaintingStyle.fill;

    for (var y = -half; y < size.height + cell; y += cell) {
      // Clear behind the title, clearer towards the bottom.
      final t = (y / size.height).clamp(0.0, 1.0);
      final vertical = t < 0.14 ? 0.0 : (0.35 + 0.65 * ((t - 0.14) / 0.86));
      for (var x = -half; x < size.width + cell; x += cell) {
        final c = Offset(x, y);
        for (final d in const [
          Offset(1, 1),
          Offset(-1, 1),
          Offset(1, -1),
          Offset(-1, -1),
        ]) {
          final tip = c + d * half;
          final mid = (c + tip) / 2;
          // Soft patches where whole areas fade out.
          final patch = 0.5 +
              0.5 *
                  math.sin(mid.dx / size.width * 5.3 + mid.dy / 180) *
                  math.cos(mid.dy / size.height * 4.1 - mid.dx / 260);
          // Each leaf its own strength — some almost invisible.
          final own = 0.25 + random.nextDouble() * 0.75;
          final alpha = 0.14 * vertical * patch * own * strength;
          if (alpha < 0.004) continue;
          paint.color = const Color(0xFF00384A).withValues(alpha: alpha);
          canvas.drawPath(_leaf(c, tip), paint);
        }
      }
    }
  }

  /// A leaf from [a] to [b], bulging evenly on both sides.
  Path _leaf(Offset a, Offset b) {
    final mid = (a + b) / 2;
    final dir = b - a;
    final normal = Offset(-dir.dy, dir.dx) * 0.42;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx + normal.dx, mid.dy + normal.dy, b.dx, b.dy)
      ..quadraticBezierTo(mid.dx - normal.dx, mid.dy - normal.dy, a.dx, a.dy)
      ..close();
  }

  @override
  bool shouldRepaint(AuthLeafPatternPainter oldDelegate) =>
      oldDelegate.cell != cell || oldDelegate.strength != strength;
}

/// The Demobank logo in white, for the brand gradient.
class AuthWhiteLogo extends StatelessWidget {
  const AuthWhiteLogo({super.key, this.height = 34});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: Image.asset(
        'assets/images/demobank_logo.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text(
          'Demobank',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Round outlined icon button for the gradient header ("?" help, back).
class AuthHeaderIconButton extends StatelessWidget {
  const AuthHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

/// Card outline from the mock: rounded corners, the top edge dipping
/// gently towards the middle.
class AuthWaveCardClipper extends CustomClipper<Path> {
  const AuthWaveCardClipper();

  @override
  Path getClip(Size size) {
    const r = 22.0;
    const dip = 16.0;
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..cubicTo(w * 0.35, dip, w * 0.65, dip, w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
