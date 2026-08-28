import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_primary_button.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_pin_input.dart';

  /// Shared OTP entry used by login, registration, and forgot-credentials.
  ///
  /// [attemptsLeft] / [resendsLeft] come from OBDX `X-Challenge` (or registration
  /// payload). When [attemptsLeft] is `<= 0`, pin and submit are disabled.
  /// When [resendsLeft] is `<= 0`, Resend is disabled.
class OtpChallengeBody extends StatelessWidget {
  const OtpChallengeBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSubmit,
    required this.onResend,
    this.attemptsLeft,
    this.resendsLeft,
    this.referenceNumber,
    this.errorMessage,
    this.otpLength = 4,
    this.submitLabel,
    this.verifyingLabel,
    @Deprecated('Cancel removed to match login; back uses header.')
    this.onCancel,
    @Deprecated('Cancel removed to match login.')
    this.cancelLabel,
    this.expandToFill = true,
    this.didntReceiveLabel,
    this.resendLabel,
    this.compact = false,
    this.showSubmitButton = true,
  });

  final String title;
  final String subtitle;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final int? attemptsLeft;
  final int? resendsLeft;
  final String? referenceNumber;
  final String? errorMessage;
  final int otpLength;
  final String? submitLabel;
  final String? verifyingLabel;
  final String? didntReceiveLabel;
  final String? resendLabel;

  /// When true (login / forgot), fills height with a spacer above actions.
  /// When false (registration in a scroll view), packs content tightly.
  final bool expandToFill;

  /// Transfer-style OTP: smaller heading, no login-scale type.
  final bool compact;

  /// When false, the parent supplies Confirm / Cancel / Back.
  final bool showSubmitButton;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compactHeight = Responsive.of(context).isCompactHeight;
    final submitDisabled =
        isLoading || (attemptsLeft != null && attemptsLeft! <= 0);
    final resendDisabled =
        isLoading || (resendsLeft != null && resendsLeft! <= 0);
    final titleSize = compact
        ? 18.0
        : (expandToFill ? (compactHeight ? 28.0 : 36.0) : 28.0);

    final content = <Widget>[
      Text(
        title,
        style: TextStyle(
          fontSize: titleSize,
          fontWeight: FontWeight.w600,
          color: AuthColors.textPrimary(context),
          height: 1.2,
          letterSpacing: compact ? -0.2 : 0,
        ),
      ),
      SizedBox(height: compact ? 6 : 8),
      Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AuthColors.textSecondary(context),
          height: 1.45,
        ),
      ),
      if (attemptsLeft != null) ...[
        const SizedBox(height: 8),
        Text(
          l10n.otpAttemptsLeft(attemptsLeft!),
          style: TextStyle(
            fontSize: 13,
            color: AuthColors.textSecondary(context),
          ),
        ),
      ],
      if (resendsLeft != null) ...[
        const SizedBox(height: 4),
        Text(
          l10n.otpResendsLeft(resendsLeft!),
          style: TextStyle(
            fontSize: 13,
            color: AuthColors.textSecondary(context),
          ),
        ),
      ],
      if (referenceNumber != null && referenceNumber!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          l10n.otpReferenceNumber(referenceNumber!),
          style: TextStyle(
            fontSize: 13,
            color: AuthColors.textSecondary(context),
          ),
        ),
      ],
      const SizedBox(height: 24),
      OtpPinInput(
        controller: controller,
        focusNode: focusNode,
        length: otpLength,
        enabled: !submitDisabled,
        onCompleted: (_) => onSubmit(),
      ),
      if (errorMessage != null && errorMessage!.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(
          errorMessage!,
          style: TextStyle(
            color: AuthColors.error(context),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
      if (expandToFill)
        const Spacer()
      else
        SizedBox(height: compact ? 16 : 24),
      Row(
        mainAxisAlignment:
            compact ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Text(
            didntReceiveLabel ?? l10n.otpDidntReceive,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AuthColors.textSecondary(context),
            ),
          ),
          TextButton(
            onPressed: resendDisabled ? null : onResend,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              resendLabel ?? l10n.otpResend,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: resendDisabled
                    ? AuthColors.textSecondary(context)
                    : AuthColors.brand(context),
              ),
            ),
          ),
        ],
      ),
      if (showSubmitButton) ...[
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: isLoading
              ? (verifyingLabel ?? l10n.otpVerifying)
              : (submitLabel ?? l10n.otpContinue),
          isLoading: isLoading,
          onPressed: submitDisabled ? null : onSubmit,
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: content,
    );
  }
}
