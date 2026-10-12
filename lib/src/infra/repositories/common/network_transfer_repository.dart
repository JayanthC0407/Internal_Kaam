import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/own_account_transfer.dart';
import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_payee_api.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_payments_api.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Transfers to payees — existing, adhoc, repeat, and International Low
/// Value Payment — on the OBDX 22.2 network payment APIs.
class NetworkTransferRepository extends ObdxRepositoryBase {
  NetworkTransferRepository({
    required ObdxPaymentsApi paymentsApi,
    required ObdxPayeeApi payeeApi,
    required ObdxAccountsApi accountsApi,
  })  : _payments = paymentsApi,
        _payees = payeeApi,
        _accounts = accountsApi;

  final ObdxPaymentsApi _payments;
  final ObdxPayeeApi _payees;
  final ObdxAccountsApi _accounts;

  // ── Lookups ────────────────────────────────────────────────────────────

  Future<ResponseHandler<List<TransferNetwork>>> fetchNetworks() async =>
      parseBody(await _payments.fetchNetworks(), TransferNetwork.listFromPayload);

  /// Saved payees the transfer screens can pay.
  Future<ResponseHandler<List<TransferPayee>>> fetchPayees() async =>
      parseBody(await _payees.fetchPayees(), (body) {
        final list = body['listPayees'];
        return [
          if (list is List)
            for (final item in list)
              if (item is Map)
                if (TransferPayee.fromJson(Map<String, dynamic>.from(item))
                    case final payee?)
                  payee,
        ];
      });

  /// Accounts that may pay on a network — its task code, else the own
  /// account transfer's.
  Future<ResponseHandler<List<CasaAccount>>> fetchDebitAccounts(
    String? taskCode,
  ) async {
    final result = taskCode == null
        ? await _accounts.fetchTransferEligibleAccounts()
        : await _accounts.fetchTransferEligibleAccounts(taskCode: taskCode);
    return parseBody(result, CasaAccount.listFromPayload);
  }

  Future<ResponseHandler<List<TransferPurpose>>> fetchPurposes(
    String networkCode,
  ) async =>
      parseBody(
        await _payments.fetchNetworkPurposes(networkCode),
        TransferPurpose.listFromPayload,
      );

  Future<ResponseHandler<List<GpiCurrency>>> fetchGpiCurrencies() async =>
      parseBody(await _payments.fetchGpiCurrencies(), GpiCurrency.listFromPayload);

  /// The frequencies the bank offers — the server's own list when the
  /// enumeration answers, filtered to the ones the app can schedule.
  Future<ResponseHandler<List<TransferFrequency>>> fetchFrequencies() async =>
      parseBody(await _payments.fetchFrequencies(), (body) {
        final reps = body['enumRepresentations'];
        final data = reps is List && reps.isNotEmpty
            ? ObdxApiUtils.asMap(reps.first)['data']
            : null;
        final codes = <String>{
          if (data is List)
            for (final d in data)
              if (d is Map) (d['code'] ?? d['value'] ?? '').toString(),
        };
        if (codes.isEmpty) return TransferFrequency.all;
        return [
          for (final f in TransferFrequency.all)
            if (codes.contains(f.code)) f,
        ];
      });

  /// The bank behind a clearing code (domestic) or a SWIFT code.
  Future<ResponseHandler<TransferBank?>> lookupBank({
    required TransferKind kind,
    required String code,
    required String network,
  }) async =>
      parseBody(
        kind == TransferKind.international
            ? await _payments.fetchBicDetails(code)
            : await _payments.fetchNetworkCodeDetails(
                clearingCode: code,
                network: network,
              ),
        TransferBank.fromPayload,
      );

  Future<ResponseHandler<PaymentChargesSummary>> fetchCharges(
    NetworkTransferRequest request,
  ) async =>
      parseBody(
        await _payments.fetchCharges(
          accountId: request.debitAccount.id,
          accountType: request.accountType,
          amount: request.amount,
          currency: request.currency,
          paymentDate: obdxPaymentDate(
            request.schedule?.startDate ?? request.paymentDate,
          ),
          network: request.network,
        ),
        PaymentChargesSummary.fromPayload,
      );

  // ── Validate and submit ───────────────────────────────────────────────

  /// `X-Validate-Only`: the bank checks the transfer and answers its value
  /// date, exchange rate and the reference to submit it with.
  Future<ResponseHandler<TransferValidationResult>> validate(
    NetworkTransferRequest request,
  ) async =>
      parseBody(
        await _post(request, validateOnly: true),
        TransferValidationResult.fromPayload,
      );

