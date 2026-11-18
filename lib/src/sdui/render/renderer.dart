import 'package:flutter/material.dart';

import 'node.dart';
import 'render_context.dart';
import 'widgets/widget_registry.dart';

/// Recursive JSON node → widget renderer (CONTRACT §3).
///
/// One bad node never breaks a screen: every node build is wrapped in
/// try/catch, and unknown types render a placeholder and report `ERROR`.
class Renderer implements NodeRenderer {
  Renderer({
    required this.onAction,
    required this.onStateChanged,
    required this.onError,
    Map<String, NodeBuilder>? registry,
    this.wrapNode,
  }) : registry = registry ?? widgetRegistry;

  final Map<String, NodeBuilder> registry;

  /// Optional decoration of every drawn node with its JSON. Only the Studio
  /// preview sets it (tap-to-select and the selection outline); the app
  /// draws nodes as they are.
  final Widget Function(Widget node, Map json)? wrapNode;
  final void Function(Map<String, dynamic> action, RenderContext ctx) onAction;
  final VoidCallback onStateChanged;

  /// (code, message, payload) → host posts an `ERROR` event.
  final void Function(String code, String message, Map<String, dynamic> payload) onError;

  final Set<String> _reported = <String>{};

  void _report(String key, String code, String message, Map<String, dynamic> payload) {
    if (_reported.add(key)) onError(code, message, payload);
  }

  @override
  void runAction(Map<String, dynamic> action, RenderContext ctx) => onAction(action, ctx);

  @override
  void stateChanged() => onStateChanged();

  /// Renders a screen root. Non-scrolling roots are still made scrollable so
  /// forms never overflow when the keyboard opens.
  Widget buildRoot(dynamic json, RenderContext ctx) {
    final w = build(json, ctx);
    var scrolls = false;
    if (json is Map) {
      final props = json['props'];
      scrolls = json['type'] == 'Column' && props is Map && props['scroll'] == true;
    }
    if (scrolls) return w;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: w,
    );
  }

  @override
  Widget build(dynamic json, RenderContext ctx) {
    if (json is! Map) {
      _report('invalid:${json.runtimeType}', 'INVALID_NODE', 'Node is not an object', <String, dynamic>{});
      return const SizedBox.shrink();
    }
    final type = (json['type'] ?? '').toString();
    Widget w;
    try {
      final builder = registry[type];
      if (builder == null) {
        _report('unsupported:$type', 'UNSUPPORTED_WIDGET', 'Unsupported widget type "$type"',
            <String, dynamic>{'widget': type});
        w = UnsupportedBox(label: 'Unsupported: ${type.isEmpty ? '?' : type}');
      } else {
        w = builder(_resolve(json, ctx), NodeScope(this, ctx));
      }
    } catch (e) {
      _report('render:$type:$e', 'RENDER_ERROR', 'Failed to render "$type": $e',
          <String, dynamic>{'widget': type});
      w = UnsupportedBox(label: 'Could not show $type');
    }
    final wrap = wrapNode;
    return wrap == null ? w : wrap(w, json);
  }

  NodeSpec _resolve(Map json, RenderContext ctx) {
    final rawProps = json['props'];
    final props = <String, dynamic>{};
    if (rawProps is Map) {
      rawProps.forEach((k, v) => props[k.toString()] = ctx.interpolateDeep(v));
    }
    final bind = json['bind'];
    if (bind is Map) {
      bind.forEach((prop, path) {
        props[prop.toString()] = ctx.resolve(path.toString());
      });
    }
    final on = json['on'];
    final children = json['children'];
    return NodeSpec(
      type: (json['type'] ?? '').toString(),
      props: props,
      on: on is Map ? Map<String, dynamic>.from(on) : <String, dynamic>{},
      children: children is List ? children : const <dynamic>[],
    );
  }
}

/// Small grey placeholder for unknown / failing nodes.
class UnsupportedBox extends StatelessWidget {
  const UnsupportedBox({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD0D0D0)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
      ),
    );
  }
}
