import 'dart:async';

/// Android Back for screens embedded in a dashboard that keep their own
/// [PopScope] (Preferences, Service Requests, the Personalize panel).
///
/// Flutter calls every pop handler on the route for one Back press, so a
/// screen that steps back itself must stop the dashboard from also going
/// back: it calls [claim] when it handles the press, and the dashboard,
/// which reads [wasClaimed] after the handlers have run, does nothing.
abstract final class EmbeddedBack {
  static bool _claimed = false;

  /// This Back press is handled. Cleared on the next event, after the
  /// dashboard has looked, so a stale claim never swallows a later press.
  static void claim() {
    _claimed = true;
    Timer.run(() => _claimed = false);
  }

  /// Whether a screen handled the current Back press. Read it from a
  /// microtask scheduled in the pop handler, after every handler has run.
  static bool get wasClaimed => _claimed;
}