  /// Submits; OBDX may answer 417 with an OTP challenge, retried with the
  /// [otp] for [challenge].
  Future<ResponseHandler<TransferSubmitOutcome>> submit(
    NetworkTransferRequest request, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _post(
      request,
      challengeResponseHeader:
          otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return mapFailure(result);
    }
    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);
    // A repeat transfer answers 201 for success — read it as 200 does.
    final outcome = TransferSubmitOutcome.tryParse(
      statusCode: statusCode == StatusCode.CREATED ? StatusCode.OK : statusCode,
      headers: wrapped['headers'],
      body: body,
      otpSubmitted: otpSubmitted,
    );
    if (outcome != null) {
      return ResponseHandler.success(outcome, code: statusCode);
    }
    final error = otpSubmitted
        ? ObdxErrorMapper.fromChallengeResponse(statusCode, body)
        : ObdxErrorMapper.fromHttpResponse(statusCode, body);
    return ResponseHandler.error(
      error.httpStatusCode ?? statusCode,
      error.userMessage,
      obdxError: error,
    );
  }

  // ── Multiple Transfers: one batch, as OBDX's web sends them ────────────

  /// Checks every transfer in one batch (`X-BATCH_TYPE: CMFT`, each part
  /// `X-Validate-Only`). One result per request, in order; each accepted
  /// one carries the reference to submit it with.
  Future<ResponseHandler<List<BatchRowResult<TransferValidationResult>>>>
      validateBatch(List<NetworkTransferRequest> requests) async => parseBody(
            await _payments.postBatch(
              _batchItems(requests, validateOnly: true),
              batchType: ObdxBatchType.validateMultipleTransfers,
            ),
            (body) => _batchRows(
              body,
              requests.length,
              TransferValidationResult.fromPayload,
            ),
            successCodes: _batchSuccessCodes,
          );

  /// Submits every transfer in one batch (`X-BATCH_TYPE: MFT`). The bank
  /// asks for a single OTP for the batch (417), retried with [otp] for
  /// [challenge]; then each row says whether it went through.
  Future<ResponseHandler<BatchSubmitOutcome>> submitBatch(
    List<NetworkTransferRequest> requests, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _payments.postBatch(
      _batchItems(requests),
      batchType: ObdxBatchType.multipleTransfers,
      challengeResponseHeader:
          otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    if (result is Success<Map<String, dynamic>> &&
        result.data?['statusCode'] == ApiConst.expectationFailed) {
      final wrapped = result.data!;
      final next = ObdxChallenge.fromPaymentChallengeHeaders(wrapped['headers']);
      if (next != null) {
        return ResponseHandler.success(
          BatchSubmitOutcome.otpRequired(next, invalidOtp: otpSubmitted),
          code: ApiConst.expectationFailed,
        );
      }
      final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);
      final error = otpSubmitted
          ? ObdxErrorMapper.fromChallengeResponse(ApiConst.expectationFailed, body)
          : ObdxErrorMapper.fromHttpResponse(ApiConst.expectationFailed, body);
      return ResponseHandler.error(
        error.httpStatusCode ?? ApiConst.expectationFailed,
        error.userMessage,
        obdxError: error,
      );
    }
    return parseBody(
      result,
      (body) => BatchSubmitOutcome.done(
        _batchRows(body, requests.length, TransferSubmitResult.fromPayload),
      ),
      successCodes: _batchSuccessCodes,
    );
  }

  static const _batchSuccessCodes = {StatusCode.OK, StatusCode.MULTI_STATUS};

  /// Each request as a batch part — the same call [validate] / [submit]
  /// would make on its own.
  static List<ObdxBatchItem> _batchItems(
    List<NetworkTransferRequest> requests, {
    bool validateOnly = false,
  }) =>
      [
        for (final request in requests)
          ObdxBatchItem(
            method: 'POST',
            uri: request.isRepeat
                ? '/payments/pay/networkInstruction'
                : '/payments/pay/network',
            applicationId: ApiConst.paymentsBatchApplicationId,
            body: request.toJson(),
            headers: {if (validateOnly) 'X-Validate-Only': 'true'},
          ),
      ];

  /// The batch's answer for each of [count] requests, by position. A part
  /// the bank did not answer counts as failed.
  static List<BatchRowResult<T>> _batchRows<T>(
    Map<String, dynamic> body,
    int count,
    T Function(Map<String, dynamic> body) parse,
  ) {
    final answers = {
      for (final item in ObdxBatchItemResult.listFromPayload(body))
        item.sequenceId: item,
    };
    return [
      for (var i = 0; i < count; i++)
        switch (answers[i]) {
          null => const BatchRowResult.failed(
              "The bank didn't answer for this transfer.",
            ),
          final item when item.succeeded && !ObdxApiUtils.hasErrorMessage(item.body) =>
            BatchRowResult.ok(
              parse(item.body),
              pendingApproval: item.pendingApproval,
            ),
          final item => BatchRowResult.failed(
              ObdxErrorMapper.fromHttpResponse(item.status, item.body).userMessage,
            ),
        },
    ];
  }

  Future<ResponseHandler<Map<String, dynamic>>> _post(
    NetworkTransferRequest request, {
    bool validateOnly = false,
    String? challengeResponseHeader,
  }) =>
      request.isRepeat
          ? _payments.postPayNetworkInstruction(
              request.toJson(),
              validateOnly: validateOnly,
              challengeResponseHeader: challengeResponseHeader,
            )
          : _payments.postPayNetwork(
              request.toJson(),
              validateOnly: validateOnly,
              challengeResponseHeader: challengeResponseHeader,
            );
}
