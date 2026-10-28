import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Account Settings → Session Summary (`base-components/session-summary`),
/// Alerts Subscription (`alerts/user-alerts-subscription`) and Change
/// Password (`change-password/change-password`). Payload shapes follow
/// those components' model.js.

// ── Session Summary ──────────────────────────────────────────────────────

/// One sign-in: `GET me/sessions` → `userSessionDTOList[]`.
class UserSession {
  const UserSession({required this.sessionId, required this.accessPointId, this.start, this.end, this.ipAddress});

  final String sessionId;
  final DateTime? start;

  /// `lastUpdatedDate`; empty while the session is still open.
  final DateTime? end;

  /// `APINTERNET`, `APMOBAPP`, … — shown as the channel.
  final String accessPointId;
  final String? ipAddress;

  static List<UserSession> listFromPayload(Map<String, dynamic> body) => [
        for (final s in _maps(body['userSessionDTOList']))
          UserSession(
            sessionId: _str(s['sessionId']),
            start: DateTime.tryParse(_str(s['creationDate'])),
            end: DateTime.tryParse(_str(s['lastUpdatedDate'])),
            accessPointId: _str(s['accessPointId']),
            ipAddress: _nullable(s['ipAddress']),
          ),
      ]..sort((a, b) => (b.start ?? DateTime(0)).compareTo(a.start ?? DateTime(0)));
}

/// What was done in a session: `me/sessions/search` (with the
/// `SESSION-ID` header) → `auditList[]`.
class SessionActivity {
  const SessionActivity({required this.activity, required this.status, this.time});

  final String activity;

  /// `SUCCESS`, `FAILURE`, or empty.
  final String status;
  final DateTime? time;

  static List<SessionActivity> listFromPayload(Map<String, dynamic> body) => [
        for (final a in _maps(body['auditList']))
          SessionActivity(
            activity: _str(a['activity']),
            status: _str(a['status']).toUpperCase(),
            time: DateTime.tryParse(_str(a['startTime'])),
          ),
      ];
}

// ── Change Password ──────────────────────────────────────────────────────

/// The rules of `users/myPasswordPolicy` → `passwordPolicyDTO[0]`, in
/// OBDX's order (rules 1, 2, 3, 5, 7, 4, 8, 6, 9).
enum PasswordRule { length, upper, lower, number, special, successive, repeated, common, history }

class PasswordPolicy {
  const PasswordPolicy({
    this.minLength = 8,
    this.maxLength = 20,
    this.minUpper = 0,
    this.minLower = 0,
    this.minNumber = 0,
    this.minSpecial = 0,
    this.upperAllowed = true,
    this.lowerAllowed = true,
    this.numberAllowed = true,
    this.specialAllowed = true,
    this.specialChars = const [],
    this.maxSuccessive,
    this.maxRepeated,
    this.historySize,
    this.excludedWords = const [],
  });

  final int minLength;
  final int maxLength;
  final int minUpper;
  final int minLower;
  final int minNumber;
  final int minSpecial;
  final bool upperAllowed;
  final bool lowerAllowed;
  final bool numberAllowed;
  final bool specialAllowed;

  /// `specialCharAllowed[]`; empty allows any.
  final List<String> specialChars;

  /// `nbrSuccessiveChars` when `successiveAllowed` limits runs like "abcd".
  final int? maxSuccessive;

  /// `nbrRepeatChars`: a character may appear at most this many times.
  final int? maxRepeated;
  final int? historySize;

  /// `excludedDictWords[]` — the "common password" list.
  final List<String> excludedWords;

