import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/config/session_config.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_auth_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_user_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/pref/pref_const.dart';
import 'package:ubci_bank/src/infra/pref/secure_storage_service.dart';
import 'package:ubci_bank/src/infra/security/biometric_unlock_policy.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/infra/security/secure_device_id_service.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home_dashboard_screen.dart';

/// Manages authenticated session lifecycle, idle timeout, and sign-out.
class SessionManager {
  SessionManager(
    this._preferenceHelper, {
    ObdxAuthApi? authApi,
    ObdxUserApi? userApi,
  })  : _authApi = authApi,
        _userApi = userApi;

  final PreferenceHelper _preferenceHelper;
  final ObdxAuthApi? _authApi;
  final ObdxUserApi? _userApi;
  final SecureStorageService _secure = SecureStorageService.instance;

  Future<bool> isAuthenticated() async {
    final auth = await _preferenceHelper.getAuthorization();
    if (auth == null || auth.accessToken.isEmpty) return false;

    // Anonymous registration tokens must not count as logged in.
    if (RegistrationSessionHolder.instance.anonymousAuth != null) {
      return false;
    }

    // Completed login always records activity via [onLoginSuccess].
    final lastActivity = await _secure.read(PrefConst.lastSessionActivityAt);
    return lastActivity != null && lastActivity.isNotEmpty;
  }

  Future<bool> isSessionExpired() async {
    if (!SessionConfig.isIdleTimeoutEnabled) return false;

    final raw = await _secure.read(PrefConst.lastSessionActivityAt);
    if (raw == null || raw.isEmpty) return true;

    final lastActivity = DateTime.tryParse(raw);
    if (lastActivity == null) return true;

    return DateTime.now().difference(lastActivity) > SessionConfig.idleTimeout;
  }

  Future<void> recordActivity() async {
    // Require a real user JWT, but do not require lastSessionActivityAt —
    // that would block the first write after login (chicken-and-egg).
    final auth = await _preferenceHelper.getAuthorization();
    if (auth == null || auth.accessToken.isEmpty) return;
    if (RegistrationSessionHolder.instance.anonymousAuth != null) return;
    await _touchActivity();
  }

  Future<void> onLoginSuccess({
    required String userName,
    String? displayName,
  }) async {
    await _secure.write(PrefConst.lastUserName, userName);
    if (displayName != null && displayName.trim().isNotEmpty) {
      await _secure.write(PrefConst.lastDisplayName, displayName.trim());
    }
    // Always stamp activity on login — do not go through [isAuthenticated].
    await _touchActivity();
  }

