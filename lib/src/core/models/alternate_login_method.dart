/// On-device alternate login gate. Only one method is active at a time.
/// All methods use the same OBDX token login after local unlock.
enum AlternateLoginMethod {
  faceId,
  fingerprint,
  passcode,
  pattern;

  bool get isBiometric =>
      this == AlternateLoginMethod.faceId ||
      this == AlternateLoginMethod.fingerprint;

  bool get requiresLocalSecret =>
      this == AlternateLoginMethod.passcode ||
      this == AlternateLoginMethod.pattern;

  static AlternateLoginMethod? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in AlternateLoginMethod.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
