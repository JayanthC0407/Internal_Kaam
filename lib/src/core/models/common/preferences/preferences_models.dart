import 'dart:convert';
import 'dart:typed_data';

import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Account Settings → Preferences (OBDX `side-menu`): Profile, Primary
/// Account Number, Third Party Applications, Security & Login, Themes and
/// Settings. Payload shapes follow the OBDX channel components named on
/// each class.

// ── Profile (`base-components-profile`) ──────────────────────────────────

/// One row of `profileConfig` → `userProfileConfigDTO.personalDetails[]` /
/// `contactDetails[]`.
class ProfileFieldConfig {
  const ProfileFieldConfig({required this.fieldName, required this.label, this.editable = false});

  /// `EMAIL`, `PHONENO`, `FAXNO`, `ADDRESS`, an identification type, …
  final String fieldName;

  /// `displayValue`, shown as the field's label.
  final String label;
  final bool editable;

  factory ProfileFieldConfig.fromJson(Map<String, dynamic> json) => ProfileFieldConfig(
        fieldName: (json['fieldName'] ?? '').toString(),
        label: (json['displayValue'] ?? json['fieldName'] ?? '').toString(),
        editable: json['editable'] == true || json['editable']?.toString().toLowerCase() == 'true',
      );

  static List<ProfileFieldConfig> listOf(dynamic raw) => [
        if (raw is List)
          for (final item in raw)
            if (item is Map) ProfileFieldConfig.fromJson(Map<String, dynamic>.from(item)),
      ];
}

/// `{areaCode, number}` of a phone or fax contact.
class ProfilePhone {
  const ProfilePhone({this.areaCode = '', this.number = ''});

  final String areaCode;
  final String number;

  bool get isEmpty => number.isEmpty;

  factory ProfilePhone.fromJson(dynamic raw) {
    final map = ObdxApiUtils.asMap(raw);
    return ProfilePhone(
      areaCode: _str(map['areaCode']),
      number: _str(map['number']),
    );
  }

  Map<String, dynamic> toJson() => {'areaCode': areaCode, 'number': number};
}

/// The `PST` (postal) address of `party.addresses[]`.
class ProfileAddress {
  const ProfileAddress({
    this.line1 = '',
    this.line2 = '',
    this.line3 = '',
    this.line4 = '',
    this.city = '',
    this.country = '',
    this.postalCode = '',
  });

  final String line1;
  final String line2;
  final String line3;
  final String line4;
  final String city;
  final String country;
  final String postalCode;

  factory ProfileAddress.fromJson(dynamic raw) {
    final map = ObdxApiUtils.asMap(raw);
    return ProfileAddress(
      line1: _str(map['line1']),
      line2: _str(map['line2']),
      line3: _str(map['line3']),
      line4: _str(map['line4']),
      city: _str(map['city']),
      country: _str(map['country']),
      postalCode: _str(map['postalCode'] ?? map['zipCode']),
    );
  }

  /// OBDX's serializer: `{line1}, {line2}, {line3}, {line4}, {city}, {country},{postalCode}`
  /// with empty parts left out.
  String get formatted => [line1, line2, line3, line4, city, country, postalCode].where((p) => p.isNotEmpty).join(', ');

  /// `attr_value` of an ADDRESS update.
  Map<String, dynamic> toJson() => {
        'line1': line1,
        'line2': line2,
        'line3': line3,
        'city': city,
        'country': country,
        'postalCode': postalCode,
      };

  bool sameAs(ProfileAddress other) =>
      line1 == other.line1 &&
      line2 == other.line2 &&
      line3 == other.line3 &&
      city == other.city &&
      postalCode == other.postalCode &&
      country.toUpperCase() == other.country.toUpperCase();
}

/// The signed-in party: `GET me/party` read together with `profileConfig`.
class PartyProfile {
  const PartyProfile({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.fullName,
    required this.birthDate,
    required this.email,
    required this.phone,
    required this.fax,
    required this.address,
    required this.identifications,
    required this.personalFields,
    required this.contactFields,
    required this.mobileIsd,
    required this.faxIsd,
  });

  final String firstName;
  final String middleName;
  final String lastName;
  final String fullName;
  final DateTime? birthDate;
  final String email;
  final ProfilePhone phone;
  final ProfilePhone fax;
  final ProfileAddress address;

  /// `party.identifications[]`: type → id.
  final Map<String, String> identifications;

  /// The "Personal Information" rows OBDX shows below Date of Birth.
  final List<ProfileFieldConfig> personalFields;

