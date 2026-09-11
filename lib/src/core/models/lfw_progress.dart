/// One step in the OBDX Login Flow Wizard (LFW) progress snapshot.
class LfwStepProgress {
  const LfwStepProgress({
    required this.id,
    required this.wizardStepId,
    required this.order,
    required this.mandatory,
    required this.enabled,
    required this.completed,
    this.name,
    this.module,
    this.raw,
  });

  /// Server login-flow step id used in `PUT .../loginFlow/step/{id}`.
  final String id;

  /// Factory step id (e.g. `001` terms, `002` security questions).
  final String wizardStepId;

  final int order;
  final bool mandatory;
  final bool enabled;
  final bool completed;
  final String? name;
  final String? module;

  /// Original map — forwarded on complete so OBDX receives expected fields.
  final Map<String, dynamic>? raw;

  bool get isPending => enabled && !completed;

  LfwStepKind get kind => LfwStepKind.fromWizardStepId(wizardStepId, module);

  factory LfwStepProgress.fromJson(Map<String, dynamic> json) {
    final nestedWizard = json['wizardStep'];
    final nestedWizardMap =
        nestedWizard is Map ? Map<String, dynamic>.from(nestedWizard) : null;

    final id = _firstString(json, const [
          'id',
          'loginFlowId',
          'loginFlowStepId',
          'stepId',
        ]) ??
        '';
    final wizardStepId = _firstString(json, const [
          'wizardStepId',
          'wizardStep',
          'stepCode',
          'code',
        ]) ??
        _firstString(nestedWizardMap ?? const {}, const [
          'id',
          'wizardStepId',
          'code',
          'name',
        ]) ??
        '';
    final order = _asInt(
          json['order'] ??
              json['sequence'] ??
              json['seq'] ??
              nestedWizardMap?['order'],
        ) ??
        0;
    final name = _firstString(json, const ['name', 'description', 'label']) ??
        _firstString(nestedWizardMap ?? const {}, const [
          'name',
          'description',
          'label',
        ]);
    final module = _firstString(json, const [
          'module',
          'moduleId',
          'moduleName',
          'functionalModule',
        ]) ??
        _firstString(nestedWizardMap ?? const {}, const [
          'module',
          'moduleId',
          'name',
        ]);

    return LfwStepProgress(
      id: id,
      wizardStepId: wizardStepId,
      order: order,
      mandatory: _asBool(json['mandatory'] ?? json['isMandatory']) ?? false,
      enabled: _asBool(json['enabled'] ?? json['isEnabled']) ?? true,
      completed: _asBool(json['completed'] ?? json['isCompleted']) ?? false,
      name: name,
      module: module,
      raw: Map<String, dynamic>.from(json),
    );
  }

  /// Body for `PUT .../loginFlow/step/{id}`.
  ///
  /// Mirrors the OBDX web client exactly — only these fields, no `userId` /
  /// `determinantValue` echo:
  /// `{"id":"103","order":2,"mandatory":false,"enabled":true,
  /// "wizardStepId":"002","completed":true}`
  Map<String, dynamic> toCompletePayload() {
    return {
      if (id.isNotEmpty) 'id': id,
      'order': order,
      'mandatory': mandatory,
      'enabled': enabled,
      if (wizardStepId.isNotEmpty) 'wizardStepId': wizardStepId,
      'completed': true,
    };
  }
}

/// Overall LFW status for the signed-in user.
class LfwProgress {
  const LfwProgress({
    required this.status,
    required this.steps,
  });

  final String status;
  final List<LfwStepProgress> steps;

  bool get isCompleted {
    final s = status.toUpperCase();
    if (s == 'COMPLETED' || s == 'COMPLETE') return true;
    final pendingMandatory = steps.where(
      (step) => step.enabled && step.mandatory && !step.completed,
    );
    return pendingMandatory.isEmpty &&
        steps.any((step) => step.enabled) &&
        steps.where((step) => step.enabled).every((step) => step.completed);
  }

