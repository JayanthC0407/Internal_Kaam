import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/obdx_otp_outcome.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';

/// Runs one OBDX write, asking for the OTP on each 417 until it is done,
/// fails or the user cancels (then the last 417 result comes back).
/// [title] / [invalidOtp] default to the app's generic OTP texts.
Future<ResponseHandler<T>> runWithOtp<T extends ObdxOtpOutcome>(
  BuildContext context,
  Future<ResponseHandler<T>> Function(ObdxChallenge? challenge, String? otp) call, {
  String? title,
  String? invalidOtp,
}) async {
  final l10n = AppLocalizations.of(context);
  var result = await call(null, null);
  while (result is Success<T> && result.data?.challenge != null) {
    final outcome = result.data!;
    if (!context.mounted) return result;
    final otp = await showPayOtpPrompt(
      context,
      title: title ?? l10n.otpTitle,
      error: outcome.invalidOtp ? (invalidOtp ?? l10n.errorOtpInvalid) : null,
      attemptsLeft: outcome.challenge!.attemptsLeft,
    );
    if (otp == null || !context.mounted) return result;
    result = await call(outcome.challenge, otp);
  }
  return result;
}

/// Done: not failed and no OTP still waiting.
bool obdxWriteDone<T extends ObdxOtpOutcome>(ResponseHandler<T> r) =>
    r is Success<T> && r.data != null && r.data!.challenge == null;
