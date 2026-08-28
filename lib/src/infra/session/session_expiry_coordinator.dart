import 'dart:async';

/// Broadcasts OBDX invalid-token / session-expiry events from the Dio layer
/// to the UI without requiring a [BuildContext] in interceptors.
class SessionExpiryCoordinator {
  SessionExpiryCoordinator._();

  static final SessionExpiryCoordinator instance = SessionExpiryCoordinator._();

  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  /// True while a session-expiry redirect is already in flight (debounce).
  bool _handling = false;

  Stream<void> get events => _controller.stream;

  bool get isHandling => _handling;

  /// Notifies listeners once; subsequent calls are ignored until [reset].
  void notifyExpired() {
    if (_handling) return;
    _handling = true;
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  /// Call after navigation to login / biometric unlock completes.
  void reset() {
    _handling = false;
  }
}