  /// The "Contact Information" rows (PHONEISDNO / FAXISDNO are flags, not rows).
  final List<ProfileFieldConfig> contactFields;

  /// `PHONEISDNO` / `FAXISDNO` in `contactDetails`: phone and fax are edited
  /// as Area Code + Number.
  final bool mobileIsd;
  final bool faxIsd;

  String get displayName {
    final parts = [firstName, middleName, lastName].where((p) => p.isNotEmpty);
    return parts.isEmpty ? fullName : parts.join(' ');
  }

  /// Fields OBDX lists as "Edit {label}" in its menu.
  List<ProfileFieldConfig> get editableFields => [
        for (final f in [...personalFields, ...contactFields])
          if (f.editable) f,
      ];

  /// What OBDX shows for [fieldName] (`partyData[fieldName]`).
  String valueOf(String fieldName) {
    switch (fieldName) {
      case 'EMAIL':
        return email;
      case 'PHONENO':
        return mobileIsd ? '${phone.areaCode}${phone.number}' : phone.number;
      case 'FAXNO':
        return faxIsd ? '${fax.areaCode}${fax.number}' : fax.number;
      case 'ADDRESS':
        return address.formatted;
    }
    return identifications[fieldName] ?? '';
  }

  bool isIdentification(String fieldName) => identifications.containsKey(fieldName);

  factory PartyProfile.fromPayloads({required Map<String, dynamic> party, required Map<String, dynamic> config}) {
    final p = ObdxApiUtils.asMap(party['party'] ?? party);
    final personal = ObdxApiUtils.asMap(p['personalDetails']);
    final dto = ObdxApiUtils.asMap(config['userProfileConfigDTO']);

    var phone = const ProfilePhone();
    var fax = const ProfilePhone();
    for (final contact in _maps(p['contacts'])) {
      final type = _str(contact['contactType']);
      if (type == 'WMO') phone = ProfilePhone.fromJson(contact['phone']);
      if (type == 'FAX') fax = ProfilePhone.fromJson(contact['fax']);
    }

    var address = const ProfileAddress();
    for (final a in _maps(p['addresses'])) {
      if (_str(a['type']) == 'PST') address = ProfileAddress.fromJson(a['postalAddress']);
    }

    final identifications = <String, String>{
      for (final id in _maps(p['identifications']))
        if (_str(id['type']).isNotEmpty) _str(id['type']): _str(id['id']),
    };

    final contactRaw = ProfileFieldConfig.listOf(dto['contactDetails']);
    final mobileIsd = contactRaw.any((f) => f.fieldName == 'PHONEISDNO');
    final faxIsd = contactRaw.any((f) => f.fieldName == 'FAXISDNO');

    return PartyProfile(
      firstName: _str(personal['firstName']),
      middleName: _str(personal['middleName']),
      lastName: _str(personal['lastName']),
      fullName: _str(personal['fullName']),
      birthDate: DateTime.tryParse(_str(personal['birthDate'])),
      email: _str(personal['email'] is Map ? personal['email']['displayValue'] : personal['email']),
      phone: phone,
      fax: fax,
      address: address,
      identifications: identifications,
      personalFields: ProfileFieldConfig.listOf(dto['personalDetails']),
      contactFields: [
        for (final f in contactRaw)
          if (f.fieldName != 'PHONEISDNO' && f.fieldName != 'FAXISDNO') f,
      ],
      mobileIsd: mobileIsd,
      faxIsd: faxIsd,
    );
  }
}

/// `enumerations/country` → `enumRepresentations[0].data[]`.
class ProfileCountry {
  const ProfileCountry({required this.code, required this.name});

  final String code;
  final String name;

  static List<ProfileCountry> listFromPayload(Map<String, dynamic> body) {
    final reps = body['enumRepresentations'];
    if (reps is! List || reps.isEmpty) return const [];
    return [
      for (final row in _maps(ObdxApiUtils.asMap(reps.first)['data']))
        ProfileCountry(code: _str(row['code']), name: _str(row['description'])),
    ];
  }
}

// ── User preferences (`userPreferences`, apiType sms) ────────────────────

/// `GET userPreferences`. OBDX edits this object and `PUT`s all of it back
/// (minus `status`) for Primary Account, Third Party Applications and the
/// Settings toggles, so the raw body is kept.
class UserPreferences {
  UserPreferences(Map<String, dynamic> raw) : raw = Map<String, dynamic>.unmodifiable(_withoutStatus(raw));

  final Map<String, dynamic> raw;

