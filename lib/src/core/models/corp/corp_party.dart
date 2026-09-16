import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// The corporate party behind the logged-in user, from
/// `GET /digx-common/user/v1/me/party` (Corporate capture, entry #12).
///
/// Supplies the authoritative entity name for the dashboard header and
/// account cards — `userProfile.accessibleEntityDTOs[].partyName` on the
/// `me` response can be stale or absent for some setups, this cannot.
class CorpParty {
  const CorpParty({
    required this.id,
    this.idDisplay,
    this.fullName,
    this.partyType,
    this.country,
    this.addressLine1,
    this.fatcaCheckRequired = false,
  });

  /// `party.id.value` — the party id every party-scoped corporate API needs.
  final String id;

  /// `party.id.displayValue`, e.g. `***401`.
  final String? idDisplay;

  /// `party.personalDetails.fullName`, e.g. `LC TEST4`.
  final String? fullName;

  /// `IND` / `CORP` etc.
  final String? partyType;

  final String? country;
  final String? addressLine1;
  final bool fatcaCheckRequired;

  static CorpParty? fromPayload(dynamic data) {
    final root = _unwrap(data);
    if (root == null) return null;

    final party = ObdxApiUtils.asMap(root['party']);
    if (party.isEmpty) return null;

    final idMap = ObdxApiUtils.asMap(party['id']);
    final id = (idMap['value'] ?? '').toString().trim();

    final personal = ObdxApiUtils.asMap(party['personalDetails']);

    String? country;
    String? line1;
    final addresses = party['addresses'];
    if (addresses is List) {
      for (final address in addresses) {
        if (address is! Map) continue;
        final postal = ObdxApiUtils.asMap(address['postalAddress']);
        if (postal.isEmpty) continue;
        country ??= postal['country']?.toString().trim();
        line1 ??= postal['line1']?.toString().trim();
      }
    }

    return CorpParty(
      id: id,
      idDisplay: _trimmed(idMap['displayValue']),
      fullName: _trimmed(personal['fullName']),
      partyType: _trimmed(personal['partyType']),
      country: (country?.isEmpty ?? true) ? null : country,
      addressLine1: (line1?.isEmpty ?? true) ? null : line1,
      fatcaCheckRequired: party['fatcaCheckRequired'] == true,
    );
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('party')) return map;
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }

  static String? _trimmed(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}
