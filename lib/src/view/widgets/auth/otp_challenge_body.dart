import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/screens/common/auth/auth_colors.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_primary_button.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_pin_input.dart';

  /// Shared OTP entry used by login, registration, and forgot-credentials.
  ///
  /// [attemptsLeft] / [resendsLeft] come from OBDX `X-Challenge` (or registration
  /// payload). When [attemptsLeft] is `<= 0`, pin and submit are disabled.
  /// When [resendsLeft] is `<= 0`, Resend is disabled.
class OtpChallengeBody extends StatefulWidget {
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
    this.showTitle = true,
    this.underlineBoxes = false,
    this.resendCooldownSeconds = 0,
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

  /// False when the screen header already shows the title (login mock).
  final bool showTitle;

  /// Underlined digit slots (login mock) instead of boxes.
  final bool underlineBoxes;

  /// When > 0, Resend waits this long after the screen opens and after
  /// each resend ("Resend code in 00:30"). OBDX's resend limit
  /// ([resendsLeft]) still applies.
  final int resendCooldownSeconds;

  @override
  State<OtpChallengeBody> createState() => _OtpChallengeBodyState();
}

class _OtpChallengeBodyState extends State<OtpChallengeBody> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    if (widget.resendCooldownSeconds <= 0) return;
    _timer?.cancel();
    setState(() => _secondsLeft = widget.resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _resend() {
    widget.onResend();
    _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compactHeight = Responsive.of(context).isCompactHeight;
    final submitDisabled = widget.isLoading ||
        (widget.attemptsLeft != null && widget.attemptsLeft! <= 0);
    final resendDisabled = widget.isLoading ||
        (widget.resendsLeft != null && widget.resendsLeft! <= 0);
    final titleSize = widget.compact
        ? 18.0
        : (widget.expandToFill ? (compactHeight ? 28.0 : 36.0) : 28.0);
    final secondary = AuthColors.textSecondary(context);

    final details = [
      if (widget.attemptsLeft != null) l10n.otpAttemptsLeft(widget.attemptsLeft!),
      if (widget.resendsLeft != null) l10n.otpResendsLeft(widget.resendsLeft!),
      if (widget.referenceNumber != null && widget.referenceNumber!.isNotEmpty)
        l10n.otpReferenceNumber(widget.referenceNumber!),
    ];

    final content = <Widget>[
      if (widget.showTitle) ...[
        Text(
          widget.title,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            color: AuthColors.textPrimary(context),
            height: 1.2,
            letterSpacing: widget.compact ? -0.2 : 0,
          ),
        ),
        SizedBox(height: widget.compact ? 6 : 8),
      ],
      Text(
        widget.subtitle,
        style: TextStyle(
          fontSize: widget.showTitle ? 14 : 15,
          fontWeight: widget.showTitle ? FontWeight.w400 : FontWeight.w500,
          color: widget.showTitle
              ? secondary
              : AuthColors.textPrimary(context),
          height: 1.45,
        ),
      ),
      if (details.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final line in details)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(line, style: TextStyle(fontSize: 13, color: secondary)),
          ),
      ],
      const SizedBox(height: 24),
      OtpPinInput(
        controller: widget.controller,
        focusNode: widget.focusNode,
        length: widget.otpLength,
        enabled: !submitDisabled,
        underline: widget.underlineBoxes,
        onCompleted: (_) => widget.onSubmit(),
      ),
      if (widget.errorMessage != null && widget.errorMessage!.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(
          widget.errorMessage!,
          style: TextStyle(
            color: AuthColors.error(context),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
      if (widget.underlineBoxes) const SizedBox(height: 20),
      if (_secondsLeft > 0)
        Align(
          alignment: widget.underlineBoxes
              ? AlignmentDirectional.centerStart
              : Alignment.center,
          child: Text(
            l10n.otpResendIn(
              '00:${_secondsLeft.toString().padLeft(2, '0')}',
            ),
            style: TextStyle(
              fontSize: 14,
              color: AuthColors.brand(context),
            ),
          ),
        ),
      if (widget.expandToFill)
        const Spacer()
      else
        SizedBox(height: widget.compact ? 16 : 24),
      if (_secondsLeft <= 0)
        Row(
          mainAxisAlignment: widget.compact
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.didntReceiveLabel ?? l10n.otpDidntReceive,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: secondary,
                ),
              ),
            ),
            TextButton(
              onPressed: resendDisabled ? null : _resend,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                widget.resendLabel ?? l10n.otpResend,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: resendDisabled
                      ? secondary
                      : AuthColors.brand(context),
                ),
              ),
            ),
          ],
        ),
      if (widget.showSubmitButton) ...[
        const SizedBox(height: 12),
        AuthPrimaryButton(
          label: widget.isLoading
              ? (widget.verifyingLabel ?? l10n.otpVerifying)
              : (widget.submitLabel ?? l10n.otpContinue),
          isLoading: widget.isLoading,
          onPressed: submitDisabled ? null : widget.onSubmit,
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: content,
    );
  }
}
