import 'package:ubci_bank/src/core/models/login_trace.dart';
import 'package:ubci_bank/src/core/models/otp_login_pending.dart';

/// Outcome of password login — either complete or OTP step-up required.
class LoginFlowResult {
  const LoginFlowResult._({this.trace, this.pending});

  factory LoginFlowResult.complete(LoginTrace trace) {
    return LoginFlowResult._(trace: trace);
  }

  factory LoginFlowResult.otpRequired(OtpLoginPending pending) {
    return LoginFlowResult._(pending: pending);
  }

  final LoginTrace? trace;
  final OtpLoginPending? pending;

  bool get isComplete => trace != null;
  bool get needsOtp => pending != null;
}
