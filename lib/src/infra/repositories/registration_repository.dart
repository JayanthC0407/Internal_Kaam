import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/account_type_option.dart';
import 'package:ubci_bank/src/core/models/registration_flow_result.dart';
import 'package:ubci_bank/src/core/models/registration_request.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_auth_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_registration_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';

class RegistrationRepository {
  RegistrationRepository({
    required ObdxAuthApi authApi,
    required ObdxRegistrationApi registrationApi,
  })  : _authApi = authApi,
        _registrationApi = registrationApi;

  final ObdxAuthApi _authApi;
  final ObdxRegistrationApi _registrationApi;

  RegistrationRequest? _pendingRequest;
  String? _registrationId;

  String? get activeRegistrationId => _registrationId;

  Future<ResponseHandler<List<AccountTypeOption>>> loadAccountTypes() async {
    final bootstrap = await _ensureAnonymousSession();
    if (bootstrap is! Success<void>) {
      return _mapFailure(bootstrap);
    }
    return _registrationApi.fetchAccountTypes();
  }

  /// Step 1 — party/account lookup; returns `registrationId` + attempts.
  Future<ResponseHandler<RegistrationStartResult>> startRegistration({
    required RegistrationRequest request,
  }) async {
    await _clearRegistrationState();

    try {
      await _authApi.initSession();

      final tokenResult = await _authApi.getAnonymousToken();
      if (tokenResult is! Success<Map<String, dynamic>>) {
        return _mapFailure(tokenResult);
      }

      var registrationRequest = request;
      if (registrationRequest.accountType.isEmpty) {
        final typesResult = await _registrationApi.fetchAccountTypes();
        if (typesResult is Success<List<AccountTypeOption>> &&
            typesResult.data != null &&
            typesResult.data!.isNotEmpty) {
          registrationRequest = registrationRequest.copyWith(
            accountType: typesResult.data!.first.code,
          );
        }
      }

      final registerResult = await _registrationApi.startRegistration(
        request: registrationRequest,
      );
      if (registerResult is! Success<Map<String, dynamic>> ||
          registerResult.data == null) {
        return _mapFailure(registerResult);
      }

      final statusCode = registerResult.data!['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(registerResult.data!['body']);

      if (!_isHttpOk(statusCode) || !_isSuccessful(body)) {
        final obdxError = ObdxErrorMapper.fromHttpResponse(
          statusCode == 0 ? StatusCode.BAD_REQUEST : statusCode,
          registerResult.data!['body'] ?? registerResult.data!['rawBody'],
        );
        return ResponseHandler.error(
          obdxError.httpStatusCode ?? statusCode,
          obdxError.userMessage,
          obdxError: obdxError,
        );
      }

      final start = RegistrationStartResult.fromJson(body);
      if (start.registrationId.isEmpty) {
        return ResponseHandler.exceptionError();
      }

      _pendingRequest = registrationRequest;
      _registrationId = start.registrationId;
      return ResponseHandler.success(start);
    } catch (_) {
      await _clearRegistrationState();
      return ResponseHandler.exceptionError();
    }
  }

  /// Step 2 — verify OTP using `Token_id` header.
  ///
  /// Returns [RegistrationAuthResult] even when the code is wrong so the UI
  /// can refresh `attemptsLeft`. Callers must check [RegistrationAuthResult.isVerified].
  Future<ResponseHandler<RegistrationAuthResult>> authenticate({
    required String verificationCode,
  }) async {
    final registrationId = _registrationId;
    if (registrationId == null || registrationId.isEmpty) {
      return ResponseHandler.exceptionError();
    }

    try {
      if (RegistrationSessionHolder.instance.anonymousAuth == null) {
        final bootstrap = await _ensureAnonymousSession(preserveFlow: true);
        if (bootstrap is! Success<void>) {
          return _mapFailure(bootstrap);
        }
      }

      final authResult = await _registrationApi.authenticateRegistration(
        registrationId: registrationId,
        verificationCode: verificationCode.trim(),
      );
      if (authResult is! Success<Map<String, dynamic>> ||
          authResult.data == null) {
        return _mapFailure(authResult);
      }

      final statusCode = authResult.data!['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(authResult.data!['body']);

      if (body.isNotEmpty) {
        final parsed = RegistrationAuthResult.fromJson(body);
        if (parsed.isVerified && _isSuccessful(body)) {
          return ResponseHandler.success(parsed, code: statusCode);
        }

        // Wrong OTP with registration payload — keep attemptsLeft for the UI.
        if (parsed.registrationId.isNotEmpty ||
            body.containsKey('attemptsLeft') ||
            body.containsKey('registrationDTO')) {
          return ResponseHandler.success(parsed, code: statusCode);
        }

        final obdxError = ObdxErrorMapper.fromHttpResponse(
          statusCode == 0 ? StatusCode.BAD_REQUEST : statusCode,
          authResult.data!['body'] ?? authResult.data!['rawBody'],
        );
        return ResponseHandler.error(
          obdxError.httpStatusCode ?? statusCode,
          obdxError.userMessage,
          obdxError: obdxError,
        );
      }

      if (!_isHttpOk(statusCode)) {
        final obdxError = ObdxErrorMapper.fromHttpResponse(
          statusCode,
          authResult.data!['body'] ?? authResult.data!['rawBody'],
        );
        return ResponseHandler.error(
          obdxError.httpStatusCode ?? statusCode,
          obdxError.userMessage,
          obdxError: obdxError,
        );
      }

      return ResponseHandler.exceptionError();
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Best-effort resend: re-runs start with the same lookup payload.
  Future<ResponseHandler<RegistrationStartResult>> resendVerificationCode() async {
    final pending = _pendingRequest;
    if (pending == null) {
      return ResponseHandler.exceptionError();
    }
    return startRegistration(request: pending);
  }

  Future<void> abandon() => _clearRegistrationState();

  Future<void> _clearRegistrationState({bool keepFlow = false}) async {
    if (!keepFlow) {
      _pendingRequest = null;
      _registrationId = null;
    }
    RegistrationSessionHolder.instance.clear();
    await PreferenceHelper.getInstance().clearSession();
  }

  Future<ResponseHandler<void>> _ensureAnonymousSession({
    bool preserveFlow = false,
  }) async {
    final pending = _pendingRequest;
    final id = _registrationId;
    await _clearRegistrationState(keepFlow: preserveFlow);
    if (preserveFlow) {
      _pendingRequest = pending;
      _registrationId = id;
    }
    await _authApi.initSession();
    final tokenResult = await _authApi.getAnonymousToken();
    if (tokenResult is! Success<Map<String, dynamic>>) {
      return _mapFailure(tokenResult);
    }
    return ResponseHandler.success(null);
  }

  static bool _isHttpOk(int statusCode) {
    return statusCode == StatusCode.OK ||
        statusCode == StatusCode.CREATED ||
        statusCode == StatusCode.NO_CONTENT;
  }

  static bool _isSuccessful(Map<String, dynamic> body) {
    return ObdxApiUtils.isSuccessfulPayload(body);
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
