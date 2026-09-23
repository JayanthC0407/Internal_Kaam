class PayeeAccountTypeOption {
  const PayeeAccountTypeOption({
    required this.code,
    required this.value,
    required this.description,
    this.ordinal,
  });

  final String code;
  final String value;
  final String description;
  final int? ordinal;

  factory PayeeAccountTypeOption.fromMap(Map<String, dynamic> map) {
    return PayeeAccountTypeOption(
      code: map['code']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      description: map['description']?.toString().trim() ?? '',
      ordinal: map['ordinal'] is num ? (map['ordinal'] as num).toInt() : null,
    );
  }
}

class DomesticNetworkOption {
  const DomesticNetworkOption({
    required this.code,
    required this.description,
    required this.taskCode,
    required this.hostNetworkCode,
    required this.enabled,
  });

  final String code;
  final String description;
  final String taskCode;
  final String hostNetworkCode;
  final bool enabled;

  factory DomesticNetworkOption.fromMap(Map<String, dynamic> map) {
    final hosts = map['networkHost'];
    final firstHost = hosts is List && hosts.isNotEmpty && hosts.first is Map
        ? Map<String, dynamic>.from(hosts.first as Map)
        : <String, dynamic>{};

    return DomesticNetworkOption(
      code: map['code']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      taskCode: map['taskCode']?.toString() ?? '',
      hostNetworkCode: firstHost['hostNetworkCode']?.toString() ?? '',
      enabled: firstHost['enabled']?.toString().toUpperCase() != 'N',
    );
  }
}

class CountryOption {
  const CountryOption({
    required this.code,
    required this.value,
    required this.description,
  });

  final String code;
  final String value;
  final String description;

  String get displayName => description.isNotEmpty ? description : value;

  factory CountryOption.fromMap(Map<String, dynamic> map) {
    return CountryOption(
      code: map['code']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      description: map['description']?.toString().trim() ?? '',
    );
  }
}

/// Case-insensitive first non-empty value across candidate keys. Used by the
/// newer location/party models below, whose exact JSON field names were not
/// included in the supplied capture (only endpoint purpose + example output
/// values were documented) — so parsing tries the common OBDX naming
/// variants instead of assuming one exact shape.
String? firstNonEmptyPayeeField(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }
  return null;
}

/// Generic `{code, value, description}` enumeration entry — the shape shared
/// by the OBDX `/enumerations/*` endpoints used by the payee module that
/// don't need their own dedicated model (international network type,
/// national clearing code type, address type).
class PayeeEnumOption {
  const PayeeEnumOption({
    required this.code,
    required this.value,
    required this.description,
  });

  final String code;
  final String value;
  final String description;

  String get displayName => description.isNotEmpty ? description : value;

  factory PayeeEnumOption.fromMap(Map<String, dynamic> map) {
    return PayeeEnumOption(
      code: map['code']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      description: map['description']?.toString().trim() ?? '',
    );
  }
}

/// A city/location entry from
/// `/digx-common/location/v1/locations/country/all/city`, used by the
/// Demand Draft Payee "Draft Payable At" / "City" pickers.
///
/// The captured document describes this endpoint's purpose and example
/// output values (TZ, California, test) but not its raw JSON shape, so
/// parsing is intentionally lenient: it accepts either a plain string list
/// or a list of objects using common OBDX field-naming conventions.
class CityOption {
  const CityOption({required this.code, required this.name});

  final String code;
  final String name;

  String get displayName => name.isNotEmpty ? name : code;

  factory CityOption.fromValue(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final code = firstNonEmptyPayeeField(
            map,
            const ['city', 'cityCode', 'code', 'value'],
          ) ??
          '';
      final name = firstNonEmptyPayeeField(
            map,
            const ['cityName', 'description', 'name', 'city'],
          ) ??
          code;
      return CityOption(code: code, name: name);
    }
    final text = value?.toString() ?? '';
    return CityOption(code: text, name: text);
  }
}

/// A bank/branch entry from
/// `/digx-common/location/v1/locations/country/all/city/{city}/branchCode`,
/// used to populate the "Branch Near Me" dropdown once a city is selected.
/// See [CityOption] for why parsing is lenient.
class BranchOption {
  const BranchOption({required this.code, required this.name});

  final String code;
  final String name;

  String get displayName => name.isNotEmpty ? name : code;

  factory BranchOption.fromValue(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      // Confirmed shape (branchAddressDTO entries): {"id": "NMB",
      // "branchName": "NMB BANK PLC", ...}. Older guesses kept as fallbacks.
      final code = firstNonEmptyPayeeField(
            map,
            const ['id', 'branchCode', 'code', 'value'],
          ) ??
          '';
      final name = firstNonEmptyPayeeField(
            map,
            const ['branchName', 'description', 'name'],
          ) ??
          code;
      return BranchOption(code: code, name: name);
    }
    final text = value?.toString() ?? '';
    return BranchOption(code: text, name: text);
  }
}

/// Resolved branch address from
/// `/digx-common/location/v1/locations/branches?branchCode=...`, rendered
/// as the read-only address preview under "Branch Near Me". See
/// [CityOption] for why parsing is lenient.
class BranchAddress {
  const BranchAddress({
    this.line1,
    this.line2,
    this.city,
    this.state,
    this.country,
  });

