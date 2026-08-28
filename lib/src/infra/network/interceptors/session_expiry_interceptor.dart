import 'package:dio/dio.dart';
import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/pref/pref_const.dart';
import 'package:ubci_bank/src/infra/pref/secure_storage_service.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';

/// Clears the local session and signals the UI when OBDX rejects the JWT
/// (`401` / `DIGX_AU_035` / invalid authentication token).
///
/// Does **not** navigate — [SessionExpiryCoordinator] listeners handle routing
/// so interceptors stay free of [BuildContext].
class SessionExpiryInterceptor extends Interceptor {
  SessionExpiryInterceptor({
    PreferenceHelper? preferences,
    SessionExpiryCoordinator? coordinator,
    SecureStorageService? secureStorage,
  })  : _preferences = preferences ?? PreferenceHelper.getInstance(),
        _coordinator = coordinator ?? SessionExpiryCoordinator.instance,
        _secure = secureStorage ?? SecureStorageService.instance;

  final PreferenceHelper _preferences;
  final SessionExpiryCoordinator _coordinator;
  final SecureStorageService _secure;

  /// OBDX codes that mean the access token / session is no longer valid.
  static const invalidTokenCodes = {
    'DIGX_AU_035',
    'DIGX_AUTH_0005',
  };

  /// Pure detection — used by [onError] and unit tests.
  static bool isInvalidTokenResponse(DioException err) {
    final status = err.response?.statusCode;
    if (status != StatusCode.UNAUTHORIZED) return false;

    final path = err.requestOptions.path;
    if (ApiConst.noAuthPaths.any((p) => path.contains(p))) return false;

    final mapped = ObdxErrorMapper.fromDioException(err);
    final code = mapped.obdxCode?.toUpperCase();
    if (code != null && invalidTokenCodes.contains(code)) return true;

    final detail = (mapped.detail ?? '').toLowerCase();
    if (detail.contains('invalid authentication token') ||
        detail.contains('invalid auth token')) {
      return true;
    }
    if (detail.contains('session') && detail.contains('expired')) {
      return true;
    }

    return false;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_coordinator.isHandling && isInvalidTokenResponse(err)) {
      // Mark handling synchronously so parallel 401s do not multi-fire the UI.
      _coordinator.notifyExpired();
      // Fire-and-forget clear; do not block error propagation to repositories.
      _clearLocalSession();
    }
    handler.next(err);
  }

  Future<void> _clearLocalSession() async {
    try {
      RegistrationSessionHolder.instance.clear();
      await _preferences.clearSession();
      await _secure.delete(PrefConst.lastSessionActivityAt);
    } catch (_) {
      // Best-effort wipe; UI redirect still proceeds via the coordinator.
    }
  }
}
