import 'package:flutter/widgets.dart';

import 'render_context.dart';

/// Builds one widget for a resolved node.
typedef NodeBuilder = Widget Function(NodeSpec node, NodeScope scope);

/// What the widget builders need from the renderer.
abstract class NodeRenderer {
  Widget build(dynamic json, RenderContext ctx);
  void runAction(Map<String, dynamic> action, RenderContext ctx);
  void stateChanged();
}

/// A node after `props` interpolation and `bind` resolution.
class NodeSpec {
  NodeSpec({
    required this.type,
    required this.props,
    required this.on,
    required this.children,
  });

  final String type;
  final Map<String, dynamic> props;
  final Map<String, dynamic> on;
  final List<dynamic> children;

  bool has(String key) => props[key] != null;

  String str(String key, [String fallback = '']) {
    final v = props[key];
    if (v == null) return fallback;
    final s = stringify(v);
    return s.isEmpty ? fallback : s;
  }

  String? strOrNull(String key) {
    final v = props[key];
    if (v == null) return null;
    final s = stringify(v);
    return s.isEmpty ? null : s;
  }

  double dbl(String key, double fallback) {
    final n = toNum(props[key]);
    return n == null ? fallback : n.toDouble();
  }

  int integer(String key, int fallback) {
    final n = toNum(props[key]);
    return n == null ? fallback : n.toInt();
  }

  bool flag(String key, [bool fallback = false]) {
    final v = props[key];
    if (v is bool) return v;
    if (v is String) return v == 'true';
    return fallback;
  }

  List<dynamic> list(String key) {
    final v = props[key];
    return v is List ? v : const <dynamic>[];
  }

  Map<String, dynamic>? action(String event) {
    final a = on[event];
    return a is Map ? Map<String, dynamic>.from(a) : null;
  }
}

/// Passed to every [NodeBuilder]: the renderer plus the current context.
class NodeScope {
  NodeScope(this.renderer, this.ctx);

  final NodeRenderer renderer;
  final RenderContext ctx;

  List<Widget> children(NodeSpec n, [RenderContext? c]) =>
      n.children.map((child) => renderer.build(child, c ?? ctx)).toList();

  /// Tap handler for `on[event]`, or null when the node has none.
  VoidCallback? handler(NodeSpec n, String event, [RenderContext? c]) {
    final a = n.action(event);
    if (a == null) return null;
    final useCtx = c ?? ctx;
    return () => renderer.runAction(a, useCtx);
  }

  void run(dynamic action, [RenderContext? c]) {
    if (action is Map) {
      renderer.runAction(Map<String, dynamic>.from(action), c ?? ctx);
    }
  }

  void stateChanged() => renderer.stateChanged();
}
