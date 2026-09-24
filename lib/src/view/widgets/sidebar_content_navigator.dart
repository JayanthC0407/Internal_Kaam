import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/routes/routes.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';

/// The area to the right of a dashboard's persistent side menu, on web.
///
/// Runs its own [Navigator], so a screen opened from anywhere inside
/// [child] — or from a screen opened from there — slides in *here*, beside
/// the menu, instead of on the app's root navigator where it would cover
/// the menu. Callers need no changes: `Navigator.of(context)` already
/// resolves to the nearest navigator, which is this one.
///
/// Browser Back closes the innermost opened screen first
/// ([NavigatorPopHandler]); once only [child] is left, it behaves as before.
///
/// Anything that leaves the signed-in area — sign-in, sign-out, a fresh
/// dashboard, see [Routes.appLevelRoutes] — still belongs to the root
/// navigator. Those call sites pass `rootNavigator: true`; as a backstop, one
/// requested here is handed to the root navigator (clearing the stack, as
/// every such flow from inside a dashboard does) rather than opened next to
/// the menu.
///
/// Only place this where the menu is persistent (the desktop layout). Off
/// the web it returns [child] unchanged, so native apps keep opening
/// screens full-screen.
class SidebarContentNavigator extends StatefulWidget {
  const SidebarContentNavigator({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.enabled = kIsWeb,
  });

  /// Lets the dashboard close opened screens, e.g. when a menu item is
  /// chosen: `navigatorKey.currentState?.popUntil((r) => r.isFirst)`.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The dashboard content, shown when no screen is open on top of it.
  final Widget child;

  /// Defaults to web only. Exposed so widget tests, which never run as web,
  /// can exercise the nested behaviour.
  final bool enabled;

  /// Closes every screen opened in the content area of [navigatorKey],
  /// leaving the dashboard content. Safe to call when none are open, or
  /// when the nested navigator is not in use.
  static void closeOpenedScreens(GlobalKey<NavigatorState> navigatorKey) {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  State<SidebarContentNavigator> createState() =>
      _SidebarContentNavigatorState();
}

class _SidebarContentNavigatorState extends State<SidebarContentNavigator> {
  static const _rootPageKey = ValueKey('sidebar-content-root');

  Route<dynamic> _generateRoute(RouteSettings settings) {
    if (!Routes.appLevelRoutes.contains(settings.name)) {
      final route = Routes.onGenerateRoutes(settings);
      // A screen reached without the arguments it needs falls back to the
      // splash screen, which re-resolves the session — an app-level step.
      if (route != null && route.settings.name != RoutesConst.splashScreen) {
        return route;
      }
    }
    return _handOffToRoot(settings);
  }

  /// Opens [settings] on the root navigator instead, and returns an empty
  /// placeholder for this one — which the root push then removes along
  /// with the rest of the dashboard.
  Route<dynamic> _handOffToRoot(RouteSettings settings) {
    assert(() {
      debugPrint(
        'SidebarContentNavigator: "${settings.name}" is an app-level route; '
        'open it with Navigator.of(context, rootNavigator: true). Handing '
        'it to the root navigator.',
      );
      return true;
    }());
    final root = Navigator.of(context, rootNavigator: true);
    // Not synchronously: this navigator is in the middle of pushing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      root.pushNamedAndRemoveUntil(
        settings.name ?? RoutesConst.splashScreen,
        (_) => false,
        arguments: settings.arguments,
      );
    });
    return PageRouteBuilder<void>(
      settings: settings,
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => widget.navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: widget.navigatorKey,
        // One page, the dashboard content, with the same key every build —
        // so a dashboard rebuild updates it in place and leaves any screens
        // opened on top of it where they are.
        pages: [MaterialPage<void>(key: _rootPageKey, child: widget.child)],
        // The root page is never removed: NavigatorPopHandler only lets a
        // pop through while there is a screen above it.
        onDidRemovePage: (_) {},
        onGenerateRoute: _generateRoute,
      ),
    );
  }
}
