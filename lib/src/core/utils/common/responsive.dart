import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared layout breakpoints and helpers for phone / tablet / desktop.
class Breakpoints {
  Breakpoints._();

  static const double phone = 600;

  /// iPad portrait / medium tablets — triggers wide auth & home shells.
  static const double wide = 768;
  static const double tablet = 900;
  static const double desktop = 1200;
}

class Responsive {
  const Responsive._(this.size, this.orientation);

  final Size size;
  final Orientation orientation;

  factory Responsive.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Responsive._(mq.size, mq.orientation);
  }

  double get width => size.width;
  double get height => size.height;

  bool get isPhone => width < Breakpoints.phone;
  bool get isTablet =>
      width >= Breakpoints.phone && width < Breakpoints.desktop;
  bool get isDesktop => width >= Breakpoints.desktop;
  bool get isLandscape => orientation == Orientation.landscape;

  /// Split / multi-column shell (tablet portrait+, desktop, large web).
  bool get useWideLayout => width >= Breakpoints.wide;

  /// Home dashboard uses the wide multi-column layout.
  bool get useWideHome => width >= Breakpoints.wide;

  bool get isCompactHeight => height < 700 || (isLandscape && height < 560);

  double get pageMaxWidth {
    if (isDesktop) return 1280;
    if (useWideLayout) return 980;
    return 560;
  }

  double get formMaxWidth {
    if (isDesktop) return 560;
    if (useWideLayout) return 480;
    return 480;
  }

  /// Horizontal inset for auth / form pages.
  double get formHorizontalPadding =>
      isPhone ? 16.0 : (useWideLayout ? 24.0 : 20.0);

  EdgeInsets pagePadding({
    double phone = 16,
    double tablet = 20,
    double desktop = 24,
  }) {
    final horizontal = isDesktop ? desktop : (useWideLayout ? tablet : phone);
    return EdgeInsets.symmetric(horizontal: horizontal);
  }

  double fontScale({
    required double phone,
    double? tablet,
    double? desktop,
  }) {
    if (isDesktop) return desktop ?? tablet ?? phone;
    if (useWideLayout) return tablet ?? phone;
    return phone;
  }

  /// PIN key diameter that fits [availableWidth] (3 keys + gaps).
  static double pinKeySize(double availableWidth,
      {double max = 72, double min = 48}) {
    final raw = (availableWidth - 48) / 3;
    return raw.clamp(min, max);
  }

  /// Pattern lock side length for the current viewport.
  double patternLockSize({double max = 280, double min = 200}) {
    final byWidth = width - (formHorizontalPadding * 2);
    final byHeight = isCompactHeight ? math.min(max, height * 0.38) : max;
    return math.min(byWidth, byHeight).clamp(min, max);
  }
}

/// Centers [child] and caps width for readable layouts on large screens.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? responsive.pageMaxWidth,
        ),
        child:
            padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// Form-width capped body that scrolls when the viewport is short.
///
/// Use for PIN / pattern / biometric stacks that previously relied on
/// [Spacer] inside a fixed [Column] (overflow risk on landscape / small phones).
class AuthResponsiveScrollBody extends StatelessWidget {
  const AuthResponsiveScrollBody({
    super.key,
    required this.builder,
    this.maxWidth,
    this.padding,
  });

  /// Builds the column children. When [compact] is true, avoid [Spacer]
  /// and use fixed gaps instead.
  final List<Widget> Function(
    BuildContext context,
    Responsive responsive,
    bool compact,
  ) builder;

  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final compact = responsive.isCompactHeight;
    final hPad = responsive.formHorizontalPadding;
    final resolvedPadding = padding ??
        EdgeInsets.fromLTRB(hPad, compact ? 8 : 16, hPad, compact ? 16 : 24);
    final padVertical = resolvedPadding is EdgeInsets
        ? resolvedPadding.vertical
        : (compact ? 24.0 : 40.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final children = builder(context, responsive, compact);
        final maxW = maxWidth ?? responsive.formMaxWidth;
        final bodyHeight = math.max(0.0, constraints.maxHeight - padVertical);

        final column = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );

        // Compact: scroll. Tall: fixed height so Spacer works (no IntrinsicHeight —
        // that breaks with nested LayoutBuilders such as AuthPinPad).
        if (compact) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: resolvedPadding,
            child: column,
          );
        }

        return Padding(
          padding: resolvedPadding,
          child: SizedBox(height: bodyHeight, child: column),
        );
      },
    );
  }
}
