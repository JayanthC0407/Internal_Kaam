import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Side-by-side children that share the tallest child's height.
///
/// Uses a two-pass layout (not [IntrinsicHeight]), so descendants such as
/// [LayoutBuilder] keep working inside a scroll view.
class StretchRow extends MultiChildRenderObjectWidget {
  const StretchRow({
    super.key,
    required super.children,
    this.gap = 20,
    this.flexes,
  });

  final double gap;
  final List<int>? flexes;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderStretchRow(gap: gap, flexes: flexes);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderStretchRow renderObject,
  ) {
    renderObject
      ..gap = gap
      ..flexes = flexes;
  }
}

class _StretchParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderStretchRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _StretchParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _StretchParentData> {
  _RenderStretchRow({
    required double gap,
    List<int>? flexes,
  })  : _gap = gap,
        _flexes = flexes;

  double _gap;
  List<int>? _flexes;

  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  set flexes(List<int>? value) {
    if (_listEquals(_flexes, value)) return;
    _flexes = value;
    markNeedsLayout();
  }

  static bool _listEquals(List<int>? a, List<int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _StretchParentData) {
      child.parentData = _StretchParentData();
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    assert(
      constraints.hasBoundedWidth,
      'StretchRow requires a bounded width',
    );
    final n = childCount;
    if (n == 0) {
      size = constraints.constrain(Size.zero);
      return;
    }

    final flexes = _flexes ?? List<int>.filled(n, 1);
    assert(
      flexes.length == n,
      'StretchRow flexes length must match children',
    );
    final totalFlex = flexes.fold<int>(0, (sum, f) => sum + f);
    final innerWidth = math.max(0.0, constraints.maxWidth - _gap * (n - 1));

    var maxHeight = 0.0;
    var index = 0;
    var child = firstChild;
    while (child != null) {
      final width = innerWidth * flexes[index] / totalFlex;
      child.layout(
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
        ),
        parentUsesSize: true,
      );
      maxHeight = math.max(maxHeight, child.size.height);
      child = childAfter(child);
      index++;
    }

    final targetHeight = constraints.constrainHeight(maxHeight);
    index = 0;
    child = firstChild;
    var x = 0.0;
    while (child != null) {
      final width = innerWidth * flexes[index] / totalFlex;
      child.layout(
        BoxConstraints.tightFor(width: width, height: targetHeight),
        parentUsesSize: true,
      );
      (child.parentData! as _StretchParentData).offset = Offset(x, 0);
      x += width + _gap;
      child = childAfter(child);
      index++;
    }

    size = constraints.constrain(Size(constraints.maxWidth, targetHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
