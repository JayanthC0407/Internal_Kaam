import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';

/// 3×3 Android-style pattern lock. Emits selected dot indices (0–8).
class AuthPatternLock extends StatefulWidget {
  const AuthPatternLock({
    super.key,
    required this.onCompleted,
    this.minLength = 4,
    this.size,
  });

  final ValueChanged<List<int>> onCompleted;
  final int minLength;

  /// When null, size is derived from the current viewport.
  final double? size;

  @override
  State<AuthPatternLock> createState() => AuthPatternLockState();
}

class AuthPatternLockState extends State<AuthPatternLock> {
  final List<int> _selected = [];
  Offset? _finger;
  bool _tooShort = false;

  void reset() {
    setState(() {
      _selected.clear();
      _finger = null;
      _tooShort = false;
    });
  }

  List<Offset> _dotCenters(Size size) {
    final cell = size.width / 3;
    final centers = <Offset>[];
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        centers.add(Offset(col * cell + cell / 2, row * cell + cell / 2));
      }
    }
    return centers;
  }

  int? _hitTest(Offset local, List<Offset> centers, double side) {
    final hitRadius = math.max(28.0, side / 7.5);
    for (var i = 0; i < centers.length; i++) {
      if ((centers[i] - local).distance <= hitRadius) return i;
    }
    return null;
  }

  void _select(int index) {
    if (_selected.contains(index)) return;
    if (_selected.isNotEmpty) {
      final last = _selected.last;
      final mid = _middleDot(last, index);
      if (mid != null && !_selected.contains(mid)) {
        _selected.add(mid);
      }
    }
    _selected.add(index);
  }

  int? _middleDot(int a, int b) {
    final ar = a ~/ 3;
    final ac = a % 3;
    final br = b ~/ 3;
    final bc = b % 3;
    if ((ar - br).abs() == 2 && (ac - bc).abs() == 2) {
      return 4;
    }
    if (ar == br && (ac - bc).abs() == 2) {
      return ar * 3 + 1;
    }
    if (ac == bc && (ar - br).abs() == 2) {
      return 3 + ac;
    }
    return null;
  }

  void _finish() {
    if (_selected.length < widget.minLength) {
      setState(() {
        _tooShort = true;
        _finger = null;
      });
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted) reset();
      });
      return;
    }
    final pattern = List<int>.from(_selected);
    setState(() => _finger = null);
    widget.onCompleted(pattern);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final side = widget.size ?? responsive.patternLockSize();

    return SizedBox(
      width: side,
      height: side,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final centers = _dotCenters(size);
          final dotRadius = math.max(10.0, side / 20);
          return GestureDetector(
            onPanStart: (details) {
              setState(() {
                _tooShort = false;
                _selected.clear();
                _finger = details.localPosition;
                final hit = _hitTest(details.localPosition, centers, side);
                if (hit != null) _select(hit);
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _finger = details.localPosition;
                final hit = _hitTest(details.localPosition, centers, side);
                if (hit != null) _select(hit);
              });
            },
            onPanEnd: (_) => _finish(),
            child: CustomPaint(
              size: size,
              painter: _PatternPainter(
                context: context,
                centers: centers,
                selected: _selected,
                finger: _finger,
                error: _tooShort,
                dotRadius: dotRadius,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.context,
    required this.centers,
    required this.selected,
    required this.finger,
    required this.error,
    required this.dotRadius,
  });

  final BuildContext context;
  final List<Offset> centers;
  final List<int> selected;
  final Offset? finger;
  final bool error;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor =
        error ? AuthColors.error(context) : AuthColors.brand(context);
    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (selected.length >= 2) {
      final path = Path()
        ..moveTo(centers[selected.first].dx, centers[selected.first].dy);
      for (var i = 1; i < selected.length; i++) {
        path.lineTo(centers[selected[i]].dx, centers[selected[i]].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    if (selected.isNotEmpty && finger != null) {
      canvas.drawLine(centers[selected.last], finger!, linePaint);
    }

    for (var i = 0; i < centers.length; i++) {
      final selectedDot = selected.contains(i);
      final fill = Paint()
        ..color = selectedDot
            ? (error ? AuthColors.error(context) : AuthColors.brand(context))
            : AuthColors.surfaceLevel0(context);
      final border = Paint()
        ..color = selectedDot
            ? (error ? AuthColors.error(context) : AuthColors.brand(context))
            : AuthColors.inputBorder(context)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(centers[i], dotRadius, fill);
      canvas.drawCircle(centers[i], dotRadius, border);
      if (selectedDot) {
        canvas.drawCircle(
          centers[i],
          dotRadius * 0.43,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.finger != finger ||
        oldDelegate.error != error ||
        oldDelegate.dotRadius != dotRadius;
  }
}
