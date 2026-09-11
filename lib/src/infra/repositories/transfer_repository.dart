import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/own_account_transfer.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_payments_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

class TransferRepository {
  TransferRepository({
    required ObdxPaymentsApi paymentsApi,
    required ObdxAccountsApi accountsApi,
  })  : _paymentsApi = paymentsApi,
        _accountsApi = accountsApi;

  final ObdxPaymentsApi _paymentsApi;
  final ObdxAccountsApi _accountsApi;

  /// OBDX API Reference V1.1 — Get Accounts Eligible for Debit.
  Future<ResponseHandler<List<CasaAccount>>> fetchEligibleAccounts() async {
    try {
      final result = await _accountsApi.fetchTransferEligibleAccounts();
      return _parseSuccessBody(result, CasaAccount.listFromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// OBDX API Reference V1.1 — Fetch Payment Networks.
  Future<ResponseHandler<List<PaymentNetwork>>> fetchNetworks() async {
    try {
      final result = await _paymentsApi.fetchNetworks();
      return _parseSuccessBody(result, PaymentNetwork.listFromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// OBDX API Reference V1.1 — Get Payment Maintenance Configuration.
  Future<ResponseHandler<Map<String, dynamic>>> fetchMaintenance() async {
    try {
      final result = await _paymentsApi.fetchMaintenance();
      return _parseSuccessBody(result, (body) => body);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<PaymentCurrentDate>> fetchCurrentDate({
    String branchCode = '001',
  }) async {
    try {
      final result = await _paymentsApi.fetchCurrentDate(branchCode: branchCode);
      return _parseSuccessBody(result, PaymentCurrentDate.fromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<List<PaymentCurrencyOption>>> fetchCurrencies({
    required String currency,
  }) async {
    try {
      final result = await _paymentsApi.fetchCurrencies(currency: currency);
      return _parseSuccessBody(result, (body) {
        final list = body['currencyList'];
        if (list is! List) return const <PaymentCurrencyOption>[];
        return list
            .whereType<Map>()
            .map((e) => PaymentCurrencyOption.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .where((c) => c.code.isNotEmpty)
            .toList();
      });
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<PaymentChargesSummary>> fetchCharges({
    required OwnAccountTransferRequest request,
  }) async {
    try {
      final result = await _paymentsApi.fetchCharges(
        accountId: request.debitAccount.id,
        accountType: request.accountType,
        amount: request.amount,
        currency: request.currency,
        paymentDate: request.toJson()['paymentDate'] as String,
      );
      return _parseSuccessBody(result, PaymentChargesSummary.fromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<TransferValidationResult>> validateTransfer({
    required OwnAccountTransferRequest request,
  }) async {
    try {
      final result = await _paymentsApi.postPayNetwork(
        request.toJson(),
        validateOnly: true,
      );
      return _parseSuccessBody(result, TransferValidationResult.fromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<TransferSubmitOutcome>> submitTransfer({
    required OwnAccountTransferRequest request,
    required String systemReferenceId,
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    try {
      final body = request.toJson()
        ..['systemReferenceId'] = systemReferenceId.trim();
      final otpValue = otp?.trim() ?? '';
      final otpSubmitted = challenge != null && otpValue.isNotEmpty;
      final result = await _paymentsApi.postPayNetwork(
        body,
        challengeResponseHeader: otpSubmitted
            ? challenge.toChallengeResponseHeader(otpValue)
            : null,
      );
      return _parseSubmitOutcome(result, otpSubmitted: otpSubmitted);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  ResponseHandler<TransferSubmitOutcome> _parseSubmitOutcome(
    ResponseHandler<Map<String, dynamic>> result, {
    required bool otpSubmitted,
  }) {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return _mapFailure(result);
    }

    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);
    final outcome = TransferSubmitOutcome.tryParse(
      statusCode: statusCode,
      headers: wrapped['headers'],
      body: body,
      otpSubmitted: otpSubmitted,
    );
    if (outcome != null) {
      return ResponseHandler.success(outcome, code: statusCode);
    }

    if (otpSubmitted) {
      final obdxError = ObdxErrorMapper.fromChallengeResponse(statusCode, body);
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
    return ResponseHandler.error(
      obdxError.httpStatusCode ?? statusCode,
      obdxError.userMessage,
      obdxError: obdxError,
    );
  }

  /// Validates a scheduled payment date when [transferNow] is false.
  Future<ResponseHandler<void>> validateScheduledDate({
    required OwnAccountTransferRequest request,
  }) async {
    try {
      final paymentDate = request.toJson()['paymentDate'] as String;
      final result = await _paymentsApi.fetchGenericPaymentDate(
        accountId: request.debitAccount.id,
        accountType: request.accountType,
        activationDate: paymentDate,
        amount: request.amount,
        currency: request.currency,
        debitCurrency: request.debitAccount.currencyCode,
      );
      if (result is! Success<Map<String, dynamic>> || result.data == null) {
        return _mapFailure(result);
      }
      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);
      if (statusCode != StatusCode.OK ||
          ObdxApiUtils.hasErrorMessage(body)) {
        final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
        return ResponseHandler.error(
          obdxError.httpStatusCode ?? statusCode,
          obdxError.userMessage,
          obdxError: obdxError,
        );
      }
      return ResponseHandler.success(null, code: statusCode);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<T>> _parseSuccessBody<T>(
    ResponseHandler<Map<String, dynamic>> result,
    T Function(Map<String, dynamic> body) parse,
  ) async {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return _mapFailure(result);
    }

    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

    if (statusCode != StatusCode.OK) {
      final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    if (ObdxApiUtils.hasErrorMessage(body)) {
      final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
      return ResponseHandler.error(
        obdxError.httpStatusCode ?? statusCode,
        obdxError.userMessage,
        obdxError: obdxError,
      );
    }

    try {
      final parsed = parse(body);
      return ResponseHandler.success(parsed, code: statusCode);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  ResponseHandler<T> _mapFailure<T>(ResponseHandler<dynamic> result) {
    if (result is Error) {
      return ResponseHandler.error(
        result.code,
        result.error,
        requestId: result.requestId,
        obdxError: result.obdxError,
      );
    }
    if (result is NetworkError) {
      return ResponseHandler.networkError(obdxError: result.obdxError);
    }
    return ResponseHandler.exceptionError();
  }
}
