import 'package:flutter/material.dart';

import 'dxp_runtime.dart';
import 'render/render_context.dart';
import 'view/dxp_screen_page.dart';

/// Runs the closed set of actions (CONTRACT-OBDX §7, prototype §7) that this
/// app version supports. Anything else shows a short notice and posts an
/// ERROR event; it never throws.
class DxpActions {
  const DxpActions(this.runtime);

  final DxpRuntime runtime;

  static const _notAvailable = 'Not available in this version';

  void run(
    BuildContext context,
    Map<String, dynamic> action,
    RenderContext ctx, {
    String? screen,
    VoidCallback? onRefresh,
  }) {
    final type = action['type']?.toString() ?? '';
    runtime.track('UI_ACTION', screen: screen, payload: {'action': type});
    switch (type) {
      case 'navigate':
        final id = action['screen']?.toString() ?? '';
        if (runtime.hasScreen(id)) {
          DxpScreenPage.open(context, id);
        } else {
          _unsupported(context, type, 'screen "$id" is not published', screen);
        }
      case 'nativeRoute':
        final route = action['route']?.toString() ?? '';
        final host = runtime.host;
        // Captured first: popping below can unmount [context].
        final messenger = ScaffoldMessenger.maybeOf(context);
        // Leave any DXP pages first, so the existing screen opens in its
        // normal place in the dashboard.
        Navigator.of(context).popUntil((r) => r.settings.name != DxpScreenPage.routeName);
        if (host == null || !host.openNative(route)) {
          runtime.track('ERROR', screen: screen, payload: {
            'code': 'UNKNOWN_ROUTE',
            'message': 'route "$route" is not in the route table',
          });
          messenger
            ?..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text(_notAvailable)));
        }
      case 'back':
        Navigator.of(context).maybePop();
      case 'refresh':
        onRefresh?.call();
      case 'toast':
        final message = ctx.interpolate(action['message']?.toString() ?? '');
        _toast(context, message);
      default:
        // openUrl, journeys and logout arrive with later pack versions.
        _unsupported(context, type, 'action not in this app version', screen);
    }
  }

  void _unsupported(BuildContext context, String type, String why, String? screen) {
    runtime.track('ERROR', screen: screen, payload: {
      'code': 'UNSUPPORTED_ACTION',
      'action': type,
      'message': why,
    });
    _toast(context, _notAvailable);
  }

  static void _toast(BuildContext context, String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
