import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/common/forgot_credentials_pending.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/obdx_error.dart';
import 'package:ubci_bank/src/core/models/common/security_question.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_auth_api.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_credentials_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';

class ForgotCredentialsRepository {
  ForgotCredentialsRepository({
    required ObdxAuthApi authApi,
    required ObdxCredentialsApi credentialsApi,
  })  : _authApi = authApi,
        _credentialsApi = credentialsApi;

  final ObdxAuthApi _authApi;
  final ObdxCredentialsApi _credentialsApi;

  ForgotCredentialsPending? _pending;

  ForgotCredentialsPending? get pending => _pending;

  Future<ResponseHandler<ForgotCredentialsFlowResult>> startForgotUsername({
    required String emailId,
    required String dateOfBirth,
  }) async {
    await clear();
    final bootstrap = await _ensureAnonymousSession();
    if (bootstrap is! Success<void>) {
      return _mapFailure(bootstrap);
    }

    final result = await _credentialsApi.forgotUserId(
      emailId: emailId,
      dateOfBirth: dateOfBirth,
    );
    return _interpretStart(
      result,
      kind: ForgotCredentialsKind.username,
      dateOfBirth: dateOfBirth,
      emailId: emailId,
    );
  }

  Future<ResponseHandler<ForgotCredentialsFlowResult>> startForgotPassword({
    required String userId,
    required String dateOfBirth,
  }) async {
    await clear();
    final bootstrap = await _ensureAnonymousSession();
    if (bootstrap is! Success<void>) {
      return _mapFailure(bootstrap);
    }

    final result = await _credentialsApi.forgotCredentials(
      userId: userId,
      dateOfBirth: dateOfBirth,
    );
    return _interpretStart(
      result,
      kind: ForgotCredentialsKind.password,
      dateOfBirth: dateOfBirth,
      userId: userId,
    );
  }

  Future<ResponseHandler<ForgotCredentialsFlowResult>> submitOtp({
    required String otp,
  }) async {
    final pending = _pending;
    if (pending == null) {
      return ResponseHandler.exceptionError();
    }

    if (RegistrationSessionHolder.instance.anonymousAuth == null) {
      final bootstrap = await _ensureAnonymousSession();
      if (bootstrap is! Success<void>) {
        return _mapFailure(bootstrap);
      }
    }

    final header = pending.challenge.toChallengeResponseHeader(otp);
    return _submitChallengeResponse(
      pending,
      challengeResponseHeader: header,
      securityQuestionSubmit: false,
    );
  }

  /// Submit `SEC_QUE` answers via the same forgot endpoint + `X-Challenge_response`.
  Future<ResponseHandler<ForgotCredentialsFlowResult>> submitSecurityAnswers({
    required List<({String questionId, String answer})> answers,
  }) async {
    final pending = _pending;
    if (pending == null) {
      return ResponseHandler.exceptionError();
    }

    if (RegistrationSessionHolder.instance.anonymousAuth == null) {
      final bootstrap = await _ensureAnonymousSession();
      if (bootstrap is! Success<void>) {
        return _mapFailure(bootstrap);
      }
    }

    final header =
        pending.challenge.toSecurityQuestionChallengeResponseHeader(answers);
    return _submitChallengeResponse(
      pending,
      challengeResponseHeader: header,
      securityQuestionSubmit: true,
    );
  }

  Future<ResponseHandler<ForgotCredentialsFlowResult>> _submitChallengeResponse(
    ForgotCredentialsPending pending, {
    required String challengeResponseHeader,
    required bool securityQuestionSubmit,
  }) async {
    final result = switch (pending.kind) {
      ForgotCredentialsKind.username => await _credentialsApi.forgotUserId(
          emailId: pending.emailId ?? '',
          dateOfBirth: pending.dateOfBirth,
          challengeResponseHeader: challengeResponseHeader,
        ),
      ForgotCredentialsKind.password => await _credentialsApi.forgotCredentials(
          userId: pending.userId ?? '',
          dateOfBirth: pending.dateOfBirth,
          challengeResponseHeader: challengeResponseHeader,
        ),
    };

    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return _mapFailure(result);
    }

    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final headers = wrapped['headers'];
    final body = ObdxApiUtils.asMap(wrapped['body']);
    final rawBody = wrapped['body'] ?? wrapped['rawBody'];

