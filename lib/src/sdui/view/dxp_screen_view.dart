import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dxp_actions.dart';
import '../dxp_providers.dart';
import '../dxp_runtime.dart';
import '../render/render_context.dart';
import '../render/renderer.dart';
import '../render/widgets/app_widgets.dart';
import '../theme/dxp_theme.dart';

/// Draws one published screen: loads its document, resolves its data
/// aliases through the host (OBDX, CONTRACT-OBDX §6), renders it, and
/// redraws when a new configuration is applied.
///
/// [embedded] draws it inside another scrolling page (the Home slot):
/// no scroll view of its own, and nothing at all while loading or on error,
/// so the native page never jumps or shows a broken box.
class DxpScreenView extends ConsumerStatefulWidget {
  const DxpScreenView({super.key, required this.screenId, this.embedded = false});

  final String screenId;
  final bool embedded;

  @override
  ConsumerState<DxpScreenView> createState() => _DxpScreenViewState();
}

class _DxpScreenViewState extends ConsumerState<DxpScreenView> {
  Map<String, dynamic>? _doc;
  Map<String, dynamic> _data = const {};
  final Map<String, dynamic> _state = {};
  bool _failed = false;
  int _loadedRevision = -1;
  int _loadSeq = 0;

  DxpRuntime get _runtime => ref.read(dxpRuntimeProvider);

  @override
  void didUpdateWidget(covariant DxpScreenView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenId != widget.screenId) _loadedRevision = -1;
  }

  Future<void> _load({bool dataOnly = false}) async {
    final runtime = _runtime;
    final seq = ++_loadSeq;
    _loadedRevision = runtime.revision;
    try {
      final doc = dataOnly && _doc != null
          ? _doc!
          : await runtime.screen(widget.screenId);
      final data = await _resolveData(runtime, doc);
      if (!mounted || seq != _loadSeq) return;
      final firstView = _doc == null || doc != _doc;
      setState(() {
        _doc = doc;
        _data = data;
        _failed = false;
      });
      if (firstView) runtime.track('SCREEN_VIEW', screen: widget.screenId);
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() => _failed = true);
      runtime.track('ERROR', screen: widget.screenId, payload: {
        'code': 'SCREEN_LOAD_FAILED',
        'message': '$e',
      });
    }
  }

  /// Every `data` alias of [doc], in parallel. A failed source renders
  /// empty instead of failing the screen (prototype §3).
  static Future<Map<String, dynamic>> _resolveData(
    DxpRuntime runtime,
    Map<String, dynamic> doc,
  ) async {
    final spec = doc['data'];
    final host = runtime.host;
    if (spec is! Map || spec.isEmpty || host == null) return const {};
    final out = <String, dynamic>{};
    await Future.wait(spec.entries.map((entry) async {
      final s = entry.value;
      final source = s is Map ? s['source']?.toString() : s?.toString();
      if (source == null || source.isEmpty) return;
      final value = await host.resolveData(source);
      if (value == null) {
        runtime.track('ERROR', screen: doc['id']?.toString(), payload: {
          'code': 'DATA_SOURCE_FAILED',
          'source': source,
        });
      }
      out[entry.key.toString()] = value;
    }));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(dxpRuntimeProvider);
    if (runtime.status != DxpStatus.ready) return const SizedBox.shrink();

    if (_loadedRevision != runtime.revision) {
      // Show the cached copy right away, then load data for it.
      _doc ??= runtime.cachedScreen(widget.screenId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadedRevision != runtime.revision) _load();
      });
    }

    final doc = _doc;
    if (doc == null) {
      if (widget.embedded || !_failed) {
        return widget.embedded
            ? const SizedBox.shrink()
            : const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
      }
      return _LoadError(onRetry: _load);
    }

    final ctx = RenderContext.build(
      customer: runtime.host?.customer ?? const {},
      data: _data,
      state: _state,
      theme: runtime.theme.raw,
    );
    final actions = DxpActions(runtime);
    final renderer = Renderer(
      onAction: (action, c) => actions.run(
        context,
        action,
        c,
        screen: widget.screenId,
        onRefresh: () => _load(dataOnly: true),
      ),
      onStateChanged: () => setState(() {}),
      onError: (code, message, payload) => runtime.track(
        'ERROR',
        screen: widget.screenId,
        payload: {'code': code, 'message': message, ...payload},
      ),
    );
    final root = doc['root'];
    return DxpAppWidgets(
      builders: runtime.host?.appWidgets ?? const {},
      child: DxpThemeScope(
        theme: runtime.theme,
        child: widget.embedded
            ? renderer.build(root, ctx)
            : renderer.buildRoot(root, ctx),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("This page couldn't be loaded."),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
