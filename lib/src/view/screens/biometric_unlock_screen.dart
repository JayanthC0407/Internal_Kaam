import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/alternate_login_method.dart';
import 'package:ubci_bank/src/core/models/login_flow_result.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/security/alternate_login_crypto.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';
import 'package:ubci_bank/src/view/screens/home_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/otp_login_screen.dart';
import 'package:ubci_bank/src/view/screens/passcode_setup_screen.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_logo_header.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_pattern_lock.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_pin_pad.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_primary_button.dart';
import 'package:ubci_bank/src/view/widgets/auth/biometric_hero.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';
import 'package:ubci_bank/src/view/widgets/session_expired_dialog.dart';

class BiometricUnlockArgs {
  const BiometricUnlockArgs({
    required this.homeArgs,
    this.performTokenLogin = false,
  });

  final HomeDashboardArgs homeArgs;

  /// When true, exchanges stored OBDX setup token for a new session after local auth.
  final bool performTokenLogin;
}

class BiometricUnlockScreen extends ConsumerStatefulWidget {
  const BiometricUnlockScreen({super.key, required this.args});

  final BiometricUnlockArgs args;

  @override
  ConsumerState<BiometricUnlockScreen> createState() =>
      _BiometricUnlockScreenState();
}

class _BiometricUnlockScreenState extends ConsumerState<BiometricUnlockScreen> {
  AlternateLoginMethod? _method;
  bool _loadingMethod = true;
  bool _authenticating = false;
  String? _errorMessage;
  String _pin = '';
  final _patternKey = GlobalKey<AuthPatternLockState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMethod());
  }

  Future<void> _loadMethod() async {
    final method =
        await ref.read(preferenceHelperProvider).getAlternateLoginMethod() ??
            AlternateLoginMethod.fingerprint;
    if (!mounted) return;
    setState(() {
      _method = method;
      _loadingMethod = false;
    });
    if (method.isBiometric) {
      // Wait for first frame so auto-prompt does not race route transition.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _authenticateBiometric();
    }
  }

  Future<void> _authenticateBiometric() async {
    // Never skip when another prompt is in flight — join it via authenticate().
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _errorMessage = null;
    });

    final l10n = AppLocalizations.of(context);
    final result = await ref.read(biometricServiceProvider).authenticate(
          reason: l10n.biometricUnlockReason,
        );

    if (!mounted) return;

    if (result != BiometricAuthResult.success) {
      setState(() {
        _authenticating = false;
        _errorMessage = biometricResultMessage(l10n, result);
      });
      return;
    }

    await _onLocalAuthSuccess();
  }

  Future<void> _onPinDigit(String digit) async {
    if (_authenticating || _pin.length >= kPasscodeLength) return;
    final next = _pin + digit;
    setState(() {
      _pin = next;
      _errorMessage = null;
    });
    if (next.length == kPasscodeLength) {
      await _submitLocalSecret(next);
    }
  }

  void _onPinBackspace() {
    if (_authenticating || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _onPattern(List<int> dots) async {
    if (_authenticating) return;
    await _submitLocalSecret(AlternateLoginCrypto.patternSecret(dots));
  }

  Future<void> _submitLocalSecret(String secret) async {
    setState(() {
      _authenticating = true;
      _errorMessage = null;
    });

    final prefs = ref.read(preferenceHelperProvider);
    final token = await prefs.decryptBiometricSetupToken(secret);
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() {
        _authenticating = false;
        _errorMessage = AppLocalizations.of(context).passcodeIncorrect;
        _pin = '';
      });
      _patternKey.currentState?.reset();
      return;
    }

    // Session unlock (6.5a): secret verified by successful decrypt.
    if (!widget.args.performTokenLogin) {
      setState(() => _authenticating = false);
      ref.read(biometricLockProvider.notifier).state = false;
      Navigator.of(context).pushReplacementNamed(
        RoutesConst.homeScreen,
        arguments: widget.args.homeArgs,
      );
      return;
    }

    await _completeTokenLogin(setupToken: token);
  }

  Future<void> _onLocalAuthSuccess() async {
    if (widget.args.performTokenLogin) {
      await _completeTokenLogin();
      return;
    }

    setState(() => _authenticating = false);
    ref.read(biometricLockProvider.notifier).state = false;
    Navigator.of(context).pushReplacementNamed(
      RoutesConst.homeScreen,
      arguments: widget.args.homeArgs,
    );
  }

  Future<void> _completeTokenLogin({String? setupToken}) async {
    final l10n = AppLocalizations.of(context);
    final loginResult = await ref
        .read(biometricRepositoryProvider)
        .loginWithBiometricToken(setupTokenOverride: setupToken);
    if (!mounted) return;
    setState(() => _authenticating = false);

    if (loginResult is Success<LoginFlowResult> && loginResult.data != null) {
      final flow = loginResult.data!;
      ref.read(biometricLockProvider.notifier).state = false;

      if (flow.needsOtp && flow.pending != null) {
        Navigator.of(context).pushReplacementNamed(
          RoutesConst.otpLoginScreen,
          arguments: OtpLoginArgs(pending: flow.pending!),
        );
        return;
      }

      if (flow.isComplete && flow.trace != null) {
        final userName =
            await ref.read(sessionManagerProvider).getLastUserName() ??
                widget.args.homeArgs.userName;
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          RoutesConst.homeScreen,
          arguments: HomeDashboardArgs(
            userName: userName,
            loginTrace: flow.trace!.toSafeMap(),
          ),
        );
        return;
      }
    }

    final message = loginResult is Error<LoginFlowResult>
        ? loginResult.error
        : l10n.biometricAuthFailed;

    // Grow-style: keep enrollment; send user to password login (primary auth).
    await _showUsePasswordDialogThenLogin(l10n, message: message);
  }

  Future<void> _usePassword() async {
    await ref.read(sessionManagerProvider).logout();
    if (!mounted) return;
    ref.read(biometricLockProvider.notifier).state = false;
    Navigator.of(context).pushReplacementNamed(RoutesConst.loginScreen);
  }

  Future<void> _showUsePasswordDialogThenLogin(
    AppLocalizations l10n, {
    String? message,
  }) async {
    ref.read(biometricLockProvider.notifier).state = false;
    if (!mounted) return;
    await SessionExpiredDialog.show(
      context,
      title: l10n.sessionExpiredTitle,
      message: message?.trim().isNotEmpty == true
          ? message!.trim()
          : l10n.biometricUsePasswordAfterLogout,
      actionLabel: l10n.sessionExpiredSignIn,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(RoutesConst.loginScreen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userName = widget.args.homeArgs.userName;
    final method = _method;

    return SecureScreen(
      // FLAG_SECURE around BiometricPrompt drops the first success on many OEMs.
      enabled: false,
      child: Scaffold(
        backgroundColor: AuthColors.screenBackground(context),
        body: SafeArea(
          child: _loadingMethod || method == null
              ? Center(
                  child: CircularProgressIndicator(
                    color: AuthColors.brand(context),
                  ),
                )
              : AuthResponsiveScrollBody(
                  builder: (context, responsive, compact) {
                    final heroSize = compact ? 96.0 : 132.0;
                    return [
                      AuthLogoHeader(
                        trailing: TextButton(
                          onPressed: _usePassword,
                          child: Text(
                            l10n.biometricUsePassword,
                            style: TextStyle(
                              color: AuthColors.brand(context),
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
                      if (method.isBiometric) ...[
                        Center(child: BiometricHero(size: heroSize)),
                        SizedBox(height: compact ? 16 : 28),
                      ],
                      Text(
                        _titleFor(method, l10n),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 24 : 28,
                          fontWeight: FontWeight.w600,
                          color: AuthColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AuthColors.brand(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _subtitleFor(method, l10n),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AuthColors.textSecondary(context),
                          height: 1.45,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.red,
                            height: 1.4,
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
                            onCompleted: _onPattern,
                          ),
                        ),
                      if (compact)
                        const SizedBox(height: 20)
                      else
                        const Spacer(),
                      if (method.isBiometric) ...[
                        if (_authenticating)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: CircularProgressIndicator(
                                color: AuthColors.brand(context),
                              ),
                            ),
                          )
                        else
                          AuthPrimaryButton(
                            label: l10n.biometricTryAgain,
                            onPressed: _authenticateBiometric,
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
                            color: AuthColors.brand(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ];
                  },
                ),
        ),
      ),
    );
  }

  String _titleFor(AlternateLoginMethod method, AppLocalizations l10n) {
    return switch (method) {
      AlternateLoginMethod.passcode => l10n.passcodeUnlockTitle,
      AlternateLoginMethod.pattern => l10n.patternUnlockTitle,
      _ => l10n.biometricUnlockTitle,
    };
  }

  String _subtitleFor(AlternateLoginMethod method, AppLocalizations l10n) {
    return switch (method) {
      AlternateLoginMethod.passcode => l10n.passcodeUnlockSubtitle,
      AlternateLoginMethod.pattern => l10n.patternUnlockSubtitle,
      _ => l10n.biometricUnlockSubtitle,
    };
  }
}
