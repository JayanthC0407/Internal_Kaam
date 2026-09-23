/// A statement download format, as returned by
/// `GET /digx-common/dda/v1/enumerations/mediatype`.
///
/// Confirmed response shape (captured via HAR):
/// ```json
/// {
///   "enumRepresentations": [
///     { "data": [
///       {"code":"csv","value":"csv","description":"text/csv","ordinal":1},
///       {"code":"pdf","value":"pdf","description":"application/pdf","ordinal":2},
///       {"code":"qif","value":"qif","description":"application/qif","ordinal":3},
///       {"code":"ofx","value":"ofx","description":"application/x-ofx","ordinal":4}
///     ]}
///   ]
/// }
/// ```
/// `code` is the value the statement-download endpoint expects as
/// `mediaFormat`; `description` is the MIME type it expects as `media`
/// (confirmed against the PDF download request in the same capture:
/// `media=application/pdf&mediaFormat=pdf`).
class StatementFormat {
  const StatementFormat({
    required this.code,
    required this.mimeType,
    this.ordinal,
  });

  /// e.g. `csv`, `pdf`, `qif`, `ofx` — sent as the `mediaFormat` query
  /// parameter, and used as the saved file's extension.
  final String code;

  /// e.g. `text/csv`, `application/pdf` — sent as the `media` query
  /// parameter.
  final String mimeType;

  final int? ordinal;

  String get fileExtension => code.toLowerCase();

  /// Upper-cased short label for display, e.g. "PDF", "CSV".
  String get label => code.toUpperCase();

  static List<StatementFormat> listFromPayload(dynamic data) {
    final root = _asMap(data);
    if (root == null) return const [];

    final reps = root['enumRepresentations'];
    if (reps is! List || reps.isEmpty) return const [];

    final formats = <StatementFormat>[];
    for (final rep in reps) {
      if (rep is! Map) continue;
      final items = rep['data'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final code = (map['code'] ?? map['value'] ?? '').toString().trim();
        final mimeType = (map['description'] ?? '').toString().trim();
        if (code.isEmpty || mimeType.isEmpty) continue;
        final ordinalValue = map['ordinal'];
        formats.add(
          StatementFormat(
            code: code,
            mimeType: mimeType,
            ordinal: ordinalValue is num ? ordinalValue.toInt() : null,
          ),
        );
      }
    }

    formats.sort((a, b) => (a.ordinal ?? 0).compareTo(b.ordinal ?? 0));
    return formats;
  }

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('enumRepresentations')) return map;
    final nested = map['body'];
    if (nested is Map) return _asMap(nested);
    return map;
  }
}
