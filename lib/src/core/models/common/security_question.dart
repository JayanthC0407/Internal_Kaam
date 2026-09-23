/// Master / user security question for LFW step 2.
class SecurityQuestionOption {
  const SecurityQuestionOption({
    required this.id,
    required this.text,
    this.languageId,
  });

  final String id;
  final String text;

  /// Locale of the master question text (e.g. `en-US`) — required on submit.
  final String? languageId;

  factory SecurityQuestionOption.fromJson(Map<String, dynamic> json) {
    // OBDX sometimes nests the payload under `securityQuestion`.
    final nested = json['securityQuestion'];
    final Map<String, dynamic> source;
    if (nested is Map) {
      source = {
        ...json,
        ...Map<String, dynamic>.from(nested),
      };
    } else {
      source = json;
    }

    // Prefer questionId — OBDX `secQueMapping` uses questionId; outer
    // `secQueList[].id` is a group id (e.g. 20611), not a selectable question.
    final id = _firstScalar(source, const [
          'questionId',
          'securityQuestionId',
          'id',
          'code',
          'key',
          'uuid',
          'determinantValue',
        ]) ??
        '';

    final text = _resolveText(source) ?? '';
    final languageId = _firstScalar(source, const [
      'languageId',
      'locale',
      'lang',
    ]);

    return SecurityQuestionOption(
      id: id,
      text: text.isNotEmpty ? text : id,
      languageId: languageId,
    );
  }

  /// Parse master-list payloads from OBDX — map, bare array, or nested DTOs.
  static List<SecurityQuestionOption> listFromPayload(dynamic payload) {
    final list = _extractQuestionMaps(payload);
    final seen = <String>{};
    final out = <SecurityQuestionOption>[];
    for (final map in list) {
      final option = SecurityQuestionOption.fromJson(map);
      if (option.id.isEmpty || option.text.isEmpty || !seen.add(option.id)) {
        continue;
      }
      // Skip group shells that only expose a numeric group id as text.
      if (option.id == option.text && !_hasQuestionText(map)) continue;
      out.add(option);
    }
    return out;
  }

  /// Outer group id from `{ "secQueList": [ { "id": "20611", "secQueMapping": … } ] }`.
  static String? extractGroupId(dynamic payload) {
    if (payload is! Map) return null;
    final body = Map<String, dynamic>.from(payload);
    for (final key in const ['secQueList', 'securityQuestionDTOList']) {
      final value = body[key];
      if (value is! List || value.isEmpty) continue;
      final first = value.first;
      if (first is! Map) continue;
      final id = first['id'] ?? first['groupId'];
      if (id == null) continue;
      final text = id.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static bool _hasQuestionText(Map<String, dynamic> map) {
    return _resolveText(map) != null;
  }

  static List<Map<String, dynamic>> _extractQuestionMaps(dynamic payload) {
    if (payload == null) return const [];

    if (payload is List) {
      return _flattenQuestionRows([
        for (final item in payload)
          if (item is Map) Map<String, dynamic>.from(item),
      ]);
    }

    if (payload is! Map) return const [];
    final body = Map<String, dynamic>.from(payload);

    for (final key in const [
      'secQueList',
      'securityQuestionDTOList',
      'securityQuestionList',
      'securityQuestions',
      'securityQuestionDTOs',
      'securityQuestion',
      'questions',
      'items',
      'list',
      'content',
      'data',
      'result',
      'dtoList',
    ]) {
      final value = body[key];
      if (value is List) {
        return _flattenQuestionRows([
          for (final item in value)
            if (item is Map) Map<String, dynamic>.from(item),
        ]);
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final expanded = _flattenQuestionRows([map]);
        if (expanded.isNotEmpty) return expanded;
      }
    }

    for (final value in body.values) {
      if (value is! List || value.isEmpty) continue;
      final maps = [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
      final expanded = _flattenQuestionRows(maps);
      if (expanded.isNotEmpty) return expanded;
    }

    return _flattenQuestionRows([body]);
  }

  /// OBDX UAT shape:
  /// `{ "secQueList": [ { "id": "20611", "secQueMapping": [ {questionId, question} ] } ] }`
  static List<Map<String, dynamic>> _flattenQuestionRows(
    List<Map<String, dynamic>> rows,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final mapping = row['secQueMapping'] ??
          row['securityQuestionMapping'] ??
          row['questions'] ??
          row['questionList'];
      if (mapping is List && mapping.isNotEmpty) {
        for (final item in mapping) {
          if (item is Map) out.add(Map<String, dynamic>.from(item));
        }
        continue;
      }

      // `{ "securityQuestion": { "id", "description" } }`
      final nested = row['securityQuestion'];
      final Map<String, dynamic> candidate;
      if (nested is Map) {
        candidate = {
          ...row,
          ...Map<String, dynamic>.from(nested),
        };
      } else {
        candidate = row;
      }

      if (_looksLikeSelectableQuestion(candidate)) {
        out.add(candidate);
      }
    }
    return out;
  }

  static bool _looksLikeSelectableQuestion(Map<String, dynamic> map) {
    // Group shells have id but no question text and embed secQueMapping.
    if (map.containsKey('secQueMapping') ||
        map.containsKey('securityQuestionMapping')) {
      return false;
    }
    final hasText = _resolveText(map) != null;
    final hasQuestionId = map['questionId'] != null ||
        map['securityQuestionId'] != null;
    final hasId = map['id'] != null;
    return hasText && (hasQuestionId || hasId);
  }

  static String? _resolveText(Map<String, dynamic> source) {
    for (final key in const [
      'question',
      'text',
      'description',
      'label',
      'securityQuestion',
      'questionText',
      'name',
      'displayName',
      'displayText',
    ]) {
      final value = source[key];
      final text = _scalarOrLocale(value);
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _scalarOrLocale(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? null : t;
    }
    if (value is num || value is bool) return value.toString();
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'en',
        'en-US',
        'en_US',
        'value',
        'text',
        'description',
        'label',
      ]) {
        final nested = map[key];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
      for (final nested in map.values) {
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
    }
    return null;
  }

  static String? _firstScalar(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}

/// Master security-question catalog returned by DigX (options + optional group).
class SecurityQuestionCatalog {
  const SecurityQuestionCatalog({
    required this.options,
    this.groupId,
  });

  final List<SecurityQuestionOption> options;
  final String? groupId;
}

class UserSecurityQuestionAnswer {
  const UserSecurityQuestionAnswer({
    required this.questionId,
    required this.answer,
    this.languageId,
  });

  final String questionId;
  final String answer;

  /// Master-list locale only — do **not** send on create (DigX rejects unknown
  /// fields with `DIGX_CO_0003` when FAIL_ON_UNKNOWN_PROPERTIES is on).
  final String? languageId;

  /// DigX create DTO field pair (plain-text answer).
  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'answer': answer,
      };

  /// DigX POST body for `/security/v1/userSecurityQuestion`.
  ///
  /// Verified against the OBDX web client capture (HTTP 201 Created):
  /// `{"userSecurityQuestionList":[{"questionId":"313","answer":"A"}, …]}`.
  /// Any other envelope (bare array, `secQueList`, `…DTOList`) is rejected
  /// with `DIGX_CO_0003`.
  static Map<String, dynamic> buildSubmitBody(
    List<UserSecurityQuestionAnswer> answers,
  ) {
    return {
      'userSecurityQuestionList': [
        for (final a in answers) a.toJson(),
      ],
    };
  }
}