  final String? line1;
  final String? line2;
  final String? city;
  final String? state;
  final String? country;

  bool get isEmpty =>
      line1 == null &&
      line2 == null &&
      city == null &&
      state == null &&
      country == null;

  /// Non-empty address lines, in display order — mirrors the captured
  /// "OHIO STREET.../TANZANIA/TZ/GREAT BRITAIN" preview layout.
  List<String> get displayLines =>
      [line1, line2, city, state, country].whereType<String>().toList();

  factory BranchAddress.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> unwrap(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : const {};

    // Confirmed real shape from a captured `addressDTO[0]` entry:
    // {"branchAddress": {"postalAddress": {"line1":..., "line2":...,
    // "city":..., "country":...}}}. Some branch lookups instead nest the
    // address directly under `address` — kept as a fallback — and the
    // item's own top-level fields are merged last-priority in case a
    // future/other environment flattens the shape.
    final branchAddress = unwrap(map['branchAddress']);
    final postalAddress = unwrap(branchAddress['postalAddress']);
    final legacyAddress = unwrap(map['address']);
    final merged = {
      ...map,
      ...branchAddress,
      ...legacyAddress,
      ...postalAddress,
    };
    return BranchAddress(
      line1: firstNonEmptyPayeeField(
        merged,
        const ['line1', 'addressLine1', 'address1', 'add1', 'street'],
      ),
      line2: firstNonEmptyPayeeField(
        merged,
        const ['line2', 'addressLine2', 'address2', 'add2'],
      ),
      city: firstNonEmptyPayeeField(
        merged,
        const ['city', 'cityName', 'cityDescription'],
      ),
      state: firstNonEmptyPayeeField(
        merged,
        const ['state', 'region', 'province', 'stateName'],
      ),
      country: firstNonEmptyPayeeField(
        merged,
        const ['country', 'countryName', 'countryDescription'],
      ),
    );
  }
}

/// A single address entry (Postal / Residence / Work) from the logged-in
/// user's party details (`/digx-common/user/v1/me/party`), used for the
/// Demand Draft Payee "My Address" preview. See [CityOption] for why
/// parsing is lenient.
class PartyAddress {
  const PartyAddress({
    required this.type,
    this.line1,
    this.line2,
    this.line3,
    this.country,
  });

  final String type;
  final String? line1;
  final String? line2;
  final String? line3;
  final String? country;

  List<String> get displayLines =>
      [line1, line2, line3, country].whereType<String>().toList();

  factory PartyAddress.fromMap(Map<String, dynamic> map) {
    return PartyAddress(
      type: firstNonEmptyPayeeField(
            map,
            const ['addressType', 'type', 'code'],
          ) ??
          '',
      line1: firstNonEmptyPayeeField(
        map,
        const ['addressLine1', 'address1', 'line1'],
      ),
      line2: firstNonEmptyPayeeField(
        map,
        const ['addressLine2', 'address2', 'line2'],
      ),
      line3: firstNonEmptyPayeeField(
        map,
        const ['addressLine3', 'address3', 'line3', 'city'],
      ),
      country: firstNonEmptyPayeeField(
        map,
        const ['country', 'countryName', 'nationality'],
      ),
    );
  }

  /// Extracts every address entry found in a `/user/v1/me/party` response
  /// body, trying the common locations OBDX nests addresses under.
  static List<PartyAddress> listFromPartyResponse(Map<String, dynamic> body) {
    dynamic raw = body['addresses'];
    if (raw is! List) {
      final party = body['party'];
      if (party is Map) raw = party['addresses'];
    }
    if (raw is! List) {
      final contact = body['contactDetails'] ?? body['contact'];
      if (contact is Map) raw = contact['addresses'];
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => PartyAddress.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}

class PayeeSummary {
  const PayeeSummary({
    required this.nickname,
    required this.accountType,
    required this.accountDetails,
    this.accountNumber,
    this.payeeType,
    this.raw = const {},
  });

  final String nickname;
  final String accountType;
  final String accountDetails;
  final String? accountNumber;
  final String? payeeType;
  final Map<String, dynamic> raw;

  factory PayeeSummary.fromMap(Map<String, dynamic> source) {
    final nested = source['payee'] is Map
        ? Map<String, dynamic>.from(source['payee'] as Map)
        : <String, dynamic>{};
    final map = {...nested, ...source};

    return PayeeSummary(
      nickname: _firstString(map, const [
            'nickName',
            'nickname',
            'payeeNickname',
            'payeeNickName',
          ]) ??
          '—',
      accountType: _firstString(map, const [
            'accountType',
            'payeeAccountType',
            'type',
          ]) ??
          'Account',
      accountDetails: _firstString(map, const [
            'accountDetails',
            'accountDetail',
            'payeeDetails',
            'bankName',
          ]) ??
          '—',
      accountNumber: _firstString(map, const [
        'accountNumber',
        'accountNo',
      ]),
      payeeType: _firstString(map, const [
        'payeeType',
        'type',
      ]),
      raw: Map<String, dynamic>.from(map),
    );
  }

  static String? _firstString(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }
}