  factory PasswordPolicy.fromPayload(Map<String, dynamic> body) {
    final list = _maps(body['passwordPolicyDTO']);
    final p = list.isNotEmpty ? list.first : ObdxApiUtils.asMap(body['passwordPolicyDTO']);
    bool flag(String key) => p[key] == null || p[key] == true || _str(p[key]).toLowerCase() == 'true';
    int? positive(String key) {
      final v = _int(p[key]);
      return v == null || v <= 0 ? null : v;
    }

    return PasswordPolicy(
      minLength: _int(p['pwdMinLength']) ?? 8,
      maxLength: _int(p['pwdMaxLength']) ?? 20,
      minUpper: _int(p['nbrUpperAlpha']) ?? 0,
      minLower: _int(p['nbrLowerAlpha']) ?? 0,
      minNumber: _int(p['nbrNumeric']) ?? 0,
      minSpecial: _int(p['nbrSpecial']) ?? 0,
      upperAllowed: flag('upperAlphaAllowed'),
      lowerAllowed: flag('lowerAlphaAllowed'),
      numberAllowed: flag('numericAllowed'),
      specialAllowed: flag('specialCharsAllowed'),
      specialChars: [
        if (p['specialCharAllowed'] is List)
          for (final c in p['specialCharAllowed'] as List) _str(c),
      ].where((c) => c.isNotEmpty).toList(),
      maxSuccessive: p['successiveAllowed'] == false ? null : positive('nbrSuccessiveChars'),
      maxRepeated: positive('nbrRepeatChars'),
      historySize: positive('pwdHistorySize'),
      excludedWords: [
        if (p['excludedDictWords'] is List)
          for (final w in p['excludedDictWords'] as List) _str(w).toLowerCase(),
      ].where((w) => w.isNotEmpty).toList(),
    );
  }

  /// The rules this policy has, in display order.
  List<PasswordRule> get rules => [
        PasswordRule.length,
        PasswordRule.upper,
        PasswordRule.lower,
        PasswordRule.number,
        PasswordRule.special,
        if (maxSuccessive != null) PasswordRule.successive,
        if (maxRepeated != null) PasswordRule.repeated,
        PasswordRule.common,
        if (historySize != null) PasswordRule.history,
      ];

  static final _upper = RegExp('[A-Z]');
  static final _lower = RegExp('[a-z]');
  static final _digit = RegExp('[0-9]');
  static final _alnum = RegExp('[A-Za-z0-9]');

  /// OBDX's live checks (rules 1-8). History can only be checked by the
  /// bank, so it is null (unknown).
  bool? satisfies(PasswordRule rule, String password) {
    int count(RegExp r) => r.allMatches(password).length;
    final specials = password.split('').where((c) => !_alnum.hasMatch(c)).toList();
    switch (rule) {
      case PasswordRule.length:
        return password.length >= minLength && password.length <= maxLength;
      case PasswordRule.upper:
        return upperAllowed ? count(_upper) >= minUpper : count(_upper) == 0;
      case PasswordRule.lower:
        return lowerAllowed ? count(_lower) >= minLower : count(_lower) == 0;
      case PasswordRule.number:
        return numberAllowed ? count(_digit) >= minNumber : count(_digit) == 0;
      case PasswordRule.special:
        if (!specialAllowed) return specials.isEmpty;
        if (specials.length < minSpecial) return false;
        return specialChars.isEmpty || specials.every(specialChars.contains);
      case PasswordRule.successive:
        // A run of ascending character codes as long as the limit fails.
        var run = 1;
        for (var i = 1; i < password.length; i++) {
          run = password.codeUnitAt(i) == password.codeUnitAt(i - 1) + 1 ? run + 1 : 1;
          if (run > maxSuccessive!) return false;
        }
        return true;
      case PasswordRule.repeated:
        final counts = <String, int>{};
        for (final c in password.split('')) {
          counts[c] = (counts[c] ?? 0) + 1;
        }
        return counts.values.every((n) => n <= maxRepeated!);
      case PasswordRule.common:
        return password.isNotEmpty && !excludedWords.contains(password.toLowerCase());
      case PasswordRule.history:
        return null;
    }
  }

  /// Every rule the app can check holds.
  bool accepts(String password) => rules.every((r) => satisfies(r, password) != false);
}

// ── Alerts Subscription ──────────────────────────────────────────────────

/// The four delivery channels, with OBDX's `destination` codes.
enum AlertMode {
  push('PUSH_NOTIFICATION'),
  sms('SMS'),
  onScreen('SECURE_MAIL_BOX'),
  email('EMAIL');

  const AlertMode(this.code);

  final String code;

