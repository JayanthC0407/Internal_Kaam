/// Idle session timeout configuration.
class SessionConfig {
  SessionConfig._();

  /// Minutes of inactivity before session expires. `0` disables idle timeout.
  static const int idleTimeoutMinutes = int.fromEnvironment(
    'SESSION_IDLE_TIMEOUT_MINUTES',
    defaultValue: 15,
  );

  static Duration get idleTimeout => Duration(minutes: idleTimeoutMinutes);

  static bool get isIdleTimeoutEnabled => idleTimeoutMinutes > 0;
}
