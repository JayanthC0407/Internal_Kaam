/// Normalizes mixed bank narratives (e.g. `PRINCIPAL Liquidation`) to
/// consistent Title Case for transaction titles and subtitles.
class DisplayCase {
  DisplayCase._();

  static const _smallWords = {
    'a',
    'an',
    'the',
    'and',
    'or',
    'but',
    'for',
    'nor',
    'on',
    'at',
    'to',
    'from',
    'by',
    'of',
    'in',
    'vs',
  };

  static const _acronyms = {
    'ATM',
    'NEFT',
    'RTGS',
    'IMPS',
    'UPI',
    'ACH',
    'POS',
    'SWIFT',
    'IBAN',
    'OTP',
    'FT',
    'TT',
    'FX',
    'DD',
    'SI',
    'ECS',
    'NACH',
    'GST',
    'VAT',
    'SMS',
    'QR',
    'ID',
  };

  static String title(String input) {
    final trimmed = input
        .trim()
        .replaceAll(RegExp(r'[\u00A0\u2000-\u200B\u202F\u205F\u3000]+'), ' ')
        .replaceAll(RegExp(r'[ \t\n\r\f]+'), ' ');
    if (trimmed.isEmpty) return trimmed;

    final words = trimmed.split(' ');
    final last = words.length - 1;
    final buffer = <String>[];
    for (var i = 0; i < words.length; i++) {
      buffer.add(_titleWord(words[i], isEdge: i == 0 || i == last));
    }
    return buffer.join(' ');
  }

  static String _titleWord(String word, {required bool isEdge}) {
    if (word.isEmpty) return word;
    return word.replaceAllMapped(RegExp(r'[A-Za-z0-9]+'), (match) {
      final token = match[0]!;
      final upper = token.toUpperCase();
      if (_acronyms.contains(upper)) return upper;
      final lower = token.toLowerCase();
      if (!isEdge && _smallWords.contains(lower)) return lower;
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    });
  }
}
