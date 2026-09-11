/// Initials for the profile avatar when no photo is available.
class ProfileInitials {
  ProfileInitials._();

  /// `Saham Biswa` / `SAHAM BISWA` → `SB`. Single token uses up to two letters.
  static String fromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return _letters(parts.first, 2);
    }
    final first = _letters(parts.first, 1);
    final last = _letters(parts.last, 1);
    return '$first$last';
  }

  static String _letters(String value, int count) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (buffer.length >= count) break;
      buffer.write(String.fromCharCode(rune).toUpperCase());
    }
    return buffer.toString();
  }
}
