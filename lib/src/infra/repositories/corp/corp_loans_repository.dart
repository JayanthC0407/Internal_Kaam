import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loans_models.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_loans_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

/// Corporate Loans & Finances: parses [ObdxCorpLoansApi] into
/// `corp_loans_models.dart`. A repayment can come back with an OTP or for
/// approval — the same [PrefWriteOutcome] the app's other writes use.
class CorpLoansRepository extends CorpRepositoryBase {
  CorpLoansRepository({required ObdxCorpLoansApi api}) : _api = api;

  final ObdxCorpLoansApi _api;

  /// The Loan Account list (`taskCode=LN_I_CDD`, active conventional and
  /// Islamic loans).
  Future<ResponseHandler<List<CorpLoan>>> fetchLoans() async => parseBody(
        await _api.fetchLoans(const {
          'taskCode': 'LN_I_CDD',
          'module': ['CON', 'ISL'],
          'status': 'ACTIVE',
        }),
        CorpLoan.listFromPayload,
      );

  /// Multiple Loan Repayment's Get Contracts.
  Future<ResponseHandler<List<CorpLoan>>> fetchContracts(CorpLoanContractFilter filter, {DateTime? today}) async =>
      parseBody(await _api.fetchLoans(filter.toQuery(today ?? DateTime.now())), CorpLoan.listFromPayload);

  Future<ResponseHandler<({List<CorpLoanTxn> items, bool showValueDate})>> fetchTransactions(
    String loanId,
    CorpLoanTxnQuery query, {
    DateTime? today,
  }) async =>
      parseBody(await _api.fetchTransactions(loanId, query.toQuery(today ?? DateTime.now())), CorpLoanTxn.fromPayload);

  Future<ResponseHandler<List<CorpLoanNotice>>> fetchNotices(String loanId, CorpLoanNoticeKind kind) async =>
      parseBody(await _api.fetchNotices(loanId, kind.code), CorpLoanNotice.listFromPayload);

  Future<ResponseHandler<List<int>>> downloadNotice(String loanId, CorpLoanNoticeKind kind, String messageId) =>
      _api.downloadNotice(loanId, kind.code, messageId);

  Future<ResponseHandler<String>> generateBulkReference() async => parseBody(await _api.generateBulkReference(), (body) {
        final ref = ObdxApiUtils.asMap(body['repaymentDetailDTO'])['bulkReferenceNumber'] ?? body['bulkReferenceNumber'];
        final s = ref?.toString() ?? '';
        if (s.isEmpty) throw const FormatException('no bulk reference');
        return s;
      });

  /// How [amount] is split over [loan]'s components, in its own currency.
  Future<ResponseHandler<List<CorpRepaymentComponent>>> fetchAllocation(CorpLoan loan, double amount) async {
    final maturity = loan.maturityDate;
    return parseBody(
      await _api.fetchAllocation(
        loan.id,
        amount: amount,
        currency: loan.currency,
        maturityDate: maturity == null
            ? null
            : '${maturity.year.toString().padLeft(4, '0')}-${maturity.month.toString().padLeft(2, '0')}-${maturity.day.toString().padLeft(2, '0')}',
      ),
      CorpRepaymentComponent.listFromPayload,
    );
  }

  /// CASA accounts for the source accounts.
  Future<ResponseHandler<List<SrAccount>>> fetchSourceAccounts() async =>
      parseBody(await _api.fetchSourceAccounts(), SrAccount.listFromPayload);

  /// One contract's repayment.
  Future<ResponseHandler<PrefWriteOutcome>> repay(
    CorpRepaymentLine line,
    String bulkReference, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _api.repay(
      line.loan.id,
      line.toBody(bulkReference),
      challengeResponseHeader: otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    return writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => PrefWriteOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (body, reference, pending) => PrefWriteOutcome.done(
        pendingApproval: pending,
        reference: reference ?? ObdxApiUtils.asMap(body['repaymentDetail'])['bulkReferenceNumber']?.toString(),
      ),
    );
  }

  Future<ResponseHandler<List<CorpLoanApplicationItem>>> fetchApplications(CorpAppStatus status, {String? partyId}) async =>
      parseBody(await _api.fetchApplications(status.code, partyId: partyId), CorpLoanApplicationItem.listFromPayload);

  /// Deletes a draft; true when OBDX says SUCCESSFUL (or sends no body).
  Future<ResponseHandler<bool>> deleteDraft(String refId) async => parseBody(
        await _api.deleteApplication(refId),
        (body) {
          final result = ObdxApiUtils.asMap(body['status'])['result']?.toString();
          return result == null || result == 'SUCCESSFUL';
        },
        successCodes: const {200, 204},
      );

  Future<ResponseHandler<List<CorpAppDocument>>> fetchDocuments(String refId, String partyId) async =>
      parseBody(await _api.fetchApplicationDocuments(refId, partyId), CorpAppDocument.listFromPayload);

  Future<ResponseHandler<List<int>>> downloadDocument(String contentId, String partyId) => _api.downloadDocument(contentId, partyId);
}
