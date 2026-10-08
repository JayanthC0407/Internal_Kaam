import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/retail/account_transaction.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit_actions.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_term_deposit_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// A transactions search period — OBDX's `searchBy` codes.
enum TdTransactionPeriod {
  currentMonth('CPR'),
  previousMonth('PMT'),
  previousQuarter('PQT'),
  lastTen('LNT');

  const TdTransactionPeriod(this.code);

  final String code;
}

/// Retail term deposits: reads and the four actions.
class TermDepositRepository extends ObdxRepositoryBase {
  TermDepositRepository({required ObdxTermDepositApi api}) : _api = api;

  final ObdxTermDepositApi _api;

  static const _created = {StatusCode.OK, StatusCode.CREATED};

  // ── Reads ──────────────────────────────────────────────────────────────

  Future<ResponseHandler<TermDepositsSummary>> fetchDeposits({
    bool includeClosed = true,
  }) async =>
      parseBody(
        await _api.fetchDeposits(includeClosed: includeClosed),
        TermDepositsSummary.fromPayload,
      );

  /// The deposits an action allows (OBDX [TdTask] codes).
  Future<ResponseHandler<List<TermDeposit>>> fetchDepositsFor(
    String taskCode,
  ) async =>
      parseBody(
        await _api.fetchDeposits(taskCode: taskCode),
        TermDeposit.listFromPayload,
      );

  Future<ResponseHandler<TermDeposit>> fetchDeposit(String id) async =>
      parseBody(await _api.fetchDeposit(id), (body) {
        final deposit = TermDeposit.fromDetailPayload(body);
        if (deposit == null) throw const FormatException('no deposit');
        return deposit;
      });

  Future<ResponseHandler<List<TdPayoutInstruction>>> fetchPayoutInstructions(
    String id,
  ) async =>
      parseBody(
        await _api.fetchPayoutInstructions(id),
        TdPayoutInstruction.listFromPayload,
      );

  /// [from]–[to] searches a date range (`SPD`); otherwise [period].
  Future<ResponseHandler<List<AccountTransaction>>> fetchTransactions(
    String id, {
    TdTransactionPeriod period = TdTransactionPeriod.currentMonth,
    String transactionType = 'A',
    DateTime? from,
    DateTime? to,
  }) async {
    final range = from != null && to != null;
    return parseBody(
      await _api.fetchTransactions(
        id,
        searchBy: range ? 'SPD' : period.code,
        transactionType: transactionType,
        fromDate: range ? _ymd(from) : null,
        toDate: range ? _ymd(to) : null,
        noOfTransactions:
            !range && period == TdTransactionPeriod.lastTen ? 10 : null,
      ),
      AccountTransaction.listFromPayload,
    );
  }

  Future<ResponseHandler<List<TdEnumOption>>> fetchEnumeration(
    String name,
  ) async =>
      parseBody(
        await _api.fetchEnumeration(name),
        TdEnumOption.listFromPayload,
      );

  Future<ResponseHandler<List<TdPayAccount>>> fetchPayAccounts(
    String taskCode,
  ) async =>
      parseBody(
        await _api.fetchPayAccounts(taskCode),
        TdPayAccount.listFromPayload,
      );

  Future<ResponseHandler<TdBranch?>> fetchBranch(String code) async =>
      parseBody(await _api.fetchBranch(code), TdBranch.fromPayload);

  Future<ResponseHandler<List<TdProduct>>> fetchProducts() async =>
      parseBody(await _api.fetchProducts(), TdProduct.listFromPayload);

  // ── Top-up ─────────────────────────────────────────────────────────────

  Future<ResponseHandler<TdTopUpQuote>> simulateTopUp({
    required TermDeposit deposit,
    required double amount,
    required TdPayAccount source,
  }) async {
    final request = TdTopUpQuote.request(
      deposit: deposit,
      amount: amount,
      source: source,
    );
    return parseBody(
      await _api.topUp(deposit.id, request, simulation: true),
      (body) => TdTopUpQuote.fromPayload(body, request: request),
      successCodes: _created,
    );
  }

  Future<ResponseHandler<TdSubmitOutcome>> confirmTopUp({
    required String depositId,
    required TdTopUpQuote quote,
    String? otp,
    ObdxChallenge? challenge,
  }) async =>
      _outcome(
        await _api.topUp(
          depositId,
          quote.raw,
          challengeResponse: _otpHeader(otp, challenge),
        ),
      );

  // ── Redeem ─────────────────────────────────────────────────────────────

  Future<ResponseHandler<TdRedemptionQuote>> quoteRedemption(
    TdRedeemRequest request,
  ) async =>
      parseBody(
        await _api.redemptionQuote(request.deposit.id, request.toJson()),
        TdRedemptionQuote.fromPayload,
        successCodes: _created,
      );

  Future<ResponseHandler<TdSubmitOutcome>> redeem({
    required TdRedeemRequest request,
    required TdRedemptionQuote quote,
    String? otp,
    ObdxChallenge? challenge,
  }) async =>
      _outcome(
        await _api.redeem(
          request.deposit.id,
          request.toJson(quote: quote),
          challengeResponse: _otpHeader(otp, challenge),
        ),
      );

  // ── Maturity instructions ─────────────────────────────────────────────

  Future<ResponseHandler<TdSubmitOutcome>> updateMaturity({
    required TdMaturityUpdate update,
    String? otp,
    ObdxChallenge? challenge,
  }) async =>
      _outcome(
        await _api.updateMaturity(
          update.deposit.id,
          update.toJson(),
          challengeResponse: _otpHeader(otp, challenge),
        ),
      );

  // ── Open ───────────────────────────────────────────────────────────────

  /// Validate-only: the rate, maturity date and amount for the review.
  Future<ResponseHandler<TdOpenQuote>> validateOpen(
    TdOpenRequest request,
  ) async =>
      parseBody(
        await _api.openDeposit(request.toJson(), validateOnly: true),
        TdOpenQuote.fromPayload,
        successCodes: _created,
      );

  Future<ResponseHandler<TdSubmitOutcome>> open({
    required TdOpenRequest request,
    String? otp,
    ObdxChallenge? challenge,
  }) async =>
      _outcome(
        await _api.openDeposit(
          request.toJson(),
          challengeResponse: _otpHeader(otp, challenge),
        ),
      );

  // ── Helpers ────────────────────────────────────────────────────────────

  static String? _otpHeader(String? otp, ObdxChallenge? challenge) =>
      otp != null && challenge != null
          ? challenge.toChallengeResponseHeader(otp)
          : null;

  /// A confirm's answer: OBDX's OTP request (417 + `X-CHALLENGE`), or the
  /// done result.
  Future<ResponseHandler<TdSubmitOutcome>> _outcome(
    ResponseHandler<Map<String, dynamic>> result,
  ) async {
    if (result is Success<Map<String, dynamic>> && result.data != null) {
      final wrapped = result.data!;
      if (wrapped['statusCode'] == 417) {
        final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);
        final challenge = ObdxChallenge.fromResponse(
          headers: wrapped['headers'],
          body: body,
        );
        if (challenge != null) {
          return ResponseHandler.success(TdNeedsOtp(challenge), code: 417);
        }
      }
    }
    return parseBody<TdSubmitOutcome>(
      result,
      TdSubmitted.fromPayload,
      successCodes: _created,
    );
  }

  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