    // Challenge already sent in X-Challenge_response. Another HTTP 417
    // (DIGX_AUTH_0003 INFO re-challenge, or DIGX_TFA_* ERROR) is a failed
    // submit — never Success(otp/secQue required), or the UI silently resets.
    if (statusCode == ApiConst.expectationFailed ||
        ObdxApiUtils.hasErrorMessage(body)) {
      final updated = _resolveChallenge(headers, body);
      if (updated != null) {
        pending.updateChallenge(updated);
        if (updated.isSecurityQuestionChallenge &&
            updated.questionIds.isNotEmpty) {
          final questions = await _loadSecurityQuestions(updated.questionIds);
          if (questions != null) {
            pending.updateSecurityQuestions(questions);
          }
        }
      }
      // OTP: fromProfileResponse remaps 417 + DIGX_AUTH_0003 → invalid OTP.
      // SEC_QUE: DIGX_AUTH_0003 INFO is a wrong-answers re-challenge — not
      // password-expired / OTP-invalid.
      if (securityQuestionSubmit &&
          statusCode == ApiConst.expectationFailed) {
        final parsed =
            ObdxErrorMapper.fromChallengeResponse(statusCode, rawBody);
        final code = parsed.obdxCode;
        final key = parsed.l10nKey;
        if (code == 'DIGX_AUTH_0003' ||
            key == 'errorPasswordExpired' ||
            key == 'errorOtpInvalid') {
          return ResponseHandler.error(
            statusCode,
            'One or more answers are incorrect. Please try again.',
            obdxError: ObdxError(
              category: ObdxErrorCategory.validation,
              l10nKey: 'errorSecurityAnswersInvalid',
              userMessage:
                  'One or more answers are incorrect. Please try again.',
              detail: parsed.detail,
              httpStatusCode: statusCode,
              obdxCode: code,
              requestId: parsed.requestId,
            ),
          );
        }
        return ResponseHandler.error(
          parsed.httpStatusCode ?? statusCode,
          parsed.userMessage,
          obdxError: parsed,
        );
      }

      final obdxError = statusCode == ApiConst.expectationFailed
          ? ObdxErrorMapper.fromProfileResponse(statusCode, rawBody)
          : ObdxErrorMapper.fromChallengeResponse(
              statusCode == 0 ? StatusCode.BAD_REQUEST : statusCode,
              rawBody,
            );
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    // After challenge response, HTTP 200 without ERROR = done.
    // Bodies seen on digx-ui:
    // - forgot password: {"tokenValid":false}
    // - forgot username: status.result SUCCESSFUL (may still echo referenceNumber)
    if (statusCode == StatusCode.OK) {
      await clear();
      return ResponseHandler.success(
        const ForgotCredentialsFlowResult.complete(),
      );
    }

    final obdxError = ObdxErrorMapper.fromChallengeResponse(
      statusCode == 0 ? StatusCode.BAD_REQUEST : statusCode,
      rawBody,
    );
    return ResponseHandler.error(
      obdxError.httpStatusCode ?? statusCode,
      obdxError.userMessage,
      obdxError: obdxError,
    );
  }

  /// Resend forgot OTP — same digx-ui endpoint as login:
  /// `POST /digx-admin/security/v1/2fa/{referenceNo}/resend` (anonymous JWT).
  Future<ResponseHandler<void>> resendOtp() async {
    final pending = _pending;
    if (pending == null) {
      return ResponseHandler.exceptionError();
    }

    final referenceNo = pending.challenge.referenceNo.trim();
    if (referenceNo.isEmpty) {
      return ResponseHandler.exceptionError();
    }

    if (RegistrationSessionHolder.instance.anonymousAuth == null) {
      final bootstrap = await _ensureAnonymousSession();
      if (bootstrap is! Success<void>) {
        return _mapFailure(bootstrap);
      }
    }

    final result = await _authApi.resendTwoFactorOtp(referenceNo: referenceNo);
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return _mapFailure(result);
    }

    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final headers = wrapped['headers'];
    final body = ObdxApiUtils.asMap(wrapped['body']);
    final rawBody = wrapped['body'] ?? wrapped['rawBody'];

    if (statusCode != StatusCode.OK ||
        ObdxApiUtils.hasErrorMessage(body) ||
        !ObdxApiUtils.isSuccessfulPayload(body)) {
      final obdxError = ObdxErrorMapper.fromChallengeResponse(
        statusCode == 0 ? StatusCode.BAD_REQUEST : statusCode,
        rawBody,
      );
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    final updated = ObdxChallenge.fromResponseHeaders(headers);
    if (updated != null && updated.referenceNo.isNotEmpty) {
      pending.updateChallenge(updated);
    }

    return ResponseHandler.success(null);
  }

  Future<void> clear() async {
    _pending = null;
    RegistrationSessionHolder.instance.clear();
  }

  Future<ResponseHandler<ForgotCredentialsFlowResult>> _interpretStart(
    ResponseHandler<Map<String, dynamic>> result, {
    required ForgotCredentialsKind kind,
    required String dateOfBirth,
    String? emailId,
    String? userId,
  }) async {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      await clear();
      return _mapFailure(result);
    }

    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final headers = wrapped['headers'];
    final body = ObdxApiUtils.asMap(wrapped['body']);
    final rawBody = wrapped['body'] ?? wrapped['rawBody'];

