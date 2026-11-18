import 'package:flutter/material.dart';

import '../render/render_context.dart';
import '../render/renderer.dart';
import '../render/widgets/app_widgets.dart';
import '../theme/dxp_theme.dart';
import 'preview_bridge.dart';

/// The DXP Studio's live preview: this app's own renderer and widgets,
/// driven by documents the Studio posts in
/// (`{type: dxp.preview, screen, data, theme, selected, design}`).
///
/// It is the same drawing code the Demo Bank app uses, so what a designer
/// sees is what the customer gets. Design mode tags every node with its path
/// so a tap selects it in the Studio; actions are reported to the Studio
/// instead of being run. Data is the Studio's sample data, never OBDX.
class DxpPreviewApp extends StatefulWidget {
  const DxpPreviewApp({
    super.key,
    this.appWidgets = const {},
    this.appTheme,
    this.localizationsDelegates,
    this.supportedLocales = const [Locale('en')],
  });

  /// The host app's own widgets (`AppWidget`), drawn with sample data.
  final Map<String, Widget Function()> appWidgets;

  /// The host app's theme, so its own widgets look as they do in the app.
  /// Studio blocks still use the manifest theme (DxpThemeScope).
  final ThemeData? appTheme;
  final List<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final List<Locale> supportedLocales;

  @override
  State<DxpPreviewApp> createState() => _DxpPreviewAppState();
}

class _DxpPreviewAppState extends State<DxpPreviewApp> {
  Map<String, dynamic>? _screen;
  Map<String, dynamic> _data = {};
  DxpTheme _theme = DxpTheme.fallback();
  String? _selected;
  bool _design = true;
  final Map<String, dynamic> _state = {};
  int? _lastPointer;

  static const _selection = Color(0xFF1A73E8);

  @override
  void initState() {
    super.initState();
    listenToHost(_onMessage);
    postToHost({'type': 'dxp.preview.ready'});
  }

  void _onMessage(Map<String, dynamic> m) {
    setState(() {
      final screen = m['screen'];
      if (screen is Map) _screen = Map<String, dynamic>.from(screen);
      final data = m['data'];
      if (data is Map) _data = Map<String, dynamic>.from(data);
      final theme = m['theme'];
      if (theme is Map) _theme = DxpTheme.fromJson(Map<String, dynamic>.from(theme));
      _selected = m['selected'] is String ? m['selected'] as String : null;
      _design = m['design'] != false;
    });
  }

  /// Deep-copies [node] and stamps `__path` (`root`, `root.0`, …) on every node.
  static dynamic _tag(dynamic node, String path) {
    if (node is! Map) return node;
    final copy = Map<String, dynamic>.from(node);
    copy['__path'] = path;
    final children = copy['children'];
    if (children is List) {
      copy['children'] = [
        for (var i = 0; i < children.length; i++) _tag(children[i], '$path.$i'),
      ];
    }
    return copy;
  }

  /// Tap-to-select: the deepest node under the pointer wins, and the
  /// selected node gets an outline.
  Widget _wrap(Widget node, Map json) {
    final path = json['__path'];
    if (path is! String) return node;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (_lastPointer == e.pointer) return;
        _lastPointer = e.pointer;
        setState(() => _selected = path);
        postToHost({'type': 'dxp.preview.select', 'path': path});
      },
      child: _selected == path
          ? DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(color: _selection, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: node,
            )
          : node,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: widget.appTheme ?? _theme.toThemeData(),
      localizationsDelegates: widget.localizationsDelegates,
      supportedLocales: widget.supportedLocales,
      builder: (context, child) => DxpAppWidgets(
        builders: widget.appWidgets,
        child: DxpThemeScope(theme: _theme, child: child ?? const SizedBox.shrink()),
      ),
      home: Builder(builder: _buildScreen),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final screen = _screen;
    if (screen == null) {
      return const Scaffold(body: Center(child: Text('Waiting for the Studio…')));
    }
    final customer = _data['customer'];
    final ctx = RenderContext.build(
      customer: customer is Map ? Map<String, dynamic>.from(customer) : {},
      data: _data,
      state: _state,
      theme: _theme.raw,
    );
    final renderer = Renderer(
      onAction: (action, _) => postToHost({'type': 'dxp.preview.action', 'action': action}),
      onStateChanged: () => setState(() {}),
      onError: (code, message, payload) =>
          postToHost({'type': 'dxp.preview.error', 'code': code, 'message': message}),
      wrapNode: _design ? _wrap : null,
    );
    final root = _design ? _tag(screen['root'], 'root') : screen['root'];
    return Scaffold(
      backgroundColor: _theme.background,
      appBar: AppBar(title: Text((screen['title'] ?? '').toString())),
      body: SafeArea(child: renderer.buildRoot(root, ctx)),
    );
  }
}
