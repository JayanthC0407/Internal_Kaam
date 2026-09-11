import 'dart:convert';

import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/constants/adlog.dart';
import 'package:ubci_bank/src/core/models/lfw_party_profile.dart';
import 'package:ubci_bank/src/core/models/lfw_progress.dart';
import 'package:ubci_bank/src/core/models/security_question.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_login_wizard_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// First-time Login Flow Wizard orchestration.
///
/// Does not participate in password/OTP login — only runs after a valid session
/// when navigating to home.
class LoginWizardRepository {
  LoginWizardRepository({required ObdxLoginWizardApi api}) : _api = api;

  final ObdxLoginWizardApi _api;

  /// Decide whether home is allowed or LFW must run.
  ///
  /// Primary signal: `GET /sms/v1/loginFlow` pending enabled steps.
  /// Secondary signal: dashboard modules **428** / `DIGX_CMN_0096`.
  Future<LfwGateResult> checkGate() async {
    final progressResult = await fetchProgress();
    LfwProgress? progress;
    if (progressResult is Success<LfwProgress> && progressResult.data != null) {
      progress = progressResult.data!;
      adLog(
        'LFW gate: progress status=${progress.status} '
        'steps=${progress.steps.length} pending=${progress.pendingSteps.length}',
      );
      if (progress.pendingSteps.isNotEmpty) {
        adLog('LFW gate: REQUIRED (pending loginFlow steps)');
        return LfwGateRequired(progress);
      }
      if (progress.isCompleted) {
        adLog('LFW gate: ALLOWED (loginFlow completed)');
        return const LfwGateAllowed();
      }
      // Steps present but none pending and not marked completed — allow home.
      if (progress.steps.isNotEmpty) {
        adLog('LFW gate: ALLOWED (no pending enabled steps)');
        return const LfwGateAllowed();
      }
    } else {
      adLog(
        'LFW gate: loginFlow progress unavailable '
        '(${progressResult.runtimeType}) — probing modules',
      );
    }

    final modules = await _api.fetchDashboardModules();
    if (modules is! Success<Map<String, dynamic>> || modules.data == null) {
      adLog('LFW gate: modules probe failed — ALLOWED (fail open)');
      return const LfwGateAllowed();
    }

    final wrapped = modules.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);
    final obdx = ObdxErrorMapper.fromHttpResponse(statusCode, body);
    final code = (obdx.obdxCode ?? _extractCode(body))?.toUpperCase();

    adLog('LFW gate: modules status=$statusCode code=${code ?? '-'}');

    final isLfwRequired = statusCode == ApiConst.preconditionRequired ||
        code == ApiConst.firstTimeLoginFlowNotCompleted;

    if (isLfwRequired) {
      adLog('LFW gate: REQUIRED (modules 428 / DIGX_CMN_0096)');
      if (progress != null && progress.pendingSteps.isNotEmpty) {
        return LfwGateRequired(progress);
      }
      // Re-fetch progress once more in case first call raced.
      final retry = await fetchProgress();
      if (retry is Success<LfwProgress> &&
          retry.data != null &&
          retry.data!.pendingSteps.isNotEmpty) {
        return LfwGateRequired(retry.data!);
      }
      return LfwGateRequired(
        progress ?? const LfwProgress(status: 'NOTSTARTED', steps: []),
      );
    }

