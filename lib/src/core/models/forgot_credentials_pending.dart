import 'package:ubci_bank/src/core/models/obdx_challenge.dart';

enum ForgotCredentialsKind { username, password }

/// Anonymous forgot-credentials request waiting for OTP step-up.
class ForgotCredentialsPending {
  ForgotCredentialsPending({
    required this.kind,
    required this.dateOfBirth,
    required this.challenge,
    this.emailId,
    this.userId,
  });

  final ForgotCredentialsKind kind;
  final String dateOfBirth;
  final String? emailId;
  final String? userId;
  ObdxChallenge challenge;

  void updateChallenge(ObdxChallenge updated) {
    challenge = updated;
  }
}

/// Result of start / OTP steps for forgot username or password.
sealed class ForgotCredentialsFlowResult {
  const ForgotCredentialsFlowResult();

  const factory ForgotCredentialsFlowResult.otpRequired(
    ForgotCredentialsPending pending,
  ) = ForgotOtpRequired;

  const factory ForgotCredentialsFlowResult.complete() =
      ForgotCredentialsComplete;
}

class ForgotOtpRequired extends ForgotCredentialsFlowResult {
  const ForgotOtpRequired(this.pending);

  final ForgotCredentialsPending pending;
}

class ForgotCredentialsComplete extends ForgotCredentialsFlowResult {
  const ForgotCredentialsComplete();
}
