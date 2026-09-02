import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Pure-UI OTP entry sheet body, shared by the Internal and International
/// payment flows' step-up authentication step (functional flow doc §7,
/// §17). Each flow wraps this in a small `ConsumerStatefulWidget` bound to
/// its own submission provider — mirroring how `LoanRepaymentScreen`
/// already wires its OTP sheet — so this widget itself stays
/// provider-agnostic and reusable.
class PaymentOtpSheetView extends StatefulWidget {
  const PaymentOtpSheetView({
    super.key,
    required this.isSubmitting,
    required this.onSubmit,
    this.attemptsLeft,
    this.errorText,
    this.title = 'Verify Transaction',
    this.subtitle = 'Enter the one-time code sent to your registered mobile number.',
  });

  final bool isSubmitting;
  final int? attemptsLeft;
  final String? errorText;
  final String title;
  final String subtitle;
  final void Function(String otp) onSubmit;

  @override
  State<PaymentOtpSheetView> createState() => _PaymentOtpSheetViewState();
}

class _PaymentOtpSheetViewState extends State<PaymentOtpSheetView> {
  final _otpController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _localError = 'Please enter the code.');
      return;
    }
    setState(() => _localError = null);
    HapticFeedback.lightImpact();
    widget.onSubmit(otp);
  }

  @override
  Widget build(BuildContext context) {
    final inlineError = widget.errorText ?? _localError;
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HomeColors.divider(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: 13,
                color: HomeColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              autofocus: true,
              obscureText: true,
              obscuringCharacter: '●',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                color: HomeColors.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: '••••••',
                errorText: inlineError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) {
                if (_localError != null) setState(() => _localError = null);
              },
              onSubmitted: (_) => _handleSubmit(),
            ),
            if (widget.attemptsLeft != null) ...[
              const SizedBox(height: 8),
              Text(
                '${widget.attemptsLeft} attempt(s) left',
                style: TextStyle(
                  fontSize: 12,
                  color: HomeColors.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: widget.isSubmitting ? null : _handleSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.brand(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
