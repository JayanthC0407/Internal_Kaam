/// Small, null-tolerant readers for trade-finance payloads.
///
/// digx trade-finance DTOs mix types freely (`"false"` vs `false`,
/// `"30"` vs `30`, `""` for "not set"), so every model in this folder reads
/// through these instead of casting.
class TfJson {
  TfJson._();

  /// A JSON object as a map; anything else (null, a scalar, or a string —
  /// which `ObdxApiUtils.asMap` would try to `jsonDecode` and throw on)
  /// reads as empty.
  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> maps(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  /// Trimmed string, or `null` for null / empty / the literal `"null"`.
  static String? str(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static double? dbl(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', ''));
    return null;
  }

  static int? integer(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool boolean(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == 'y' || lower == 'yes') return true;
      if (lower == 'false' || lower == 'n' || lower == 'no') return false;
    }
    return fallback;
  }

  /// digx dates are `2023-06-20T00:00:00` (no zone). Parsed as local
  /// calendar dates — the time part is always midnight.
  static DateTime? date(dynamic value) {
    final text = str(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }

  /// Unwraps the `{ statusCode, body }` envelope when present.
  static Map<String, dynamic> root(dynamic data) {
    final map = TfJson.map(data);
    final body = map['body'];
    if (body is Map && !map.containsKey('status')) {
      return Map<String, dynamic>.from(body);
    }
    return map;
  }
}

/// Date formatting for trade-finance screens and request bodies.
class TfDate {
  TfDate._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `20 Jun 2023`, or [placeholder] when null.
  static String display(DateTime? value, {String placeholder = '—'}) {
    if (value == null) return placeholder;
    final day = value.day.toString().padLeft(2, '0');
    return '$day ${_months[value.month - 1]} ${value.year}';
  }

  /// `2023-06-20T00:00:00` — the exact shape every captured request uses.
  static String? toApi(DateTime? value) {
    if (value == null) return null;
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-${d}T00:00:00';
  }
}

/// digx `{ displayValue, value }` identifier.
class TfId {
  const TfId({this.value, this.displayValue});

  final String? value;
  final String? displayValue;

  bool get isEmpty => value == null || value!.isEmpty;

  factory TfId.fromJson(dynamic json) {
    final map = TfJson.map(json);
    return TfId(
      value: TfJson.str(map['value']),
      displayValue: TfJson.str(map['displayValue']),
    );
  }

  Map<String, dynamic> toJson() => {
        'displayValue': displayValue,
        'value': value,
      };

  static const empty = TfId();
}

/// Postal address in the digx trade-finance shape.
///
/// [toJson] always emits the full 12-line skeleton the web client sends
/// (H1 #121) — the host tolerates the nulls and some validators expect the
/// keys to be present.
class LcAddress {
  const LcAddress({
    this.line1,
    this.line2,
    this.line3,
    this.city,
    this.country,
    this.zipCode,
  });

  final String? line1;
  final String? line2;
  final String? line3;
  final String? city;
  final String? country;
  final String? zipCode;

  static const empty = LcAddress();

  bool get isEmpty => lines.isEmpty && country == null;

  List<String> get lines => [
        for (final line in [line1, line2, line3, city, zipCode])
          if (line != null && line.isNotEmpty) line,
      ];

  /// One-line rendering for review screens.
  String get singleLine {
    final parts = [...lines, if (country != null) country!];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  factory LcAddress.fromJson(dynamic json) {
    final map = TfJson.map(json);
    return LcAddress(
      line1: TfJson.str(map['line1']),
      line2: TfJson.str(map['line2']),
      line3: TfJson.str(map['line3']),
      city: TfJson.str(map['city']),
      country: TfJson.str(map['country']),
      zipCode: TfJson.str(map['zipCode']),
    );
  }

  LcAddress copyWith({
    String? line1,
    String? line2,
    String? line3,
    String? country,
  }) {
    return LcAddress(
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      line3: line3 ?? this.line3,
      city: city,
      country: country ?? this.country,
      zipCode: zipCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'line1': line1,
        'line2': line2,
        'line3': line3,
        'line4': null,
        'line5': null,
        'line6': null,
        'line7': null,
        'line8': null,
        'line9': null,
        'line10': null,
        'line11': null,
        'line12': null,
        'city': city,
        'addressTypeDescription': null,
        'state': null,
        'country': country,
        'zipCode': zipCode,
      };
}

/// Generic `{ code, description }` master entry — used for enumerations,
/// goods, incoterms, additional conditions and countries alike.
class TradeCode {
  const TradeCode({required this.code, this.description});

  final String code;
  final String? description;

  /// Description when present, else the raw code.
  String get label =>
      (description == null || description!.isEmpty) ? code : description!;

  @override
  bool operator ==(Object other) => other is TradeCode && other.code == code;

  @override
  int get hashCode => code.hashCode;

  static TradeCode? fromJson(dynamic json) {
    final map = TfJson.map(json);
    final code = TfJson.str(map['code'] ?? map['id']);
    if (code == null) return null;
    return TradeCode(
      code: code,
      description: TfJson.str(map['description'] ?? map['name']),
    );
  }

  static List<TradeCode> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (TradeCode.fromJson(item) case final code?) code,
    ];
  }

  /// `enumRepresentations[0].data[]` — H1 #42/#115/#117/#142.
  static List<TradeCode> fromEnumeration(dynamic data) {
    final root = TfJson.root(data);
    final reps = root['enumRepresentations'];
    if (reps is! List || reps.isEmpty) return const [];
    return listFrom(TfJson.map(reps.first)['data']);
  }

  Map<String, dynamic> toJson() => {'code': code, 'description': description};
}

/// A SWIFT/BIC entry from `tradeBicCodes` (H1 #143).
class TradeBank {
  const TradeBank({
    required this.code,
    this.name,
    this.address = LcAddress.empty,
    this.customerNo,
  });

  final String code;
  final String? name;
  final LcAddress address;
  final String? customerNo;

  static List<TradeBank> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    return [
      for (final map in TfJson.maps(root['listResponse']))
        if (TfJson.str(map['code']) case final code?)
          TradeBank(
            code: code,
            name: TfJson.str(map['branchName']),
            address: LcAddress.fromJson(map['branchAddress']),
            customerNo: TfJson.str(map['customerNo']),
          ),
    ];
  }

  /// `advisingBankDetails`-style block the web sends alongside a bank code.
  Map<String, dynamic> toDetailsJson() => {
        'customerNo': customerNo,
        'branchAddress': address.toJson(),
        'name': name,
      };
}