  static AlertMode? parse(String code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

/// `activityEventActions/modules` → `modules[]`.
class AlertModule {
  const AlertModule({required this.id, required this.description, required this.accountTypes});

  final String id;
  final String description;

  /// `CSA`, `TRD`, `LON`, or `PTY` for party-level modules.
  final List<String> accountTypes;

  bool get partyLevel => accountTypes.isEmpty || accountTypes.contains('PTY');

  /// Distinct by id, in the bank's order.
  static List<AlertModule> listFromPayload(Map<String, dynamic> body) {
    final seen = <String>{};
    return [
      for (final m in _maps(body['modules']))
        if (seen.add(_str(m['moduleId'])))
          AlertModule(
            id: _str(m['moduleId']),
            description: _str(m['description'] ?? m['moduleId']),
            accountTypes: [
              if (m['accountTypes'] is List)
                for (final t in m['accountTypes'] as List) _str(t),
            ],
          ),
    ];
  }
}

/// One alert the user can subscribe to: `activityEventActions?alertType=S`
/// → `alertResponseDTO[]`.
class AlertEvent {
  const AlertEvent({
    required this.description,
    required this.moduleType,
    required this.alertName,
    required this.activityId,
    required this.eventId,
    required this.actionId,
    required this.template,
  });

  final String description;
  final String moduleType;
  final String alertName;
  final String activityId;
  final String eventId;
  final String actionId;

  /// `alertDTO.alertTemplate`, sent back as `actionTemplate`.
  final Map<String, dynamic> template;

  static List<AlertEvent> listFromPayload(Map<String, dynamic> body) => [
        for (final e in _maps(body['alertResponseDTO']))
          () {
            final alert = ObdxApiUtils.asMap(e['alertDTO']);
            final key = ObdxApiUtils.asMap(alert['alertKeyDTO']);
            final template = ObdxApiUtils.asMap(alert['alertTemplate']);
            return AlertEvent(
              description: _str(e['activityEventDescription'] ?? alert['alertName']),
              moduleType: _str(e['moduleType']),
              alertName: _str(alert['alertName']),
              activityId: _str(key['activityId']),
              eventId: _str(key['eventId']),
              actionId: _str(key['actionId']),
              template: {
                'version': template['version'],
                'generatedPackageId': template['generatedPackageId'],
                'auditSequence': template['auditSequence'],
                'keyDTO': template['keyDTO'],
              },
            );
          }(),
      ];
}

/// An account (or, for party-level modules, a party) alerts are set for.
class AlertTarget {
  const AlertTarget({required this.value, required this.displayValue});

  final String value;
  final String displayValue;

  Map<String, dynamic> toJson() => {'value': value, 'displayValue': displayValue};

  /// `parties/{id}/accounts` → `partyToAccountRelationshipDTOs[].account`.
  static List<AlertTarget> accountsFromPayload(Map<String, dynamic> body) => [
        for (final r in _maps(body['partyToAccountRelationshipDTOs'] ?? body['accounts']))
          () {
            final a = ObdxApiUtils.asMap(r['account'] ?? r['accountId'] ?? r['id']);
            return AlertTarget(value: _str(a['value']), displayValue: _str(a['displayValue'] ?? a['value']));
          }(),
      ].where((t) => t.value.isNotEmpty).toList();
}

/// One subscription record: `GET actionSubscriptions` →
/// `actionSubscriptionDTO[]`. The raw actions are kept so a save only
/// changes the selected account's module.
class AlertSubscription {
  const AlertSubscription({required this.id, required this.level, required this.actions});

  final String id;

  /// `ACCOUNT` or `PARTY`.
  final String level;
  final List<Map<String, dynamic>> actions;

  static List<AlertSubscription> listFromPayload(Map<String, dynamic> body) => [
        for (final s in _maps(body['actionSubscriptionDTO'] ?? body['actionSubscriptionDTOs']))
          AlertSubscription(
            id: _str(s['subscriptionId']),
            level: _str(s['subscriptionLevel']).toUpperCase(),
            actions: _maps(s['subscribedActions']),
          ),
      ];

  /// The key an action is subscribed for (account or party value).
  static String keyOf(Map<String, dynamic> action) {
    final account = ObdxApiUtils.asMap(action['subscriptionLevelAccountKey'])['value'];
    if (account != null) return _str(account);
    final party = action['subscriptionLevelPartyKey'];
    return party is Map ? _str(party['value']) : _str(party);
  }

  /// eventId → modes subscribed for [targetValue] in [module].
  Map<String, Set<AlertMode>> modesFor(String module, String targetValue) => {
        for (final a in actions)
          if (_str(a['module']) == module && keyOf(a) == targetValue)
            _str(a['eventId']): {
              for (final p in _maps(a['subscriptionPreferences']))
                if (AlertMode.parse(_str(p['destination'])) != null) AlertMode.parse(_str(p['destination']))!,
            },
      };

  /// Account values that already have any alert in [module] ("Subscribed").
  Set<String> subscribedTargets(String module) => {
        for (final a in actions)
          if (_str(a['module']) == module) keyOf(a),
      };
}

/// The signed-in user for the strip at the top of Alerts Subscription:
/// `GET me` → `userProfile`.
class AlertsUser {
  const AlertsUser({
    required this.userId,
    required this.partyValue,
    required this.partyDisplay,
    required this.partyName,
    this.active = true,
    this.corporate = false,
    this.mobile,
    this.email,
  });

  final String userId;
  final String partyValue;
  final String partyDisplay;
  final String partyName;
  final bool active;

  /// `corporateuser` role: subscriber type CORPORATE / USER, and
  /// subscriptions are looked up by user id rather than party.
  final bool corporate;

  /// Where SMS / Email alerts go, when `me` carries them.
  final String? mobile;
  final String? email;

  factory AlertsUser.fromPayload(Map<String, dynamic> body) {
    final p = ObdxApiUtils.asMap(body['userProfile'] ?? body);
    final party = ObdxApiUtils.asMap(p['partyId']);
    final entities = _maps(p['accessibleEntityDTOs']);
    final name = [_str(p['firstName']), _str(p['middleName']), _str(p['lastName'])].where((s) => s.isNotEmpty).join(' ');
    String? contact(dynamic v) => v is Map ? _nullable(v['value'] ?? v['displayValue']) : _nullable(v);
    return AlertsUser(
      userId: _str(p['userName'] ?? p['userId']),
      partyValue: _str(party['value']),
      partyDisplay: _str(party['displayValue'] ?? party['value']),
      partyName: entities.isNotEmpty && _str(entities.first['partyName']).isNotEmpty
          ? _str(entities.first['partyName'])
          : name,
      active: !(_str(p['status']).toUpperCase() == 'LOCKED' || _str(p['status']).toUpperCase() == 'INACTIVE'),
      corporate: [
        if (p['roles'] is List)
          for (final r in p['roles'] as List) _str(r).toLowerCase(),
      ].contains('corporateuser'),
      mobile: contact(p['mobileNumber'] ?? p['phoneNumber']),
      email: contact(p['emailId'] ?? p['email']),
    );
  }
}

// ── Manage DND Alerts ────────────────────────────────────────────────────

/// A Select Category option: `dndRegistry` → `categories[]{id, name}`.
class DndCategory {
  const DndCategory({required this.id, required this.name, this.raw});

  final String id;
  final String name;

  /// The id as the bank sent it (string or number), sent back as is.
  final Object? raw;
}

/// `GET alerts dndRegistry`: the categories and the ids already chosen
/// (`mapped`), as manage-dnd-alerts-stage1/hooks.js:37-45 reads them.
class DndRegistry {
  const DndRegistry({required this.categories, required this.mapped});

  final List<DndCategory> categories;

  /// Ids ticked on load.
  final Set<String> mapped;

  factory DndRegistry.fromPayload(Map<String, dynamic> body) => DndRegistry(
        categories: [
          for (final c in _maps(body['categories']))
            if (_nullable(c['id']) case final id?) DndCategory(id: id, name: _nullable(c['name']) ?? id, raw: c['id']),
        ],
        mapped: {
          if (body['mapped'] is List)
            for (final m in body['mapped'] as List)
              if (_nullable(m is Map ? m['id'] : m) case final id?) id,
        },
      );

  /// Confirm's body, `PUT user me/dndRegistry` (review.js:44-50): the ticked
  /// ids, each as the bank sent it.
  Map<String, dynamic> body(Set<String> selected) => {
        'categories': [
          for (final c in categories)
            if (selected.contains(c.id)) c.raw ?? c.id,
        ],
      };
}

/// A category's events for the "DND Alert : {name}" dialog:
/// `activityEvents[].activityEventDescription`.
List<String> dndEventsFromPayload(Map<String, dynamic> body) => [
      for (final e in _maps(body['activityEvents']))
        if (_nullable(e['activityEventDescription']) case final d?) d,
    ];

String _str(dynamic v) => v == null || v is Map || v is List ? '' : v.toString().trim();

String? _nullable(dynamic v) {
  final s = _str(v);
  return s.isEmpty ? null : s;
}

int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse(_str(v));

List<Map<String, dynamic>> _maps(dynamic raw) => [
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
