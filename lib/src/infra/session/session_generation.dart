/// Identifies the currently authenticated application session.
///
/// Every successful sign-out advances the generation. Long-running API
/// requests capture the generation they started under and must not publish
/// their response if the generation has changed in the meantime.
class SessionGeneration {
  SessionGeneration._();

  static int _current = 0;

  static int get current => _current;

  /// Starts a new logical session generation.
  ///
  /// This is deliberately in-memory only. It is not an authentication token
  /// and must never be persisted.
  static int advance() => ++_current;

  static bool isCurrent(int generation) => generation == _current;
}
