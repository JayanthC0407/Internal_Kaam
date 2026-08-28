import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_shell.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_styles.dart';

/// Shared success UI for registration + forgot-credentials (message-driven).
/// Fills the screen without scrolling — CTA stays visible.
class AuthFlowSuccessPanel extends StatefulWidget {
  const AuthFlowSuccessPanel({
    super.key,
    required this.title,
    required this.message,
    required this.loginLabel,
    required this.onLogin,
  });

  final String title;
  final String message;
  final String loginLabel;
  final VoidCallback onLogin;

  @override
  State<AuthFlowSuccessPanel> createState() => _AuthFlowSuccessPanelState();
}

class _AuthFlowSuccessPanelState extends State<AuthFlowSuccessPanel>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final AnimationController _contentController;

  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _circleScale;
  late final Animation<double> _checkProgress;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _ringScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _ringOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _circleScale = Tween<double>(begin: 0.2, end: 1).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: const Interval(0.18, 0.6, curve: Curves.elasticOut),
      ),
    );
    _checkProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: const Interval(0.48, 0.88, curve: Curves.easeOutCubic),
      ),
    );
    _contentOpacity = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    void maybeStartContent() {
      if (_heroController.value >= 0.45 &&
          _contentController.status == AnimationStatus.dismissed) {
        _contentController.forward();
      }
    }

    _heroController.addListener(maybeStartContent);
    _heroController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final responsive = Responsive.of(context);
    final compact = responsive.isCompactHeight;
    final horizontal = responsive.isPhone ? 16.0 : 24.0;

    return AuthSplitLayout(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: responsive.formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _heroController,
                          builder: (context, _) {
                            return _SuccessHero(
                              colors: colors,
                              compact: compact,
                              ringScale: _ringScale.value,
                              ringOpacity: _ringOpacity.value,
                              circleScale: _circleScale.value,
                              checkProgress: _checkProgress.value,
                            );
                          },
                        ),
                        SizedBox(height: compact ? 20 : 28),
                        FadeTransition(
                          opacity: _contentOpacity,
                          child: SlideTransition(
                            position: _contentSlide,
                            child: Column(
                              children: [
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: compact ? 24 : 28,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.message,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FadeTransition(
                    opacity: _contentOpacity,
                    child: ElevatedButton(
                      onPressed: widget.onLogin,
                      style: AuthFormStyles.primaryButton(colors),
                      child: Text(widget.loginLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessHero extends StatelessWidget {
  const _SuccessHero({
    required this.colors,
    required this.compact,
    required this.ringScale,
    required this.ringOpacity,
    required this.circleScale,
    required this.checkProgress,
  });

  final AppColors colors;
  final bool compact;
  final double ringScale;
  final double ringOpacity;
  final double circleScale;
  final double checkProgress;

  @override
  Widget build(BuildContext context) {
    final outer = compact ? 96.0 : 120.0;
    final middle = compact ? 78.0 : 96.0;
    final inner = compact ? 60.0 : 74.0;
    final checkSize = compact ? 28.0 : 34.0;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: ringOpacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: ringScale,
              child: Container(
                width: outer,
                height: outer,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.brand.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: ringOpacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: ringScale,
              child: Container(
                width: middle,
                height: middle,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.otpBoxFilled,
                  border: Border.all(
                    color: colors.brand.withValues(alpha: 0.18),
                  ),
                ),
              ),
            ),
          ),
          Transform.scale(
            scale: circleScale.clamp(0.0, 1.2),
            child: Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.brand,
                    colors.brandDark,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.brand.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: checkSize,
                  height: checkSize,
                  child: CustomPaint(
                    painter: _CheckmarkPainter(
                      progress: checkProgress.clamp(0.0, 1.0),
                      color: Colors.white,
                      strokeWidth: compact ? 3.2 : 3.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.82, size.height * 0.28);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final extracted = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(extracted, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