    adLog('LFW gate: ALLOWED');
    return const LfwGateAllowed();
  }

  Future<ResponseHandler<LfwProgress>> fetchProgress() async {
    // Docs: fetch factory LFW step definitions, then this user's loginFlow.
    final wizardResult = await _api.fetchWizardSteps();
    final flowResult = await _api.fetchLoginFlow();

    List<LfwStepProgress> definitions = const [];
    if (wizardResult is Success<Map<String, dynamic>> &&
        wizardResult.data != null) {
      final wrapped = wizardResult.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final payload = _decodePayload(wrapped);
      final map = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};
      if (_isSuccessStatus(statusCode) && !ObdxApiUtils.hasErrorMessage(map)) {
        definitions = LfwProgress.wizardDefinitionsFromJson(map);
        adLog(
          'LFW wizard steps: ${definitions.length} definitions '
          '(${definitions.map((d) => d.wizardStepId).join(',')})',
        );
      } else {
        adLog('LFW wizard steps: unavailable status=$statusCode');
      }
    }

    final parsed = await _parseBody(
      flowResult,
      (body) => LfwProgress.fromJson(body),
    );
    if (parsed is! Success<LfwProgress> || parsed.data == null) {
      return parsed;
    }

    var progress = parsed.data!;
    if (definitions.isNotEmpty) {
      progress = progress.mergeWizardDefinitions(definitions);
    }
    adLog(
      'LFW progress: status=${progress.status} '
      'steps=${progress.steps.map((s) => '${s.wizardStepId}:${s.completed ? 'done' : 'pending'}').join(',')} '
      'pending=${progress.pendingSteps.length}',
    );
    final hasTerms = progress.steps.any(
      (s) => s.kind == LfwStepKind.termsAndConditions,
    );
    if (!hasTerms) {
      adLog(
        'LFW progress: Terms (001) not in merged steps — '
        'check wizard enablement / loginFlow',
      );
    }
    return ResponseHandler.success(progress, code: parsed.code);
  }

  Future<ResponseHandler<void>> completeStep(LfwStepProgress step) async {
    if (step.id.isEmpty) {
      return ResponseHandler.error(
        StatusCode.BAD_REQUEST,
        'Missing login flow step id.',
      );
    }
    final result = await _api.completeLoginFlowStep(
      stepId: step.id,
      body: step.toCompletePayload(),
    );
    return _parseVoid(result);
  }

  Future<ResponseHandler<int>> fetchRequiredQuestionCount() async {
    final result = await _api.fetchSecurityQuestionCount();
    return _parsePayload(result, (payload) {
      if (payload is num) return payload.toInt();
      if (payload is String) return int.tryParse(payload.trim()) ?? 5;
      if (payload is! Map) return 5;
      final body = Map<String, dynamic>.from(payload);
      final direct = body['noOfQuestions'] ??
          body['numberOfQuestions'] ??
          body['count'] ??
          body['value'];
      if (direct is num) return direct.toInt();
      if (direct is String) return int.tryParse(direct) ?? 5;
      for (final value in body.values) {
        if (value is num) return value.toInt();
        if (value is Map) {
          final nested = value['noOfQuestions'] ?? value['value'];
          if (nested is num) return nested.toInt();
        }
      }
      return 5;
    });
  }

  Future<ResponseHandler<SecurityQuestionCatalog>>
      fetchMasterSecurityQuestions() async {
    final result = await _api.fetchSecurityQuestions();
    return _parsePayload(result, (payload) {
      final options = SecurityQuestionOption.listFromPayload(payload);
      final groupId = SecurityQuestionOption.extractGroupId(payload);
      adLog(
        'LFW security questions: parsed ${options.length} options'
        '${groupId != null ? ' groupId=$groupId' : ''}',
      );
      return SecurityQuestionCatalog(options: options, groupId: groupId);
    });
  }

  Future<ResponseHandler<void>> submitSecurityQuestions(
    List<UserSecurityQuestionAnswer> answers,
  ) async {
    final result = await _api.submitUserSecurityQuestions(
      UserSecurityQuestionAnswer.buildSubmitBody(answers),
    );
    return _parseVoid(result);
  }

  Future<ResponseHandler<LfwPartyProfile>> fetchPartyProfile() async {
    final result = await _api.fetchParty();
    return _parseBody(result, LfwPartyProfile.fromPayload);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchProfileConfig() async {
    final result = await _api.fetchProfileConfig();
    return _parseBody(result, (body) => body);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchLimitsSnapshot() async {
    // Parallel-friendly sequential loads — keep simple and resilient.
    final access = await _api.fetchAccessPoints();
    final package = await _api.fetchLimitPackageConfig();
    final party = await _api.fetchPartyLimits();
    final daily = await _api.fetchLimitUtilization(period: 'PER#DAILY');
    final monthly = await _api.fetchLimitUtilization(period: 'PER#MONTHLY');
    final custom = await _api.fetchCustomLimits();
    final taskGroups = await _api.fetchLimitTaskGroups();
    final resourceTasks = await _api.fetchLimitResourceTasks();

    // Limits review is informational — prefer partial data over hard failure
    // so Channel / Transactions selectors can still render.
    return ResponseHandler.success({
      'accessPoints': _bodyMapOf(access),
      'limitPackage': _bodyMapOf(package),
      'partyLimits': _bodyMapOf(party),
      'dailyUtilization': _bodyMapOf(daily),
      'monthlyUtilization': _bodyMapOf(monthly),
      'customLimits': _bodyMapOf(custom),
      'taskGroups': _bodyMapOf(taskGroups),
      'resourceTasks': _bodyMapOf(resourceTasks),
    });
  }

  /// Decoded payload of an optional call — `{}` on any transport/API error.
  Map<String, dynamic> _bodyMapOf(ResponseHandler<Map<String, dynamic>> r) {
    if (r is! Success<Map<String, dynamic>> || r.data == null) return {};
    final wrapped = r.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final decoded = _decodePayload(wrapped);
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : decoded is List
            ? <String, dynamic>{'items': decoded}
            : <String, dynamic>{};
    if (!_isSuccessStatus(statusCode) || ObdxApiUtils.hasErrorMessage(map)) {
      return {};
    }
    return map;
  }

  /// Decode OBDX body that may be a Map, bare List, or scalar (via rawBody).
  ///
  /// [ObdxApiUtils.asMap] collapses JSON arrays to `{}`, which emptied the
  /// security-question master list — always fall back to [rawBody].
  dynamic _decodePayload(Map<String, dynamic> wrapped) {
    final body = wrapped['body'];
    if (body is List) return body;
    if (body is Map && body.isNotEmpty) return body;
    if (body is num || body is bool) return body;

    final raw = wrapped['rawBody'];
    if (raw is List || raw is Map || raw is num || raw is bool) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return raw.trim();
      }
    }
    if (body is Map) return body;
    return const <String, dynamic>{};
  }

  static bool _isSuccessStatus(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  Future<ResponseHandler<T>> _parsePayload<T>(
    ResponseHandler<Map<String, dynamic>> result,
    T Function(dynamic payload) parse,
  ) async {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return _mapFailure(result);
    }
    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final payload = _decodePayload(wrapped);
    final mapForErrors = payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};

    // Security-question create answers **201 Created**, so accept any 2xx.
    if (!_isSuccessStatus(statusCode) ||
        ObdxApiUtils.hasErrorMessage(mapForErrors)) {
      final obdx = ObdxErrorMapper.fromHttpResponse(statusCode, mapForErrors);
      return ResponseHandler.error(
        obdx.httpStatusCode ?? statusCode,
        obdx.userMessage,
        obdxError: obdx,
      );
    }

    try {
      return ResponseHandler.success(parse(payload), code: statusCode);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<T>> _parseBody<T>(
    ResponseHandler<Map<String, dynamic>> result,
    T Function(Map<String, dynamic> body) parse,
  ) async {
    return _parsePayload(result, (payload) {
      final body = payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{};
      return parse(body);
    });
  }

  Future<ResponseHandler<void>> _parseVoid(
    ResponseHandler<Map<String, dynamic>> result,
  ) async {
    final parsed = await _parseBody<Object?>(result, (_) => null);
    if (parsed is Success<Object?>) {
      return ResponseHandler.success(null, code: parsed.code);
    }
    return _mapFailure(parsed);
  }

  ResponseHandler<T> _mapFailure<T>(ResponseHandler<dynamic> result) {
    if (result is Error) {
      return ResponseHandler.error(
        result.code,
        result.error,
        requestId: result.requestId,
        obdxError: result.obdxError,
      );
    }
    if (result is NetworkError) {
      return ResponseHandler.networkError(obdxError: result.obdxError);
    }
    return ResponseHandler.exceptionError();
  }

  String? _extractCode(Map<String, dynamic> body) {
    return ObdxErrorMapper.fromHttpResponse(null, body).obdxCode;
  }
}