    if (ObdxApiUtils.hasErrorMessage(body)) {
      await clear();
      final obdxError = ObdxErrorMapper.fromChallengeResponse(
        statusCode == 0 ? StatusCode.BAD_REQUEST : statusCode,
        rawBody,
      );
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    // Prefer X-Challenge when present; else status.referenceNumber (forgotUserId
    // 200 SUCCESSFUL + INFO + apiType sms).
    final challenge = _resolveChallenge(headers, body);
    if (challenge != null &&
        (statusCode == ApiConst.expectationFailed ||
            statusCode == StatusCode.OK)) {
      if (challenge.isSecurityQuestionChallenge) {
        return _securityQuestionsRequired(
          kind: kind,
          dateOfBirth: dateOfBirth,
          emailId: emailId,
          userId: userId,
          challenge: challenge,
        );
      }

      return _otpRequired(
        kind: kind,
        dateOfBirth: dateOfBirth,
        emailId: emailId,
        userId: userId,
        challenge: challenge,
      );
    }

    if (statusCode == StatusCode.OK && ObdxApiUtils.isSuccessfulPayload(body)) {
      await clear();
      return ResponseHandler.success(
        const ForgotCredentialsFlowResult.complete(),
      );
    }

    await clear();
    final obdxError = ObdxErrorMapper.fromChallengeResponse(
      statusCode == 0 ? StatusCode.BAD_REQUEST : statusCode,
      rawBody,
    );
    return ResponseHandler.error(
      obdxError.httpStatusCode ?? statusCode,
      obdxError.userMessage,
      obdxError: obdxError,
    );
  }

  Future<ResponseHandler<void>> _ensureAnonymousSession() async {
    try {
      await _authApi.initSession();
      final tokenResult = await _authApi.getAnonymousToken();
      if (tokenResult is! Success<Map<String, dynamic>>) {
        return _mapFailure(tokenResult);
      }
      return ResponseHandler.success(null);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  ResponseHandler<ForgotCredentialsFlowResult> _otpRequired({
    required ForgotCredentialsKind kind,
    required String dateOfBirth,
    required ObdxChallenge challenge,
    String? emailId,
    String? userId,
  }) {
    final pending = ForgotCredentialsPending(
      kind: kind,
      dateOfBirth: dateOfBirth,
      emailId: emailId,
      userId: userId,
      challenge: challenge,
    );
    _pending = pending;
    return ResponseHandler.success(
      ForgotCredentialsFlowResult.otpRequired(pending),
    );
  }

  Future<ResponseHandler<ForgotCredentialsFlowResult>>
      _securityQuestionsRequired({
    required ForgotCredentialsKind kind,
    required String dateOfBirth,
    required ObdxChallenge challenge,
    String? emailId,
    String? userId,
  }) async {
    if (challenge.questionIds.isEmpty) {
      await clear();
      return ResponseHandler.exceptionError();
    }

    final questions = await _loadSecurityQuestions(challenge.questionIds);
    if (questions == null || questions.isEmpty) {
      await clear();
      return ResponseHandler.exceptionError();
    }

    final pending = ForgotCredentialsPending(
      kind: kind,
      dateOfBirth: dateOfBirth,
      emailId: emailId,
      userId: userId,
      challenge: challenge,
      securityQuestions: questions,
    );
    _pending = pending;
    return ResponseHandler.success(
      ForgotCredentialsFlowResult.securityQuestionsRequired(pending),
    );
  }

  /// Fetch master question text for each challenge id (order preserved).
  Future<List<SecurityQuestionOption>?> _loadSecurityQuestions(
    List<String> questionIds,
  ) async {
    final results = await Future.wait([
      for (final id in questionIds)
        _credentialsApi.fetchSecurityQuestionById(id),
    ]);

    final out = <SecurityQuestionOption>[];
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      if (result is! Success<Map<String, dynamic>> || result.data == null) {
        return null;
      }
      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final body = wrapped['body'] ?? wrapped['rawBody'];
      if (statusCode != StatusCode.OK) return null;
      final option = SecurityQuestionOption.fromQuestionByIdPayload(body);
      if (option == null) {
        // Fall back to id-only label if DTO shape differs.
        out.add(SecurityQuestionOption(id: questionIds[i], text: questionIds[i]));
        continue;
      }
      out.add(option);
    }
    return out;
  }

  /// Prefer non-empty `X-Challenge.referenceNo`; fall back to status.referenceNumber.
  ObdxChallenge? _resolveChallenge(dynamic headers, Map<String, dynamic> body) {
    final fromHeader = ObdxChallenge.fromResponseHeaders(headers);
    if (fromHeader != null && fromHeader.referenceNo.isNotEmpty) {
      return fromHeader;
    }

    final reference = ObdxApiUtils.smsOtpChallengeReference(body);
    if (reference == null) return null;

    return ObdxChallenge(
      authType: fromHeader?.authType ?? 'OTP',
      referenceNo: reference,
      attemptsLeft: fromHeader?.attemptsLeft,
      resendsLeft: fromHeader?.resendsLeft,
      scope: fromHeader?.scope,
      questionIds: fromHeader?.questionIds ?? const [],
    );
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
}
