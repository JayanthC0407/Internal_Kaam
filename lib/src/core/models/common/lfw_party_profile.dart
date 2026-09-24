/// Party details for LFW step 3 (`GET /digx-common/user/v1/me/party`).
///
/// OBDX nests these under `party`:
/// ```json
/// { "party": {
///     "personalDetails": {
///       "firstName": "TOM", "lastName": "PHILIP",
///       "fullName": "TOM PHILIP", "birthDate": "1990-12-01T00:00:00"
///     }
/// } }
/// ```
/// Only the name and date of birth are kept — the web client's profile step
/// shows nothing else, and contact / address data has no place in a
/// review-and-continue screen.
class LfwPartyProfile {
  const LfwPartyProfile({
    this.fullName = '',
    this.dateOfBirth = '',
  });

  final String fullName;
  final String dateOfBirth;

  bool get hasDetails => dateOfBirth.isNotEmpty;

  factory LfwPartyProfile.fromPayload(Map<String, dynamic> payload) {
    final party = _mapOf(payload['party'] ?? payload['partyDTO']) ?? payload;
    final personal = _mapOf(party['personalDetails']) ?? const {};

    return LfwPartyProfile(
      fullName: _fullNameOf(personal),
      dateOfBirth: _formatDate(
        _stringOf(personal['birthDate'] ?? personal['dateOfBirth']),
      ),
    );
  }

  static String _fullNameOf(Map<String, dynamic> personal) {
    final full = _stringOf(personal['fullName'] ?? personal['name']);
    if (full.isNotEmpty) return full;
    final parts = [
      _stringOf(personal['firstName']),
      _stringOf(personal['middleName']),
      _stringOf(personal['lastName']),
    ].where((p) => p.isNotEmpty);
    return parts.join(' ');
  }

  /// `1990-12-01T00:00:00` → `01 Dec 1990`; unparsable input is returned as-is.
  static String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = parsed.day.toString().padLeft(2, '0');
    return '$day ${months[parsed.month - 1]} ${parsed.year}';
  }

  static Map<String, dynamic>? _mapOf(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String _stringOf(dynamic value) {
    if (value == null) return '';
    if (value is Map || value is List) return '';
    return value.toString().trim();
  }
}
