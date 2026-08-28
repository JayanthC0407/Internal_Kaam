import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/alternate_login_method.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/infra/security/alternate_login_crypto.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/infra/service/navigation_service.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';
import 'package:ubci_bank/src/view/screens/passcode_setup_screen.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_pattern_lock.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_pin_pad.dart';
import 'package:ubci_bank/src/view/widgets/auth/biometric_hero.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

/// Full-screen lock shown when the app resumes with quick-access unlock enabled.
/// No-op on web (biometrics / local PIN unlock are mobile-only).
class BiometricLockOverlay extends ConsumerStatefulWidget {
  const BiometricLockOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricLockOverlay> createState() =>
      _BiometricLockOverlayState();
}

class _BiometricLockOverlayState extends ConsumerState<BiometricLockOverlay> {
  AlternateLoginMethod? _method;
  bool _authenticating = false;
  bool _autoPrompted = false;
  String? _error;
  String _pin = '';
  final _patternKey = GlobalKey<AuthPatternLockState>();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadMethod();
    }
  }

  Future<void> _loadMethod() async {
    final method =
        await ref.read(preferenceHelperProvider).getAlternateLoginMethod();
    if (!mounted) return;
    setState(() => _method = method ?? AlternateLoginMethod.fingerprint);
  }

  void _maybeAutoPromptBiometric(bool locked) {
    final method = _method ?? AlternateLoginMethod.fingerprint;
    if (!locked || !method.isBiometric || _authenticating || _autoPrompted) {
      if (!locked) _autoPrompted = false;
      return;
    }
    _autoPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !ref.read(biometricLockProvider)) return;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted || !ref.read(biometricLockProvider)) return;
      // Join any in-flight prompt; do not silently skip.
      await _unlockBiometric();
    });
  }

  Future<void> _unlockBiometric() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });

    final l10n = AppLocalizations.of(context);
    final result = await ref.read(biometricServiceProvider).authenticate(
          reason: l10n.biometricUnlockReason,
        );

    if (!mounted) return;
    if (result == BiometricAuthResult.success) {
      setState(() => _authenticating = false);
      ref.read(biometricLockProvider.notifier).state = false;
      await ref.read(sessionManagerProvider).recordActivity();
      return;
    }
    setState(() {
      _authenticating = false;
      _error = biometricResultMessage(l10n, result);
    });
  }

  Future<void> _submitSecret(String secret) async {
    setState(() {
      _authenticating = true;
      _error = null;
    });
    final token =
        await ref.read(preferenceHelperProvider).decryptBiometricSetupToken(secret);
    if (!mounted) return;
    setState(() => _authenticating = false);

    if (token == null || token.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(context).passcodeIncorrect;
        _pin = '';
      });
      _patternKey.currentState?.reset();
      return;
    }

    ref.read(biometricLockProvider.notifier).state = false;
    await ref.read(sessionManagerProvider).recordActivity();
    setState(() => _pin = '');
  }

  Future<void> _onPinDigit(String digit) async {
    if (_authenticating || _pin.length >= kPasscodeLength) return;
    final next = _pin + digit;
    setState(() {
      _pin = next;
      _error = null;
    });
    if (next.length == kPasscodeLength) {
      await _submitSecret(next);
    }
  }

  void _onPinBackspace() {
    if (_authenticating || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _usePassword() async {
    await ref.read(sessionManagerProvider).logout();
    ref.read(biometricLockProvider.notifier).state = false;
    final nav = NavigationService.globalAppNav.currentState;
    nav?.pushNamedAndRemoveUntil(RoutesConst.loginScreen, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return widget.child;

    final locked = ref.watch(biometricLockProvider);
    final l10n = AppLocalizations.of(context);
    final method = _method ?? AlternateLoginMethod.fingerprint;
    _maybeAutoPromptBiometric(locked);

    return Stack(
      children: [
        widget.child,
        if (locked)
          Positioned.fill(
            child: SecureScreen(
              // Avoid FLAG_SECURE racing the system biometric sheet.
              enabled: false,
              child: Material(
                color: method.isBiometric
                    ? AuthColors.brand(context)
                    : AuthColors.screenBackground(context),
                child: SafeArea(
                  child: AuthResponsiveScrollBody(
                    builder: (context, responsive, compact) {
                      final heroSize = compact ? 96.0 : 132.0;
                      final titleColor = method.isBiometric
                          ? Colors.white
                          : AuthColors.textPrimary(context);
                      final subtitleColor = method.isBiometric
                          ? Colors.white70
                          : AuthColors.textSecondary(context);
                      return [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _usePassword,
                            child: Text(
                              l10n.biometricUsePassword,
                              style: TextStyle(
                                color: method.isBiometric
                                    ? Colors.white
                                    : AuthColors.brand(context),
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        if (compact)
                          const SizedBox(height: 16)
                        else
                          const Spacer(),
                        if (method.isBiometric)
                          Center(
                            child: BiometricHero(
                              size: heroSize,
                              inverted: true,
                            ),
                          ),
                        SizedBox(height: compact ? 16 : 28),
                        Text(
                          _title(method, l10n),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: compact ? 22 : 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _subtitle(method, l10n),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: method.isBiometric
                                  ? Colors.white
                                  : AuthColors.error(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        SizedBox(height: compact ? 16 : 24),
                        if (method == AlternateLoginMethod.passcode)
                          AuthPinPad(
                            length: _pin.length,
                            maxLength: kPasscodeLength,
                            onDigit: _onPinDigit,
                            onBackspace: _onPinBackspace,
                          )
                        else if (method == AlternateLoginMethod.pattern)
                          Center(
                            child: AuthPatternLock(
                              key: _patternKey,
                              onCompleted: (dots) => _submitSecret(
                                AlternateLoginCrypto.patternSecret(dots),
                              ),
                            ),
                          ),
                        if (compact)
                          const SizedBox(height: 20)
                        else
                          const Spacer(),
                        if (method.isBiometric) ...[
                          if (_authenticating)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _unlockBiometric,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AuthColors.brand(context),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(l10n.biometricTryAgain),
                              ),
                            ),
                        ] else if (_authenticating)
                          Center(
                            child: CircularProgressIndicator(
                              color: AuthColors.brand(context),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _usePassword,
                          child: Text(
                            l10n.biometricUsePassword,
                            style: TextStyle(
                              color: method.isBiometric
                                  ? Colors.white
                                  : AuthColors.brand(context),
                            ),
                          ),
                        ),
                      ];
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _title(AlternateLoginMethod method, AppLocalizations l10n) {
    return switch (method) {
      AlternateLoginMethod.passcode => l10n.passcodeUnlockTitle,
      AlternateLoginMethod.pattern => l10n.patternUnlockTitle,
      _ => l10n.biometricUnlockTitle,
    };
  }

  String _subtitle(AlternateLoginMethod method, AppLocalizations l10n) {
    return switch (method) {
      AlternateLoginMethod.passcode => l10n.passcodeUnlockSubtitle,
      AlternateLoginMethod.pattern => l10n.patternUnlockSubtitle,
      _ => l10n.biometricUnlockSubtitle,
    };
  }
}
