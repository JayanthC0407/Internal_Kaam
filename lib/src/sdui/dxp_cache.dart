import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dxp_config.dart';

/// The last good configuration a platform sent, kept on the device so the
/// app can keep drawing it while the platform cannot be reached
/// (CONTRACT-OBDX §8, prototype "last-known-good").
///
/// It holds designs only: the manifest (menu, theme, screen hashes) and the
/// screen documents. No customer data ever reaches these documents
/// (CONTRACT-OBDX rule 0.1), so shared preferences are an acceptable store.
class DxpCachedConfig {
  const DxpCachedConfig({
    required this.manifest,
    required this.screens,
    this.etag,
  });

  final Map<String, dynamic> manifest;
  final Map<String, Map<String, dynamic>> screens;
  final String? etag;
}

class DxpCache {
  const DxpCache();

  static const _key = 'dxp.cache.v1';

  /// Which platform and user type a copy belongs to: a copy from another
  /// platform, user type or contract is never used.
  static String _scope(String userType) =>
      '${DxpConfig.contract}|${DxpConfig.baseUrl}|$userType';

  Future<void> save(String userType, DxpCachedConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'scope': _scope(userType),
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'etag': config.etag,
          'manifest': config.manifest,
          'screens': config.screens,
        }),
      );
    } catch (_) {
      // A cache that cannot be written only costs the offline fallback.
    }
  }

  Future<DxpCachedConfig?> load(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map || json['scope'] != _scope(userType)) return null;
      final manifest = json['manifest'];
      final screens = json['screens'];
      if (manifest is! Map || screens is! Map) return null;
      return DxpCachedConfig(
        manifest: Map<String, dynamic>.from(manifest),
        screens: {
          for (final e in screens.entries)
            if (e.value is Map) e.key.toString(): Map<String, dynamic>.from(e.value as Map),
        },
        etag: json['etag']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
