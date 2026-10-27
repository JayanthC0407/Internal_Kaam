import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';

/// The outcome of an OBDX write that may need an OTP first (HTTP 417 with
/// `X-CHALLENGE`). Implemented by each feature's outcome type so one OTP
/// loop (`runWithOtp`, view/widgets/obdx_write_runner.dart) serves them all.
abstract interface class ObdxOtpOutcome {
  /// Set while an OTP is still to be entered.
  ObdxChallenge? get challenge;

  /// The last OTP entered was wrong.
  bool get invalidOtp;
}
