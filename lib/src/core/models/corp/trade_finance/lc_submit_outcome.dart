import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';

/// Result of submitting an LC initiation or amendment.
///
/// Either the host accepted it ([LcSubmitted]) or it asked for step-up
/// authentication first ([LcAwaitingOtp]) — the caller re-submits the same
/// body with the OTP in `X-Challenge_response`, as the payments flow does.
sealed class LcSubmitOutcome {
  const LcSubmitOutcome();
}

class LcSubmitted extends LcSubmitOutcome {
  const LcSubmitted({
    this.referenceNo,
    this.lcId,
    this.hostMessage,
    this.pendingApproval = false,
  });

  /// `status.referenceNumber` — the transaction reference the user quotes.
  final String? referenceNo;

  /// The LC / application id in the response body, when present.
  final String? lcId;

  /// Host message (INFO/WARNING) shown on the result screen.
  final String? hostMessage;

  /// True when the response indicates the transaction went into the
  /// maker-checker queue rather than straight to the bank.
  final bool pendingApproval;

  /// SUCCESS RESPONSE NOT CAPTURED (neither the initiation submit nor the
  /// amendment submit completed in the pre-sales captures). This reads the
  /// fields every other digx transaction response uses; adjust once a
  /// successful submit is captured.
  factory LcSubmitted.fromBody(Map<String, dynamic> body) {
    final status = TfJson.map(body['status']);
    final message = TfJson.map(status['message']);
    final lc = TfJson.map(body['letterOfCredit']);
    final amendment = TfJson.map(body['letterOfCreditAmendmentDTO']);
    final text = [
      TfJson.str(message['detail']),
      TfJson.str(message['title']),
      TfJson.str(message['code']),
    ].whereType<String>().join(' ').toUpperCase();
    return LcSubmitted(
      referenceNo: TfJson.str(status['referenceNumber']) ??
          TfJson.str(status['referenceNo']),
      lcId: TfJson.str(lc['id']) ?? TfJson.str(amendment['id']),
      hostMessage: TfJson.str(message['detail']) ?? TfJson.str(message['title']),
      pendingApproval: text.contains('APPROV') ||
          TfJson.str(lc['authStatus'])?.toUpperCase() == 'UNAUTHORIZED',
    );
  }
}

class LcAwaitingOtp extends LcSubmitOutcome {
  const LcAwaitingOtp(this.challenge);

  final ObdxChallenge challenge;
}