  static Map<String, dynamic> _withoutStatus(Map<String, dynamic> body) => Map<String, dynamic>.from(body)..remove('status');

  bool get feedbackEnabled => raw['feedbackEnabled'] == true;
  bool get liveExpEnabled => raw['liveExpEnabled'] == true;

  /// `SMS`, `EMAIL` or `BOTH`.
  String? get otpDeliveryMode => raw['otpDeliveryMode']?.toString();

  /// The primary account for [entity] (`operativeAccount[].determinantValue`).
  String? primaryAccountFor(String entity) {
    for (final row in _maps(raw['operativeAccount'])) {
      if (_str(row['determinantValue']) == entity) {
        final id = ObdxApiUtils.asMap(row['accountId']);
        final value = _str(id['value']);
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  /// `userAccessPointRelationship[]`: access point id → granted.
  Map<String, bool> get accessPointStatus => {
        for (final row in _maps(raw['userAccessPointRelationship']))
          if (_str(row['accessPointId']).isNotEmpty) _str(row['accessPointId']): row['status'] == true,
      };

  Map<String, dynamic> _copy() => jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;

  /// sms-primary-account: drops [entity]'s entry, then adds the chosen one.
  Map<String, dynamic> withPrimaryAccount(String entity, {String? accountId, String? displayValue}) {
    final body = _copy();
    final list = [
      for (final row in _maps(body['operativeAccount']))
        if (_str(row['determinantValue']) != entity) row,
    ];
    if (accountId != null) {
      list.add({
        'determinantValue': entity,
        'accountId': {'value': accountId, 'displayValue': displayValue ?? accountId},
      });
    }
    return body..['operativeAccount'] = list;
  }

  Map<String, dynamic> withAccessPointStatus(String accessPointId, bool granted) {
    final body = _copy();
    // The decoded copy's own rows — `_maps` would edit copies of them.
    final rows = body['userAccessPointRelationship'];
    if (rows is List) {
      for (final row in rows) {
        if (row is Map && _str(row['accessPointId']) == accessPointId) row['status'] = granted;
      }
    }
    return body;
  }

  Map<String, dynamic> withValue(String key, Object? value) => _copy()..[key] = value;
}

// ── Third Party Applications (`third-party-consents`) ────────────────────

/// An external (`EXT`) access point the user has a relationship with.
class ThirdPartyApp {
  const ThirdPartyApp({required this.id, required this.name, required this.granted, this.contentId, this.logo});

  final String id;
  final String name;
  final bool granted;
  final String? contentId;
  final Uint8List? logo;

  ThirdPartyApp withLogo(Uint8List? bytes) => ThirdPartyApp(id: id, name: name, granted: granted, contentId: contentId, logo: bytes);
}

/// The three account tabs OBDX shows under an app.
enum ConsentAccountType {
  csa('CSA'),
  trd('TRD'),
  lon('LON');

  const ConsentAccountType(this.code);

  final String code;

  static ConsentAccountType? parse(String code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// One account under an app: `accountExclusionDTOs[]`.
class ConsentAccount {
  const ConsentAccount({required this.accountNumber, required this.taskIds, this.exclusionId});

  /// `{value, displayValue}`, sent back as is.
  final Map<String, dynamic> accountNumber;
  final List<String> taskIds;
  final String? exclusionId;

  String get displayValue => _str(accountNumber['displayValue'] ?? accountNumber['value']);
  String get value => _str(accountNumber['value']);
}

/// `accessPointAccountDTOs[]` of one account type.
class ConsentAccountGroup {
  const ConsentAccountGroup({required this.type, required this.accounts, this.accountAccessId});

  final ConsentAccountType type;
  final String? accountAccessId;
  final List<ConsentAccount> accounts;
}

/// `GET accountAccess/me/accessPointAccount/{accessPointId}`.
class ConsentSetup {
  const ConsentSetup(this.groups);

  final Map<ConsentAccountType, ConsentAccountGroup> groups;

  factory ConsentSetup.fromPayload(Map<String, dynamic> body) {
    final groups = <ConsentAccountType, ConsentAccountGroup>{};
    for (final dto in _maps(body['accessPointAccountDTOs'])) {
      final type = ConsentAccountType.parse(_str(dto['accountType']));
      if (type == null) continue;
      groups[type] = ConsentAccountGroup(
        type: type,
        accountAccessId: _nullable(dto['accountAccessId']),
        accounts: [
          for (final a in _maps(dto['accountExclusionDTOs']))
            ConsentAccount(
              accountNumber: ObdxApiUtils.asMap(a['accountNumber']),
              taskIds: [
                if (a['taskIds'] is List)
                  for (final t in a['taskIds'] as List) t.toString(),
              ],
              exclusionId: _nullable(a['accountExclusionId']),
            ),
        ],
      );
    }
    return ConsentSetup(groups);
  }
}

/// The user's choice for one account: mapped at all, and which tasks.
class ConsentSelection {
  const ConsentSelection({required this.checked, required this.tasks});

  final bool checked;
  final Set<String> tasks;

  ConsentSelection copyWith({bool? checked, Set<String>? tasks}) =>
      ConsentSelection(checked: checked ?? this.checked, tasks: tasks ?? this.tasks);
}

// ── Security & Login ─────────────────────────────────────────────────────

/// A question the user has set (`userSecurityQuestionDTOList[]`).
class UserSecurityQuestion {
  const UserSecurityQuestion({required this.questionId, required this.question});

  final String questionId;
  final String question;

  static List<UserSecurityQuestion> listFromPayload(Map<String, dynamic> body) {
    final list = body['userSecurityQuestionDTOList'] ?? body['userSecurityQuestionList'];
    return [
      for (final row in _maps(list))
        UserSecurityQuestion(
          questionId: _str(row['questionId'] ?? ObdxApiUtils.asMap(row['securityQuestion'])['questionId']),
          question: _str(row['question'] ?? ObdxApiUtils.asMap(row['securityQuestion'])['question']),
        ),
    ];
  }
}

/// `smsbanking/pinRegistration` → `pinRegistrationDTO`.
class SmsBankingRegistration {
  const SmsBankingRegistration({required this.missedCallEnabled, required this.smsBankingEnabled});

  final bool missedCallEnabled;
  final bool smsBankingEnabled;

  factory SmsBankingRegistration.fromPayload(Map<String, dynamic> body) {
    final dto = ObdxApiUtils.asMap(body['pinRegistrationDTO']);
    return SmsBankingRegistration(
      missedCallEnabled: dto['missedCallEnabled'] == true,
      smsBankingEnabled: dto['smsBankingEnabled'] == true,
    );
  }
}

/// `POST softtokenseed/qr` → `{fileContent, tokenSeed}`.
class SoftTokenSeed {
  const SoftTokenSeed({required this.qrPng, required this.seed});

  final Uint8List? qrPng;
  final String seed;

  factory SoftTokenSeed.fromPayload(Map<String, dynamic> body) {
    final content = _str(body['fileContent']);
    Uint8List? png;
    if (content.isNotEmpty) {
      try {
        png = base64Decode(content);
      } catch (_) {
        png = null;
      }
    }
    return SoftTokenSeed(qrPng: png, seed: _str(body['tokenSeed']));
  }
}

// ── Settings (`generic-settings`) ────────────────────────────────────────

/// OS keys used by `mobileClient` (device and push unbinding).
abstract final class DeviceOs {
  static const android = 'ANDROID';
  static const ios = 'IOS';
  static const androidWear = 'ANDROID_WEAR';
  static const iosWear = 'IOS_WEAR';
  static const browser = 'BROWSER';
}

/// `mobileClient/registeredDevices` / `registeredPushToken` → `listDTO[{os, count}]`.
class DeviceCounts {
  const DeviceCounts(this.byOs);

  final Map<String, int> byOs;

  int of(String os) => byOs[os] ?? 0;

  factory DeviceCounts.fromPayload(Map<String, dynamic> body) => DeviceCounts({
        for (final row in _maps(body['listDTO']))
          _str(row['os']).toUpperCase(): int.tryParse(_str(row['count'])) ?? 0,
      });
}

// ── Writes ───────────────────────────────────────────────────────────────

/// Result of a Preferences write: done (maybe pending approval, with the
/// reference), or an OTP to enter first (417).
class PrefWriteOutcome {
  const PrefWriteOutcome.done({this.pendingApproval = false, this.reference})
      : challenge = null,
        invalidOtp = false;

  const PrefWriteOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : pendingApproval = false,
        reference = null;

  final ObdxChallenge? challenge;
  final bool invalidOtp;
  final bool pendingApproval;
  final String? reference;
}

// ── Helpers ──────────────────────────────────────────────────────────────

String _str(dynamic v) => v == null || v is Map || v is List ? '' : v.toString().trim();

String? _nullable(dynamic v) {
  final s = _str(v);
  return s.isEmpty ? null : s;
}

List<Map<String, dynamic>> _maps(dynamic raw) => [
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
