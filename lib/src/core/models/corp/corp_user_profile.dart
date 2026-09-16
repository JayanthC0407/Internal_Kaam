import 'package:ubci_bank/src/core/utils/profile_initials.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// The authenticated corporate user, parsed from `GET /digx-common/user/v1/me`.
///
/// The `me` response is already captured during login and handed to the
/// dashboard on `HomeDashboardArgs.loginTrace['profileResponse']`, so the
/// corporate dashboard can render its header (name, initials, entity) with
/// no extra round trip. See the Corporate "LOGIN to DASHBOARD" capture,
/// entry #5.
class CorpUserProfile {
  const CorpUserProfile({
    required this.userName,
    this.firstName,
    this.middleName,
    this.lastName,
    this.partyId,
    this.partyIdDisplay,
    this.partyName,
    this.roles = const <String>[],
    this.groupCorporateId,
    this.homeEntity,
    this.accessibleEntities = const <String>[],
    this.emailDisplay,
    this.phoneDisplay,
    this.lastLoginTime,
    this.isCorpAdmin = false,
    this.inactiveSessionTimeoutMs,
  });

  final String userName;
  final String? firstName;
  final String? middleName;
  final String? lastName;

  /// `userProfile.partyId.value` — needed by every party-scoped corporate
  /// API (trade finance bills, supply-chain invoices, …).
  final String? partyId;

  /// `userProfile.partyId.displayValue`, e.g. `***401`.
  final String? partyIdDisplay;

  /// Corporate entity name (`accessibleEntityDTOs[].partyName`), e.g.
  /// `LC TEST4`.
  final String? partyName;

  /// `userProfile.roles`, e.g. `['corporateuser', 'Maker']`.
  final List<String> roles;

  final String? groupCorporateId;
  final String? homeEntity;
  final List<String> accessibleEntities;
  final String? emailDisplay;
  final String? phoneDisplay;
  final DateTime? lastLoginTime;
  final bool isCorpAdmin;

  /// `inactiveSessionTimeout` from the `me` response (milliseconds).
  final int? inactiveSessionTimeoutMs;

  /// `Pooja Jha` — falls back to the login username.
  String get fullName {
    final parts = [firstName, middleName, lastName]
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty);
    final joined = parts.join(' ');
    return joined.isNotEmpty ? joined : userName;
  }

  /// `SS`-style avatar initials for the header.
  String get initials {
    final fromName = ProfileInitials.fromName(fullName);
    if (fromName.isNotEmpty) return fromName;
    return ProfileInitials.fromName(userName);
  }

  /// Approval role flags the corporate menus key off.
  bool get isMaker => _hasRole('maker');
  bool get isChecker => _hasRole('checker') || _hasRole('approver');
  bool get isViewer => _hasRole('viewer');

  bool _hasRole(String role) =>
      roles.any((value) => value.trim().toLowerCase() == role);

  /// Parses the wrapped `me` response — either the full
  /// `{ statusCode, headers, body }` envelope stored on the login trace, or
  /// an already-unwrapped body.
  static CorpUserProfile? fromProfileResponse(dynamic profileResponse) {
    final body = _bodyOf(profileResponse);
    if (body == null) return null;

    final userProfile = ObdxApiUtils.asMap(body['userProfile']);
    if (userProfile.isEmpty) return null;

    final userName = (userProfile['userName'] ?? '').toString().trim();
    if (userName.isEmpty) return null;

    final partyIdMap = ObdxApiUtils.asMap(userProfile['partyId']);
    final emailMap = ObdxApiUtils.asMap(userProfile['emailId']);
    final phoneMap = ObdxApiUtils.asMap(userProfile['phoneNumber']);

    final rolesRaw = userProfile['roles'];
    final roles = rolesRaw is List
        ? rolesRaw
            .map((role) => role?.toString().trim() ?? '')
            .where((role) => role.isNotEmpty)
            .toList()
        : const <String>[];

    final entitiesRaw = userProfile['accessibleEntities'];
    final entities = entitiesRaw is List
        ? entitiesRaw
            .map((entity) => entity?.toString().trim() ?? '')
            .where((entity) => entity.isNotEmpty)
            .toList()
        : const <String>[];

    final timeoutRaw = body['inactiveSessionTimeout'];

    return CorpUserProfile(
      userName: userName,
      firstName: _trimmed(userProfile['firstName']),
      middleName: _trimmed(userProfile['middleName']),
      lastName: _trimmed(userProfile['lastName']),
      partyId: _trimmed(partyIdMap['value']),
      partyIdDisplay: _trimmed(partyIdMap['displayValue']),
      partyName: _partyNameOf(userProfile),
      roles: roles,
      groupCorporateId: _trimmed(userProfile['groupCorporateId']),
      homeEntity: _trimmed(userProfile['homeEntity']),
      accessibleEntities: entities,
      emailDisplay: _trimmed(emailMap['displayValue']),
      phoneDisplay: _trimmed(phoneMap['displayValue']),
      lastLoginTime:
          DateTime.tryParse(userProfile['lastLoginTime']?.toString() ?? ''),
      isCorpAdmin: userProfile['corpAdmin'] == true,
      inactiveSessionTimeoutMs: timeoutRaw is num
          ? timeoutRaw.toInt()
          : int.tryParse(timeoutRaw?.toString() ?? ''),
    );
  }

  /// `accessibleEntityDTOs[]` carries the human-readable corporate entity
  /// name; the one matching `homeEntity` wins, else the first.
  static String? _partyNameOf(Map<String, dynamic> userProfile) {
    final entityDtos = userProfile['accessibleEntityDTOs'];
    if (entityDtos is! List || entityDtos.isEmpty) return null;

    final homeEntity = userProfile['homeEntity']?.toString().trim();
    Map<String, dynamic>? fallback;
    for (final dto in entityDtos) {
      if (dto is! Map) continue;
      final map = Map<String, dynamic>.from(dto);
      fallback ??= map;
      if (homeEntity != null &&
          homeEntity.isNotEmpty &&
          map['entityId']?.toString().trim() == homeEntity) {
        return _trimmed(map['partyName']) ?? _trimmed(map['entityName']);
      }
    }
    if (fallback == null) return null;
    return _trimmed(fallback['partyName']) ?? _trimmed(fallback['entityName']);
  }

  static Map<String, dynamic>? _bodyOf(dynamic profileResponse) {
    if (profileResponse is! Map) return null;
    final map = Map<String, dynamic>.from(profileResponse);
    if (map.containsKey('userProfile')) return map;
    final body = map['body'];
    if (body is Map) return _bodyOf(body);
    return null;
  }

  static String? _trimmed(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}
