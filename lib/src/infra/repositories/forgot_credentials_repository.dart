import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/forgot_credentials_pending.dart';
import 'package:ubci_bank/src/core/models/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_auth_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_credentials_api.dart';
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
    final result = switch (pending.kind) {
      ForgotCredentialsKind.username => await _credentialsApi.forgotUserId(
          emailId: pending.emailId ?? '',
          dateOfBirth: pending.dateOfBirth,
          challengeResponseHeader: header,
        ),
      ForgotCredentialsKind.password => await _credentialsApi.forgotCredentials(
          userId: pending.userId ?? '',
          dateOfBirth: pending.dateOfBirth,
          challengeResponseHeader: header,
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

    // Wrong OTP / TFA failure: HTTP 417 with message.type ERROR (e.g. DIGX_TFA_0004).
    if (ObdxApiUtils.hasErrorMessage(body)) {
      final updated = _resolveChallenge(headers, body);
      if (updated != null) {
        pending.updateChallenge(updated);
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

    if (statusCode == ApiConst.expectationFailed) {
      final challenge = _resolveChallenge(headers, body);
      if (challenge != null) {
        pending.updateChallenge(challenge);
        return ResponseHandler.success(
          ForgotCredentialsFlowResult.otpRequired(pending),
        );
      }
      final obdxError = ObdxErrorMapper.fromChallengeResponse(
        statusCode,
        rawBody,
      );
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    // After OTP was sent in X-Challenge_response, HTTP 200 without ERROR = done.
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
