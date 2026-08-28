import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/login_trace.dart';
import 'package:ubci_bank/src/core/models/otp_login_pending.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';
import 'package:ubci_bank/src/view/screens/home_dashboard_screen.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_shell.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_screen_header.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_challenge_body.dart';
import 'package:ubci_bank/src/view/widgets/biometric_enrollment_prompt.dart';
import 'package:ubci_bank/src/view/widgets/login_help_dialog.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

class OtpLoginArgs {
  const OtpLoginArgs({required this.pending});

  final OtpLoginPending pending;
}

class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key, required this.pending});

  final OtpLoginPending pending;

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isLoading = ref.read(otpIsLoadingProvider);
    if (isLoading) return;

    final l10n = AppLocalizations.of(context);
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ref.read(otpErrorMessageProvider.notifier).state = l10n.otpEnterCode;
      return;
    }

    final result = await ref.read(otpLoginScreenVmProvider).submitOtp(
          pending: widget.pending,
          otp: otp,
        );
    if (!mounted || result == null) return;

    if (result is! Success<LoginTrace> || result.data == null) {
      _otpController.clear();
      _otpFocusNode.requestFocus();
      setState(() {});
      return;
    }

    final prefs = ref.read(preferenceHelperProvider);
    if (!kIsWeb) {
      final existingPending = await prefs.getPendingBiometricEnrollment();
      await prefs.savePendingBiometricEnrollment(
        userName: widget.pending.userName,
        encryptedPassword: widget.pending.partialTrace.encryptedPassword,
        plainPassword: existingPending?.plainPassword,
      );
    }
    await ref.read(sessionManagerProvider).onLoginSuccess(
          userName: widget.pending.userName,
          displayName: result.data!.displayName,
        );
    if (!mounted) return;

    if (!kIsWeb) {
      await BiometricEnrollmentPrompt.afterPasswordLogin(context, ref);
      if (!mounted) return;
    }

    Navigator.of(context).pushReplacementNamed(
      RoutesConst.homeScreen,
      arguments: HomeDashboardArgs(
        userName: widget.pending.userName,
        loginTrace: result.data!.toSafeMap(),
      ),
    );
  }

  Future<void> _handleResendTap() async {
    final isLoading = ref.read(otpIsLoadingProvider);
    if (isLoading) return;

    final l10n = AppLocalizations.of(context);
    final ok = await ref.read(otpLoginScreenVmProvider).resendOtp(
          pending: widget.pending,
        );
    if (!mounted) return;

    if (!ok) {
      setState(() {});
      return;
    }

    _otpController.clear();
    _otpFocusNode.requestFocus();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.otpResendSuccess)),
    );
  }

  void _handleHelpTap() {
    LoginHelpDialog.show(context);
  }

  String _otpSubtitle(AppLocalizations l10n) {
    final email = _maskedEmail();
    final phone = _maskedPhone();
    return l10n.otpSubtitleDetailed(email, phone);
  }

  String _maskedEmail() {
    final profile = widget.pending.partialTrace.profileResponse;
    final raw = profile?['email'] ?? profile?['emailId'];
    if (raw is String && raw.contains('@')) {
      final parts = raw.split('@');
      if (parts.length == 2 && parts[0].length > 2) {
        return '${parts[0].substring(0, 2)}***@${parts[1]}';
      }
      return raw;
    }
    return 'your registered email';
  }

  String _maskedPhone() {
    final profile = widget.pending.partialTrace.profileResponse;
    final raw = profile?['phone'] ?? profile?['mobileNumber'];
    if (raw is Map) {
      final number = raw['number']?.toString() ?? '';
      if (number.length >= 4) {
        return '+** ******${number.substring(number.length - 4)}';
      }
    }
    if (raw is String && raw.length >= 4) {
      return '+** ******${raw.substring(raw.length - 4)}';
    }
    return 'your registered mobile number';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(otpIsLoadingProvider);
    final errorMessage = ref.watch(otpErrorMessageProvider);
    final challenge = widget.pending.challenge;
    final responsive = Responsive.of(context);
    final compact = responsive.isCompactHeight;
    final hPad = responsive.formHorizontalPadding;

    return SecureScreen(
      child: Scaffold(
        backgroundColor: AuthColors.screenBackground(context),
        resizeToAvoidBottomInset: true,
        body: AuthSplitLayout(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, compact ? 4 : 8, hPad, 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: responsive.formMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthScreenHeader(
                        onBack: () => Navigator.of(context).pop(),
                        trailingLabel: l10n.help,
                        onTrailingTap: _handleHelpTap,
                      ),
                      SizedBox(height: compact ? 12 : 24),
                      Expanded(
                        child: OtpChallengeBody(
                          title: l10n.otpTitle,
                          subtitle: _otpSubtitle(l10n),
                          controller: _otpController,
                          focusNode: _otpFocusNode,
                          isLoading: isLoading,
                          attemptsLeft: challenge.attemptsLeft,
                          resendsLeft: challenge.resendsLeft,
                          referenceNumber: challenge.referenceNo.isEmpty
                              ? null
                              : challenge.referenceNo,
                          errorMessage: errorMessage,
                          onSubmit: _submit,
                          onResend: _handleResendTap,
                          expandToFill: !compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
