import 'package:flutter/foundation.dart';

class LoginTrace {
  LoginTrace({
    required this.publicKeyResponse,
    required this.saltResponse,
    required this.encryptedPassword,
    required this.loginResponse,
    this.profileResponse,
    this.accountsResponse,
    this.displayName,
    this.debug,
  });

  final Map<String, dynamic> publicKeyResponse;
  final Map<String, dynamic> saltResponse;
  final String encryptedPassword;
  final Map<String, dynamic> loginResponse;
  final Map<String, dynamic>? profileResponse;
  final Map<String, dynamic>? accountsResponse;
  final String? displayName;
  final Map<String, dynamic>? debug;

  /// Full payload for debug builds only.
  Map<String, dynamic> toMap() => {
        'publicKeyResponse': publicKeyResponse,
        'saltResponse': saltResponse,
        'encryptedPassword': encryptedPassword,
        'loginResponse': loginResponse,
        if (profileResponse != null) 'profileResponse': profileResponse,
        if (accountsResponse != null) 'accountsResponse': accountsResponse,
        if (displayName != null) 'displayName': displayName,
        if (debug != null) 'debug': debug,
      };

  /// Safe subset for navigation / UI — no credentials or debug payloads.
  Map<String, dynamic> toSafeMap() {
    if (kDebugMode) {
      return toMap();
    }
    return {
      if (displayName != null) 'displayName': displayName,
      if (profileResponse != null) 'profileResponse': profileResponse,
      if (accountsResponse != null) 'accountsResponse': accountsResponse,
    };
  }
}
