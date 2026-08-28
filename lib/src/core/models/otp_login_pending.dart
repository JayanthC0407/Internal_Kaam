import 'package:ubci_bank/src/core/models/login_trace.dart';
import 'package:ubci_bank/src/core/models/obdx_challenge.dart';

/// Password login succeeded but profile requires OTP before session is complete.
class OtpLoginPending {
  OtpLoginPending({
    required this.userName,
    required this.partialTrace,
    required ObdxChallenge challenge,
  }) : challenge = challenge;

  final String userName;
  final LoginTrace partialTrace;
  ObdxChallenge challenge;

  void updateChallenge(ObdxChallenge updated) {
    challenge = updated;
  }
}
