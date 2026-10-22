import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_payment_models.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_bill_payments_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Bill Payments (EBPP) — Billers and Add Billers. Parses
/// [ObdxBillPaymentsApi] responses into `biller_models.dart`;
/// docs/obdx/features/bill-payments.md §3-4.
///
/// Write calls follow OBDX's framework behaviour for every request
/// (docs/obdx/SOURCE.md "Behaviour every request inherits"): 417 +
/// `X-CHALLENGE` asks for an OTP, and 202 or `APPROVAL_STATUS: INITIATED`
/// means "sent for approval" — even where the UAT capture showed neither.
class BillPaymentsRepository extends ObdxRepositoryBase {
  BillPaymentsRepository({required ObdxBillPaymentsApi api}) : _api = api;

  final ObdxBillPaymentsApi _api;

  Future<ResponseHandler<List<RegisteredBiller>>> fetchRegisteredBillers() async =>
      parseBody(await _api.fetchRegisteredBillers(), RegisteredBiller.listFromPayload);

  Future<ResponseHandler<RegisteredBiller>> fetchRegisteredBiller(String id) async =>
      parseBody(await _api.fetchRegisteredBiller(id), (body) {
        final biller = RegisteredBiller.fromDetailPayload(body);
        if (biller == null) throw StateError('Empty billerRegistration');
        return biller;
      });

  Future<ResponseHandler<BillerInfo>> fetchBiller(String billerId) async =>
      parseBody(await _api.fetchBiller(billerId), (body) {
        final biller = BillerInfo.fromPayload(body);
        if (biller == null) throw StateError('Empty biller');
        return biller;
      });

  /// Bill Payment History for [query], newest first.
  Future<ResponseHandler<List<BillPayment>>> fetchBillPayments(BillHistoryQuery query) async =>
      parseBody(await _api.fetchBillPayments(query.toQueryParameters()), BillPayment.listFromPayload);

  /// Add Billers' list of billers, sorted by name.
  Future<ResponseHandler<List<BillerInfo>>> fetchBillers() async =>
      parseBody(await _api.fetchBillers(), BillerInfo.listFromPayload);

  /// Add Billers (Manual). 200/201 → added (UAT answers 201); 202 or
  /// `APPROVAL_STATUS: INITIATED` → pending approval; 417 → OTP required
  /// (call again with [challenge] and [otp]).
  Future<ResponseHandler<BillerAddOutcome>> addBiller(
    AddBillerRequest request, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _api.addRegisteredBiller(
      request.toJson(),
      challengeResponseHeader:
          otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    return _writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => BillerAddOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (body, reference, pending) => BillerAddOutcome.added(
        biller: RegisteredBiller.fromDetailPayload(body),
        reference: reference,
        pendingApproval: pending,
      ),
    );
  }

  /// Edit Biller (Manual). Same outcome handling as add and delete.
  Future<ResponseHandler<BillerEditOutcome>> updateBiller(
    EditBillerRequest request, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _api.updateRegisteredBiller(
      request.biller.id,
      request.toJson(),
      challengeResponseHeader:
          otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    return _writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => BillerEditOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (_, reference, pending) =>
          BillerEditOutcome.updated(reference: reference, pendingApproval: pending),
    );
  }

  /// Deletes [billerRegistrationId]. [body] is the raw list item OBDX sends
  /// along (UAT: DELETE with this body answered 200).
  Future<ResponseHandler<BillerDeleteOutcome>> deleteRegisteredBiller(
    String billerRegistrationId, {
    Map<String, dynamic>? body,
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _api.deleteRegisteredBiller(
      billerRegistrationId,
      body: body,
      challengeResponseHeader:
          otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    return _writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => BillerDeleteOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (_, reference, pending) =>
          BillerDeleteOutcome.deleted(reference: reference, pendingApproval: pending),
    );
  }

  /// Shared handling of a write call's wrapped response (same steps as
  /// payee delete, payee_repository.dart:333-387, plus OBDX's
  /// `APPROVAL_STATUS` header, service-base.js:509).
  ResponseHandler<T> _writeOutcome<T>(
    ResponseHandler<Map<String, dynamic>> result, {
    required bool otpSubmitted,
    required T Function(ObdxChallenge next, bool invalidOtp) onOtp,
    required T Function(Map<String, dynamic> body, String? reference, bool pendingApproval) onDone,
  }) {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return mapFailure(result);
    }
    final wrapped = result.data!;
    final status = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

    if (status == StatusCode.EXPECTATION_FAILED) {
      final next = ObdxChallenge.fromPaymentChallengeHeaders(wrapped['headers']);
      if (next != null) {
        return ResponseHandler.success(onOtp(next, otpSubmitted), code: status);
      }
      final error = otpSubmitted
          ? ObdxErrorMapper.fromChallengeResponse(status, body)
          : ObdxErrorMapper.fromHttpResponse(status, body);
      return ResponseHandler.error(error.httpStatusCode ?? status, error.userMessage, obdxError: error);
    }

    final approval = ObdxApiUtils.headerValue(wrapped['headers'], 'APPROVAL_STATUS');
    final pending = status == StatusCode.ACCEPTED || (approval ?? '').toUpperCase() == 'INITIATED';
    if (!pending && ObdxApiUtils.hasErrorMessage(body)) {
      final error = ObdxErrorMapper.fromHttpResponse(status, body);
      return ResponseHandler.error(error.httpStatusCode ?? status, error.userMessage, obdxError: error);
    }
    final reference = ObdxApiUtils.asMap(body['status'])['referenceNumber'] ?? body['externalReferenceId'];
    return ResponseHandler.success(onDone(body, reference?.toString(), pending), code: status);
  }
}
