import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:ubci_bank/src/core/models/alternate_login_method.dart';
import 'package:ubci_bank/src/core/models/cookie_model.dart';
import 'package:ubci_bank/src/core/models/token_response.dart';
import 'package:ubci_bank/src/infra/pref/base_preferences.dart';
import 'package:ubci_bank/src/infra/pref/pref_const.dart';
import 'package:ubci_bank/src/infra/pref/secure_storage_service.dart';
import 'package:ubci_bank/src/infra/security/alternate_login_crypto.dart';

/// Persists auth session data in encrypted storage.
/// Legacy SharedPreferences session values are migrated on first launch.
class PreferenceHelper {
  PreferenceHelper._internal();

  static final PreferenceHelper _instance = PreferenceHelper._internal();

  static PreferenceHelper getInstance() => _instance;

  final SecureStorageService _secure = SecureStorageService.instance;
  final BasePreferences _legacyPrefs = BasePreferences();

  TokenResponse? _auth;
  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await _migrateLegacySessionFromSharedPreferences();
    _initialized = true;
  }

  Future<void> saveCookies(List<Cookie> cookies) async {
    await ensureInitialized();
    final existing = await getCookieModel();
    var secretKey = existing.secretKey;
    var jsessionId = existing.jsessionId;

    for (final cookie in cookies) {
      final name = cookie.name.toLowerCase();
      if (name == 'secretkey') {
        secretKey = cookie.value;
      } else if (name == 'jsessionid') {
        jsessionId = cookie.value;
      }
    }

    final cookieModel = CookieModel(
      secretKey: secretKey,
      jsessionId: jsessionId,
    ).toJson();

    await _secure.write(
      PrefConst.loggedInCookies,
      jsonEncode(cookieModel),
    );
  }

  Future<CookieModel> getCookieModel() async {
    await ensureInitialized();
    final jsonString = await _secure.read(PrefConst.loggedInCookies);
    if (jsonString == null || jsonString.isEmpty) return CookieModel();
    return CookieModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  Future<List<Cookie>> getCookies() async {
    final model = await getCookieModel();
    final cookies = <Cookie>[];

    if (model.secretKey != null && model.secretKey!.isNotEmpty) {
      cookies.add(Cookie('secretKey', model.secretKey!));
    }
    if (model.jsessionId != null && model.jsessionId!.isNotEmpty) {
      cookies.add(Cookie('JSESSIONID', model.jsessionId!));
    }
    return cookies;
  }

  Future<void> clearCookies() async {
    await ensureInitialized();
    await _secure.delete(PrefConst.loggedInCookies);
  }

  Future<void> saveAuthorization(TokenResponse auth) async {
    await ensureInitialized();
    _auth = auth;
    await _secure.write(
      PrefConst.loggedInAuthorization,
      jsonEncode(auth.toJson()),
    );
  }

  Future<TokenResponse?> getAuthorization() async {
    await ensureInitialized();
    if (_auth != null) return _auth;

    final jsonString = await _secure.read(PrefConst.loggedInAuthorization);
    if (jsonString == null || jsonString.isEmpty) return null;

    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    _auth = TokenResponse.fromJson(json);
    return _auth;
  }

  Future<void> clearAuthorization() async {
    await ensureInitialized();
    _auth = null;
    await _secure.delete(PrefConst.loggedInAuthorization);
  }

  Future<bool> isBiometricEnabled() async {
    await ensureInitialized();
    final value = await _secure.read(PrefConst.biometricEnabled);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await ensureInitialized();
    if (enabled) {
      await _secure.write(PrefConst.biometricEnabled, 'true');
    } else {
      await _secure.delete(PrefConst.biometricEnabled);
    }
  }

  Future<bool> isBiometricServerEnrolled() async {
    await ensureInitialized();
    final value = await _secure.read(PrefConst.obdxBiometricServerEnrolled);
    return value == 'true';
  }

  Future<void> setBiometricServerEnrolled(bool enrolled) async {
    await ensureInitialized();
    if (enrolled) {
      await _secure.write(PrefConst.obdxBiometricServerEnrolled, 'true');
    } else {
      await _secure.delete(PrefConst.obdxBiometricServerEnrolled);
    }
  }

  Future<String?> getBiometricSetupToken() async {
    await ensureInitialized();
    if (await isSetupTokenEncrypted()) return null;
    return _secure.read(PrefConst.obdxBiometricSetupToken);
  }

  Future<void> setBiometricSetupToken(String token) async {
    await ensureInitialized();
    await _secure.write(PrefConst.obdxBiometricSetupToken, token);
    await _secure.delete(PrefConst.obdxSetupTokenEncrypted);
  }

  Future<bool> hasBiometricSetupToken() async {
    await ensureInitialized();
    final value = await _secure.read(PrefConst.obdxBiometricSetupToken);
    return value != null && value.isNotEmpty;
  }

  Future<bool> isSetupTokenEncrypted() async {
    await ensureInitialized();
    final value = await _secure.read(PrefConst.obdxSetupTokenEncrypted);
    return value == 'true';
  }

  Future<void> setEncryptedBiometricSetupToken({
    required String plaintextToken,
    required String secret,
  }) async {
    await ensureInitialized();
    final encrypted = AlternateLoginCrypto.encrypt(
      plaintext: plaintextToken,
      secret: secret,
    );
    await _secure.write(PrefConst.obdxBiometricSetupToken, encrypted);
    await _secure.write(PrefConst.obdxSetupTokenEncrypted, 'true');
  }

  /// Decrypts the stored setup token with PIN/pattern secret. Returns null if wrong.
  Future<String?> decryptBiometricSetupToken(String secret) async {
    await ensureInitialized();
    final payload = await _secure.read(PrefConst.obdxBiometricSetupToken);
    if (payload == null || payload.isEmpty) return null;
    if (!await isSetupTokenEncrypted()) return payload;
    return AlternateLoginCrypto.decrypt(payload: payload, secret: secret);
  }

  Future<AlternateLoginMethod?> getAlternateLoginMethod() async {
    await ensureInitialized();
    return AlternateLoginMethod.tryParse(
      await _secure.read(PrefConst.alternateLoginMethod),
    );
  }

  Future<void> setAlternateLoginMethod(AlternateLoginMethod method) async {
    await ensureInitialized();
    await _secure.write(PrefConst.alternateLoginMethod, method.name);
  }

  /// Clears server biometric enrollment only (keeps local biometric preference).
  Future<void> clearBiometricServerEnrollment() async {
    await ensureInitialized();
    await _secure.delete(PrefConst.obdxBiometricSetupToken);
    await _secure.delete(PrefConst.obdxSetupTokenEncrypted);
    await _secure.delete(PrefConst.obdxBiometricServerEnrolled);
  }

  /// Invalidates quick-access after OBDX rejects the setup token (e.g. session
  /// taken over by another channel). Keeps [PrefConst.obdxSecureDeviceId] so
  /// re-enrollment after password login can reuse the same device id.
  Future<void> invalidateBiometricQuickLogin() async {
    await clearBiometricServerEnrollment();
    await _secure.delete(PrefConst.biometricEnabled);
    await _secure.delete(PrefConst.alternateLoginMethod);
  }

  Future<bool> isKeepSignedIn() async {
    await ensureInitialized();
    final value = await _secure.read(PrefConst.keepSignedIn);
    // Default true when unset — matches login checkbox default.
    return value != 'false';
  }

  Future<void> setKeepSignedIn(bool enabled) async {
    await ensureInitialized();
    await _secure.write(PrefConst.keepSignedIn, enabled ? 'true' : 'false');
  }

  Future<String> getThemeMode() async {
    await ensureInitialized();
    return _legacyPrefs.getString(PrefConst.themeMode);
  }

  Future<void> setThemeMode(String mode) async {
    await ensureInitialized();
    await _legacyPrefs.setString(PrefConst.themeMode, mode);
  }

  Future<String> getAppLocale() async {
    await ensureInitialized();
    return _legacyPrefs.getString(PrefConst.appLocale);
  }

  Future<void> setAppLocale(String languageCode) async {
    await ensureInitialized();
    await _legacyPrefs.setString(PrefConst.appLocale, languageCode);
  }

  Future<void> savePendingBiometricEnrollment({
    required String userName,
    required String encryptedPassword,
    String? plainPassword,
  }) async {
    await ensureInitialized();
    await _secure.write(PrefConst.obdxPendingBiometricUserName, userName);
    await _secure.write(
      PrefConst.obdxPendingBiometricEncryptedPassword,
      encryptedPassword,
    );
    if (plainPassword != null && plainPassword.isNotEmpty) {
      await _secure.write(
        PrefConst.obdxPendingBiometricPlainPassword,
        plainPassword,
      );
    }
  }

  Future<({
    String userName,
    String encryptedPassword,
    String? plainPassword,
  })?> getPendingBiometricEnrollment() async {
    await ensureInitialized();
    final userName = await _secure.read(PrefConst.obdxPendingBiometricUserName);
    final encryptedPassword =
        await _secure.read(PrefConst.obdxPendingBiometricEncryptedPassword);
    if (userName == null ||
        userName.isEmpty ||
        encryptedPassword == null ||
        encryptedPassword.isEmpty) {
      return null;
    }
    final plainPassword =
        await _secure.read(PrefConst.obdxPendingBiometricPlainPassword);
    return (
      userName: userName,
      encryptedPassword: encryptedPassword,
      plainPassword: plainPassword,
    );
  }

  Future<void> clearPendingBiometricEnrollment() async {
    await ensureInitialized();
    await _secure.delete(PrefConst.obdxPendingBiometricUserName);
    await _secure.delete(PrefConst.obdxPendingBiometricEncryptedPassword);
    await _secure.delete(PrefConst.obdxPendingBiometricPlainPassword);
  }

  /// Turns off local quick access without wiping server enrollment.
  ///
  /// Keeps a plaintext JWT setup token (Face/Fingerprint) so the user can
  /// re-enable immediately. Encrypted tokens (Passcode/Pattern) are dropped
  /// because they are unusable without the old secret — re-enable then uses
  /// pending password-login credentials when available.
  /// Pending enrollment credentials are preserved until logout / forget device.
  Future<void> disableLocalQuickAccess() async {
    await ensureInitialized();
    await _secure.delete(PrefConst.biometricEnabled);
    await _secure.delete(PrefConst.alternateLoginMethod);

    if (await isSetupTokenEncrypted()) {
      await _secure.delete(PrefConst.obdxBiometricSetupToken);
      await _secure.delete(PrefConst.obdxSetupTokenEncrypted);
      await _secure.delete(PrefConst.obdxBiometricServerEnrolled);
    }
  }

  /// Full wipe of OBDX biometric login secrets; keeps [PrefConst.obdxSecureDeviceId].
  Future<void> clearBiometricSecrets() async {
    await ensureInitialized();
    await _secure.delete(PrefConst.biometricEnabled);
    await _secure.delete(PrefConst.obdxBiometricSetupToken);
    await _secure.delete(PrefConst.obdxSetupTokenEncrypted);
    await _secure.delete(PrefConst.obdxBiometricServerEnrolled);
    await _secure.delete(PrefConst.alternateLoginMethod);
    await clearPendingBiometricEnrollment();
  }

  Future<void> clearSession() async {
    await ensureInitialized();
    _auth = null;
    await _secure.delete(PrefConst.loggedInAuthorization);
    await _secure.delete(PrefConst.loggedInCookies);
  }

  Future<void> _migrateLegacySessionFromSharedPreferences() async {
    final alreadyMigrated =
        await _legacyPrefs.getBool(PrefConst.secureStorageMigrated);
    if (alreadyMigrated) return;

    final legacyAuth =
        await _legacyPrefs.getString(PrefConst.loggedInAuthorization);
    if (legacyAuth.isNotEmpty) {
      await _secure.write(PrefConst.loggedInAuthorization, legacyAuth);
      await _legacyPrefs.remove(PrefConst.loggedInAuthorization);
    }

    final legacyCookies =
        await _legacyPrefs.getString(PrefConst.loggedInCookies);
    if (legacyCookies.isNotEmpty) {
      await _secure.write(PrefConst.loggedInCookies, legacyCookies);
      await _legacyPrefs.remove(PrefConst.loggedInCookies);
    }

    await _legacyPrefs.setBool(PrefConst.secureStorageMigrated, true);
  }
}