  Future<void> _touchActivity() async {
    await _secure.write(
      PrefConst.lastSessionActivityAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Rebuilds [HomeDashboardArgs] for a *restored* session — splash resolving
  /// an already-authenticated user (app relaunch, browser back/refresh
  /// landing back on splash, biometric unlock), as opposed to a fresh login
  /// where the real `login`/`me` trace is already in hand.
  ///
  /// Login itself never loses `profileResponse` — see [LoginTrace] and its
  /// callers in `auth_repository.dart`. The bug this guards against is
  /// specific to *restoring* a session without repeating login: this used to
  /// return `loginTrace` with only `displayName`, so
  /// `session_activity_scope.dart`'s dashboard resolver had no
  /// `dashboardResponse` to read and silently fell back to the Retail
  /// dashboard — even for a corporate user (e.g. browser Back → splash →
  /// re-enter home). Re-fetching `me` here restores the same
  /// `dashboardClassValue` data a fresh login would have provided, per the
  /// API Flow & Implementation doc §6/§19-20.
  Future<HomeDashboardArgs> buildHomeArgs() async {
    final userName =
        await _secure.read(PrefConst.lastUserName) ?? 'User';
    final displayName = await _secure.read(PrefConst.lastDisplayName);

    final profileResponse = await _fetchProfileForRestore();

    final loginTrace = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (profileResponse != null) 'profileResponse': profileResponse,
    };

    return HomeDashboardArgs(
      userName: userName,
      loginTrace: loginTrace.isEmpty ? null : loginTrace,
    );
  }

  /// Best-effort `me` refresh for [buildHomeArgs]. Returns `null` (never
  /// throws) on any failure — callers must keep working the way they always
  /// did when `profileResponse` is unavailable (falls back to Retail; see
  /// `_resolveDashboard` in `session_activity_scope.dart`), just without
  /// silently mis-resolving a corporate user because of a stale/missing
  /// trace.
  Future<Map<String, dynamic>?> _fetchProfileForRestore() async {
    final api = _userApi;
    if (api == null) return null;
    try {
      final result = await api.fetchProfile();
      if (result is! Success<Map<String, dynamic>> || result.data == null) {
        return null;
      }
      final profileResponse = result.data!;
      if (profileResponse['statusCode'] != StatusCode.OK) return null;
      return profileResponse;
    } catch (_) {
      return null;
    }
  }

  /// Returns [RoutesConst.homeScreen], [RoutesConst.biometricUnlockScreen], or [RoutesConst.loginScreen].
  Future<String> resolveInitialRoute({
    PreferenceHelper? preferences,
    BiometricService? biometrics,
  }) async {
    final prefs = preferences ?? _preferenceHelper;
    final bio = biometrics ?? BiometricService();

    var authenticated = await isAuthenticated();

    // "Keep me signed in" off → drop restored session; biometric cold start still allowed.
    if (authenticated && !await prefs.isKeepSignedIn()) {
      await _preferenceHelper.clearSession();
      await _secure.delete(PrefConst.lastSessionActivityAt);
      authenticated = false;
    }

    if (!authenticated) {
      RegistrationSessionHolder.instance.clear();
      final auth = await _preferenceHelper.getAuthorization();
      if (auth != null && auth.accessToken.isNotEmpty) {
        await _preferenceHelper.clearSession();
      }

      if (await BiometricUnlockPolicy.shouldShowColdStartBiometricLogin(
        session: this,
        preferences: prefs,
        biometrics: bio,
      )) {
        return RoutesConst.biometricUnlockScreen;
      }
      return RoutesConst.loginScreen;
    }

    if (await isSessionExpired()) {
      await _preferenceHelper.clearSession();
      await _secure.delete(PrefConst.lastSessionActivityAt);

      if (await BiometricUnlockPolicy.shouldShowColdStartBiometricLogin(
        session: this,
        preferences: prefs,
        biometrics: bio,
      )) {
        return RoutesConst.biometricUnlockScreen;
      }
      return RoutesConst.loginScreen;
    }

    await recordActivity();
    return RoutesConst.homeScreen;
  }

  /// Clears auth session; keeps biometric quick-access for the next login.
  ///
  /// Calls OBDX `POST .../logout` first (best-effort) while JWT/cookies are
  /// still available, then always performs the local wipe.
  Future<void> logout() async {
    await _invalidateServerSessionBestEffort();
    RegistrationSessionHolder.instance.clear();
    await _preferenceHelper.clearSession();
    await _preferenceHelper.clearPendingBiometricEnrollment();
    await _secure.delete(PrefConst.lastSessionActivityAt);
    await _secure.delete(PrefConst.lastDisplayName);
  }

  /// Full local wipe — user must sign in again; biometrics and device id removed.
  Future<void> forgetDevice() async {
    await logout();
    await _preferenceHelper.clearBiometricSecrets();
    await SecureDeviceIdService.instance.clear();
    await _secure.delete(PrefConst.lastUserName);
  }

  Future<String?> getLastUserName() =>
      _secure.read(PrefConst.lastUserName);

  /// Best-effort server logout; never blocks local sign-out on failure.
  Future<void> _invalidateServerSessionBestEffort() async {
    final api = _authApi;
    if (api == null) return;

    final auth = await _preferenceHelper.getAuthorization();
    if (auth == null || auth.accessToken.isEmpty) return;

    try {
      await api.logout();
    } catch (_) {
      // Network / server errors must not prevent local logout.
    }
  }
}
