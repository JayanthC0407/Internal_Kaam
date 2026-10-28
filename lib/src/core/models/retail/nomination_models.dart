import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// OBDX Nominations (`components/nominee`): the list of accounts with
/// their nominee status, and View Nominee.
/// Evidence: docs/obdx/features/nominations.md.

/// Account Category, from the user's roles (nominations/hooks.js:84-121).
enum NominationCategory {
  casa,
  termDeposits,
  recurringDeposits;

  /// `CASARole`, `TDRole`, `RDRole`, in the order the roles come.
  static List<NominationCategory> fromRoles(Iterable<String> roles) {
    final out = <NominationCategory>[];
    for (final r in roles) {
      final c = switch (r.toUpperCase()) {
        'CASAROLE' => casa,
        'TDROLE' => termDeposits,
        'RDROLE' => recurringDeposits,
        _ => null,
      };
      if (c != null && !out.contains(c)) out.add(c);
    }
    return out;
  }
}

/// What a row's Action opens (casa-nominee-list/hooks.js:62-107), by
/// holding pattern and whether a nominee is registered.
enum NomineeAction {
  /// SINGLE, registered: "View/Edit".
  viewEdit,

  /// SINGLE, not registered: "Add" (Add Nominee).
  add,

  /// JOINT, registered: "View".
  view,

  /// JOINT, not registered: "Know More" (the branch nomination form note).
  knowMore,
}

/// One row of the Nominations list: an account of `accounts[]`.
class NominationRow {
  const NominationRow({
    required this.accountId,
    required this.accountDisplay,
    this.primaryHolder,
    this.joint = false,
    this.registered = false,
  });

  /// `id.value` — used for `nominee/{accountId}`.
  final String accountId;
  final String accountDisplay;

  /// `partyName`.
  final String? primaryHolder;

  /// `holdingPattern` JOINT (else SINGLE).
  final bool joint;

  /// `nomineeRegistered`.
  final bool registered;

  NomineeAction get action => switch ((joint, registered)) {
        (false, true) => NomineeAction.viewEdit,
        (false, false) => NomineeAction.add,
        (true, true) => NomineeAction.view,
        (true, false) => NomineeAction.knowMore,
      };

  static List<NominationRow> listFromPayload(Map<String, dynamic> body) {
    final raw = body['accounts'];
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map)
          if (ObdxApiUtils.asMap(r) case final m)
            if (_id(m['id']) case final id?)
              NominationRow(
                accountId: id.$1,
                accountDisplay: id.$2,
                primaryHolder: _str(m['partyName']),
                joint: (_str(m['holdingPattern']) ?? '').toUpperCase() == 'JOINT',
                registered: '${m['nomineeRegistered']}'.toLowerCase() == 'true',
              ),
    ];
  }
}

class NomineeAddress {
  const NomineeAddress({this.line1, this.city, this.state, this.country, this.zipCode});

  final String? line1;
  final String? city;
  final String? state;

  /// A country code; the screen shows its description.
  final String? country;
  final String? zipCode;

  static NomineeAddress fromJson(dynamic json) {
    final m = ObdxApiUtils.asMap(json);
    return NomineeAddress(
      line1: _str(m['line1']),
      city: _str(m['city']),
      state: _str(m['state']),
      country: _str(m['country']),
      zipCode: _str(m['zipCode']),
    );
  }

  /// OBDX's order: line 1, city, state, country, zip (view-nominee/hooks.js:148-154).
  List<String> lines(String? countryName) =>
      [line1, city, state, countryName ?? country, zipCode].whereType<String>().toList();
}

/// `GET party nominee/{accountId}` → `nomineeDTO`.
class Nominee {
  const Nominee({
    required this.name,
    this.dateOfBirth,
    this.relation,
    this.address = const NomineeAddress(),
    this.minor = false,
    this.guardianName,
    this.guardianAddress,
  });

  final String name;
  final DateTime? dateOfBirth;

  /// A relation value; the screen shows its description.
  final String? relation;
  final NomineeAddress address;
  final bool minor;
  final String? guardianName;
  final NomineeAddress? guardianAddress;

  static Nominee? fromPayload(Map<String, dynamic> body) {
    final dto = ObdxApiUtils.asMap(body['nomineeDTO']);
    final name = _str(dto['name']);
    if (name == null) return null;
    final minor = '${dto['minor']}'.toLowerCase() == 'true';
    final guardian = ObdxApiUtils.asMap(dto['guardian']);
    return Nominee(
      name: name,
      dateOfBirth: DateTime.tryParse(_str(dto['dateOfBirth']) ?? ''),
      relation: _str(dto['relation']),
      address: NomineeAddress.fromJson(dto['address']),
      minor: minor,
      guardianName: minor ? _str(guardian['name']) : null,
      guardianAddress: minor ? NomineeAddress.fromJson(guardian['address']) : null,
    );
  }
}

/// `enumRepresentations[0].data[]`: relations are matched on `value`,
/// countries on `code` (view-nominee/hooks.js:128-140); both show
/// `description`.
Map<String, String> nomineeEnumDescriptions(Map<String, dynamic> body, {required String key}) {
  final reps = body['enumRepresentations'];
  if (reps is! List || reps.isEmpty) return const {};
  final data = ObdxApiUtils.asMap(reps.first)['data'];
  if (data is! List) return const {};
  return {
    for (final d in data)
      if (d is Map)
        if (_str(ObdxApiUtils.asMap(d)[key]) case final k?) k: _str(ObdxApiUtils.asMap(d)['description']) ?? k,
  };
}

String? _str(dynamic value) {
  if (value == null || value is Map || value is List) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

(String, String)? _id(dynamic json) {
  if (json is! Map) return null;
  final map = ObdxApiUtils.asMap(json);
  final value = _str(map['value']);
  if (value == null) return null;
  return (value, _str(map['displayValue']) ?? value);
}
