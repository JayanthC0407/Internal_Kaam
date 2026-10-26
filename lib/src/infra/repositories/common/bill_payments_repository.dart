import 'package:ubci_bank/src/core/models/common/bill_payments/bill_payment_models.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/statement_format.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_bill_payments_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
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

  /// Bill Payment History's download formats: only **CSV and PDF**, as OBDX
  /// offers (payment-history/hooks.js:409-416).
  Future<ResponseHandler<List<StatementFormat>>> fetchHistoryFormats() async => parseBody(
        await _api.fetchHistoryMediaTypes(),
        (body) => StatementFormat.listFromPayload(body)
            .where((f) => f.code.toLowerCase() == 'csv' || f.code.toLowerCase() == 'pdf')
            .toList(),
      );

  /// Downloads the history for [query] in [format] — decoded by the same
  /// shared code as account statements (statement_download.dart).
  Future<ResponseHandler<StatementFile>> downloadHistory(
    BillHistoryQuery query,
    StatementFormat format,
  ) async =>
      decodeStatementDownload(
        await _api.downloadBillPayments(
          query.toQueryParameters(),
          media: format.mimeType,
          mediaFormat: format.code.toLowerCase(),
        ),
        format: format,
        fileName: statementFileName(query.period.searchBy, format.fileExtension, prefix: 'bill_payments'),
      );

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
    return writeOutcome(
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
    return writeOutcome(
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
    return writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => BillerDeleteOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (_, reference, pending) =>
          BillerDeleteOutcome.deleted(reference: reference, pendingApproval: pending),
    );
  }

}
