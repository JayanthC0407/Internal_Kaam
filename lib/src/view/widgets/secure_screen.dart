import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/config/screen_security_config.dart';
import 'package:ubci_bank/src/infra/security/screen_security_service.dart';

/// Wraps sensitive screens with OS screenshot / screen-recording protection.
///
/// Apply to: login, OTP, CVV, card details, statements, transfer confirmation.
/// Web: no-op (browser cannot enforce FLAG_SECURE).
class SecureScreen extends StatefulWidget {
  const SecureScreen({
    super.key,
    required this.child,
    this.enabled,
  });

  final Widget child;

  /// When null, uses [ScreenSecurityConfig.isProtectionEnabled].
  final bool? enabled;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  bool get _isEnabled => widget.enabled ?? ScreenSecurityConfig.isProtectionEnabled;

  @override
  void initState() {
    super.initState();
    if (_isEnabled) {
      ScreenSecurityService.enable();
    }
  }

  @override
  void dispose() {
    if (_isEnabled) {
      ScreenSecurityService.disable();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