  /// Enabled, incomplete steps sorted by server [LfwStepProgress.order].
  List<LfwStepProgress> get pendingSteps {
    final list = steps.where((s) => s.isPending).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  LfwStepProgress? get currentStep =>
      pendingSteps.isEmpty ? null : pendingSteps.first;

  /// Enabled steps in server order — includes already-completed ones (e.g. Terms).
  List<LfwStepProgress> get enabledSteps {
    final list = steps.where((s) => s.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  factory LfwProgress.fromJson(Map<String, dynamic> json) {
    // Prefer explicit flow status fields; ignore OBDX wrapper `status: {result}`.
    final status = _flowStatusOf(json);

    final rawSteps = _extractStepList(json);
    final steps = rawSteps
        .whereType<Map>()
        .map((e) => LfwStepProgress.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.id.isNotEmpty || s.wizardStepId.isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return LfwProgress(status: status, steps: steps);
  }

  /// Merge factory LFW step definitions (`GET .../wizard/v1/steps?wizardType=LFW`)
  /// with this user's `loginFlow` progress.
  ///
  /// DigX often omits already-completed steps from `loginFlow` (e.g. Terms 001
  /// disappears after accept). Wizard definitions restore the full ordered set
  /// so Terms remains visible in the flow UI as completed.
  LfwProgress mergeWizardDefinitions(List<LfwStepProgress> definitions) {
    if (definitions.isEmpty) return this;

    final byWizardId = <String, LfwStepProgress>{
      for (final s in steps)
        if (s.wizardStepId.isNotEmpty) s.wizardStepId: s,
    };

    final merged = <LfwStepProgress>[];
    for (final def in definitions) {
      if (!def.enabled && def.wizardStepId.isEmpty) continue;
      final progress = byWizardId.remove(def.wizardStepId);
      if (progress != null) {
        merged.add(
          LfwStepProgress(
            id: progress.id,
            wizardStepId: progress.wizardStepId.isNotEmpty
                ? progress.wizardStepId
                : def.wizardStepId,
            order: progress.order != 0 ? progress.order : def.order,
            mandatory: progress.mandatory || def.mandatory,
            enabled: progress.enabled,
            completed: progress.completed,
            name: (progress.name?.trim().isNotEmpty == true)
                ? progress.name
                : def.name,
            module: (progress.module?.trim().isNotEmpty == true)
                ? progress.module
                : def.module,
            raw: progress.raw ?? def.raw,
          ),
        );
      } else if (def.enabled) {
        // Present in wizard, absent from loginFlow. DigX often drops completed
        // steps (Terms after accept). Infer "done" when later steps exist or
        // the flow is already INPROGRESS/COMPLETED — never invent a pending
        // step without a loginFlow id (PUT would fail).
        final inferredDone = _inferAbsentStepCompleted(def);
        if (!inferredDone) continue;
        merged.add(
          LfwStepProgress(
            id: '',
            wizardStepId: def.wizardStepId,
            order: def.order,
            mandatory: def.mandatory,
            enabled: true,
            completed: true,
            name: def.name,
            module: def.module,
            raw: def.raw,
          ),
        );
      }
    }

    // Keep any loginFlow-only steps not listed in wizard definitions.
    merged.addAll(byWizardId.values);
    merged.sort((a, b) => a.order.compareTo(b.order));
    return LfwProgress(status: status, steps: merged);
  }

  bool _inferAbsentStepCompleted(LfwStepProgress def) {
    final s = status.toUpperCase();
    if (s == 'INPROGRESS' || s == 'COMPLETED' || s == 'COMPLETE') {
      return true;
    }
    return steps.any((step) => step.order > def.order);
  }

  /// Parse factory step definitions from wizard steps API.
  static List<LfwStepProgress> wizardDefinitionsFromJson(
    Map<String, dynamic> json,
  ) {
    final raw = _extractWizardDefinitionList(json);
    final out = <LfwStepProgress>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      // Wizard definitions use `id` as wizardStepId (001…); loginFlow step id
      // is absent until progress is created.
      final wizardStepId = _firstString(map, const [
            'wizardStepId',
            'id',
            'code',
            'stepCode',
            'name',
          ]) ??
          '';
      if (wizardStepId.isEmpty) continue;
      final order = _asInt(map['order'] ?? map['sequence'] ?? map['seq']) ??
          int.tryParse(wizardStepId) ??
          0;
      out.add(
        LfwStepProgress(
          id: '',
          wizardStepId: wizardStepId,
          order: order,
          mandatory: _asBool(map['mandatory'] ?? map['isMandatory']) ?? true,
          enabled: _asBool(map['enabled'] ?? map['isEnabled']) ?? true,
          completed: false,
          name: _firstString(map, const [
            'name',
            'description',
            'label',
            'displayName',
          ]),
          module: _firstString(map, const [
            'module',
            'moduleId',
            'moduleName',
            'functionalModule',
          ]),
          raw: map,
        ),
      );
    }
    out.sort((a, b) => a.order.compareTo(b.order));
    return out;
  }

  static List<dynamic> _extractWizardDefinitionList(Map<String, dynamic> json) {
    for (final key in const [
      'wizardSteps',
      'wizardStepDTOList',
      'steps',
      'items',
      'list',
      'data',
    ]) {
      final value = json[key];
      if (value is List) return value;
      if (value is Map) {
        final nested =
            _extractWizardDefinitionList(Map<String, dynamic>.from(value));
        if (nested.isNotEmpty) return nested;
      }
    }
    for (final value in json.values) {
      if (value is List &&
          value.isNotEmpty &&
          value.first is Map &&
          (Map<String, dynamic>.from(value.first as Map).containsKey('id') ||
              Map<String, dynamic>.from(value.first as Map)
                  .containsKey('wizardStepId'))) {
        return value;
      }
    }
    return const [];
  }

  static String _flowStatusOf(Map<String, dynamic> json) {
    for (final key in const [
      'loginFlowStatus',
      'flowStatus',
      'wizardStatus',
    ]) {
      final text = _scalarString(json[key]);
      if (text != null) return text;
    }

    final status = json['status'];
    if (status is String && status.trim().isNotEmpty) {
      final text = status.trim();
      // Ignore API envelope values like SUCCESSFUL — those are not LFW state.
      if (!_isApiEnvelopeStatus(text)) return text;
    }
    if (status is Map) {
      final map = Map<String, dynamic>.from(status);
      for (final key in const [
        'loginFlowStatus',
        'flowStatus',
        'status',
        'state',
      ]) {
        final text = _scalarString(map[key]);
        if (text != null && !_isApiEnvelopeStatus(text)) return text;
      }
    }

    // Nested loginFlow object may carry the overall status.
    for (final key in const ['loginFlow', 'loginFlowDTO', 'data']) {
      final value = json[key];
      if (value is Map) {
        final nested = _flowStatusOf(Map<String, dynamic>.from(value));
        if (nested != 'UNKNOWN') return nested;
      }
    }
    return 'UNKNOWN';
  }

  static bool _isApiEnvelopeStatus(String value) {
    final v = value.toUpperCase();
    return v == 'SUCCESSFUL' ||
        v == 'SUCCESS' ||
        v == 'FAILED' ||
        v == 'ERROR' ||
        v == 'EXPECTATION_FAILED';
  }

  static List<dynamic> _extractStepList(Map<String, dynamic> json) {
    for (final key in const [
      'loginFlow',
      'loginFlows',
      'loginFlowDTO',
      'loginFlowList',
      'loginFlowSteps',
      'steps',
      'wizardSteps',
      'items',
      'list',
      'data',
    ]) {
      final value = json[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = _extractStepList(Map<String, dynamic>.from(value));
        if (nested.isNotEmpty) return nested;
        // Single step object under a known key.
        if (value.containsKey('wizardStepId') ||
            value.containsKey('completed') ||
            value.containsKey('loginFlowId')) {
          return [value];
        }
      }
    }
    // Some payloads nest under a single wrapper object.
    for (final value in json.values) {
      if (value is Map) {
        final nested = _extractStepList(Map<String, dynamic>.from(value));
        if (nested.isNotEmpty) return nested;
      }
      if (value is List &&
          value.isNotEmpty &&
          value.first is Map &&
          (Map<String, dynamic>.from(value.first as Map)
                  .containsKey('wizardStepId') ||
              Map<String, dynamic>.from(value.first as Map)
                  .containsKey('completed'))) {
        return value;
      }
    }
    return const [];
  }
}

/// Known LFW step kinds — mapped from wizardStepId / module, not hard-coded ids.
enum LfwStepKind {
  termsAndConditions,
  securityQuestions,
  userProfile,
  transactionLimits,
  unknown;

  static LfwStepKind fromWizardStepId(String wizardStepId, String? module) {
    final id = wizardStepId.trim().toLowerCase();
    final mod = (module ?? '').trim().toLowerCase();
    final blob = '$id $mod';

    if (id == '001' ||
        id.contains('terms') ||
        mod.contains('login-configuration') ||
        mod.contains('terms') ||
        blob.contains('terms-and-conditions') ||
        blob.contains('tnc')) {
      return LfwStepKind.termsAndConditions;
    }
    if (id == '002' ||
        id.contains('security') ||
        mod.contains('security-question') ||
        mod.contains('securityquestion') ||
        blob.contains('security question') ||
        blob.contains('user-security')) {
      return LfwStepKind.securityQuestions;
    }
    if (id == '003' ||
        id.contains('profile') ||
        mod.contains('base-components') ||
        blob.contains('user-profile') ||
        blob.contains('party')) {
      return LfwStepKind.userProfile;
    }
    if (id == '004' ||
        id.contains('limit') ||
        mod.contains('limits') ||
        blob.contains('transaction-limit') ||
        blob.contains('user-limit')) {
      return LfwStepKind.transactionLimits;
    }
    return LfwStepKind.unknown;
  }
}

/// Outcome of the post-auth LFW gate check (does not alter OTP [LoginFlowResult]).
sealed class LfwGateResult {
  const LfwGateResult();
}

class LfwGateAllowed extends LfwGateResult {
  const LfwGateAllowed();
}

class LfwGateRequired extends LfwGateResult {
  const LfwGateRequired(this.progress);

  final LfwProgress progress;
}

class LfwGateError extends LfwGateResult {
  const LfwGateError(this.message, {this.obdxCode});

  final String message;
  final String? obdxCode;
}

String? _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final text = _scalarString(json[key]);
    if (text != null) return text;
  }
  return null;
}

String? _scalarString(dynamic value) {
  if (value == null) return null;
  if (value is Map || value is List) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

bool? _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == 'yes' || v == 'y' || v == '1') return true;
    if (v == 'false' || v == 'no' || v == 'n' || v == '0') return false;
  }
  return null;
}
