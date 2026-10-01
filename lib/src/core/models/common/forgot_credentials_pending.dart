import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/security_question.dart';

enum ForgotCredentialsKind { username, password }

/// Anonymous forgot-credentials request waiting for OTP or SEC_QUE step-up.
class ForgotCredentialsPending {
  ForgotCredentialsPending({
    required this.kind,
    required this.dateOfBirth,
    required this.challenge,
    this.emailId,
    this.userId,
    List<SecurityQuestionOption> securityQuestions = const [],
  }) : securityQuestions = List<SecurityQuestionOption>.from(securityQuestions);

  final ForgotCredentialsKind kind;
  final String dateOfBirth;
  final String? emailId;
  final String? userId;
  ObdxChallenge challenge;

  /// Resolved master question texts for a `SEC_QUE` challenge (empty for OTP).
  List<SecurityQuestionOption> securityQuestions;

  void updateChallenge(ObdxChallenge updated) {
    challenge = updated;
  }

  void updateSecurityQuestions(List<SecurityQuestionOption> questions) {
    securityQuestions = List<SecurityQuestionOption>.from(questions);
  }
}

/// Result of start / challenge steps for forgot username or password.
sealed class ForgotCredentialsFlowResult {
  const ForgotCredentialsFlowResult();

  const factory ForgotCredentialsFlowResult.otpRequired(
    ForgotCredentialsPending pending,
  ) = ForgotOtpRequired;

  const factory ForgotCredentialsFlowResult.securityQuestionsRequired(
    ForgotCredentialsPending pending,
  ) = ForgotSecurityQuestionsRequired;

  const factory ForgotCredentialsFlowResult.complete() =
      ForgotCredentialsComplete;
}

class ForgotOtpRequired extends ForgotCredentialsFlowResult {
  const ForgotOtpRequired(this.pending);

  final ForgotCredentialsPending pending;
}

class ForgotSecurityQuestionsRequired extends ForgotCredentialsFlowResult {
  const ForgotSecurityQuestionsRequired(this.pending);

  final ForgotCredentialsPending pending;
}

class ForgotCredentialsComplete extends ForgotCredentialsFlowResult {
  const ForgotCredentialsComplete();
}
