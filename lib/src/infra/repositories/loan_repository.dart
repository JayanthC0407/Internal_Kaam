import 'dart:convert';

import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/account_transaction.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/models/loan_account_details.dart';
import 'package:ubci_bank/src/core/models/loan_repayment.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_loan_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

class LoanRepository {
  LoanRepository({required ObdxLoanApi loanApi}) : _loanApi = loanApi;

  final ObdxLoanApi _loanApi;

  Future<ResponseHandler<LoanAccountsSummary>> fetchLoans() async {
    try {
      final result = await _loanApi.fetchLoans();
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

      final summary = LoanAccountsSummary.fromPayload(body);
      return ResponseHandler.success(summary, code: statusCode);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Last [noOfTransactions] transactions for a loan — reuses
  /// [AccountTransaction] since the loan transactions endpoint shares
  /// the same field names as the CASA one.
  Future<ResponseHandler<List<AccountTransaction>>> fetchRecentLoanTransactions(
    String loanId, {
    int noOfTransactions = 5,
  }) async {
    try {
      final result = await _loanApi.fetchLoanTransactions(
        loanId,
        noOfTransactions: noOfTransactions,
      );
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

      return ResponseHandler.success(
        AccountTransaction.listFromPayload(body),
        code: statusCode,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<LoanAccountDetails>> fetchLoanDetails(
    String loanId, {
    String? module,
  }) async {
    try {
      final result = await _loanApi.fetchLoanDetails(loanId, module: module);
      if (result is! Success<Map<String, dynamic>> || result.data == null) {
        return _mapFailure(result);
      }
      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

      final failure = _checkBusinessError<LoanAccountDetails>(
        statusCode,
        body,
      );
      if (failure != null) return failure;

      final dto = ObdxApiUtils.asMap(body['loanAccountDetails']);
      return ResponseHandler.success(
        LoanAccountDetails.fromJson(dto),
        code: statusCode,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<LoanSchedule>> fetchLoanSchedule(
    String loanId, {
    String? module,
  }) async {
    try {
      final result = await _loanApi.fetchLoanSchedule(loanId, module: module);
      if (result is! Success<Map<String, dynamic>> || result.data == null) {
        return _mapFailure(result);
      }
      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

      final failure = _checkBusinessError<LoanSchedule>(statusCode, body);
      if (failure != null) return failure;

      return ResponseHandler.success(
        LoanSchedule.fromPayload(body),
        code: statusCode,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<LoanOutstanding>> fetchLoanOutstanding(
    String loanId, {
    String? module,
    String? repaymentType,
  }) async {
    try {
      final result = await _loanApi.fetchLoanOutstanding(
        loanId,
        module: module,
        repaymentType: repaymentType,
      );
      if (result is! Success<Map<String, dynamic>> || result.data == null) {
        return _mapFailure(result);
      }
      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

      final failure = _checkBusinessError<LoanOutstanding>(statusCode, body);
      if (failure != null) return failure;

      return ResponseHandler.success(
        LoanOutstanding.fromPayload(body),
        code: statusCode,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<List<LoanDisbursement>>> fetchLoanDisbursements(
    String loanId, {
    String? module,
  }) async {
    try {
      final result =
          await _loanApi.fetchLoanDisbursements(loanId, module: module);
      if (result is! Success<Map<String, dynamic>> || result.data == null) {
        return _mapFailure(result);
      }
      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

      final failure = _checkBusinessError<List<LoanDisbursement>>(
        statusCode,
        body,
      );
      if (failure != null) return failure;

      return ResponseHandler.success(
        LoanDisbursement.listFromPayload(body),
        code: statusCode,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<LoanRepaymentOutcome>> submitRepayment({
    required String loanId,
    required LoanRepaymentRequest request,
    String? otp,
    LoanRepaymentChallenge? challenge,
  }) async {
    try {
      final result = await _loanApi.postLoanRepayment(
        loanId,
        request.toJson(),
        challengeResponse: (otp != null && challenge != null)
            ? {
                'otp': otp,
                'referenceNo': challenge.referenceNo,
                'authType': challenge.authType ?? 'OTP',
              }
            : null,
      );
      if (result is! Success<Map<String, dynamic>> || result.data == null) {
        return _mapFailure(result);
      }
      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);

      // OTP enabled on this host: OBDX answers with 417 + an `X-CHALLENGE`
      // header instead of completing the repayment straight away. Surface
      // that as an outcome (not an error) so the UI can ask for the OTP —
      // hosts with OTP disabled never hit this branch and go straight to
      // the 200/201 success path below.
      if (statusCode == 417) {
        final challengeHeader = ObdxApiUtils.headerValue(
          wrapped['headers'],
          'X-CHALLENGE',
        );
        if (challengeHeader != null) {
          try {
            final challengeJson =
                ObdxApiUtils.asMap(jsonDecode(challengeHeader));
            return ResponseHandler.success(
              LoanRepaymentAwaitingOtp(
                LoanRepaymentChallenge.fromJson(challengeJson),
              ),
              code: statusCode,
            );
          } catch (_) {
            // Malformed/unrecognized challenge header — fall through to
            // the generic business-error handling below.
          }
        }
      }

      // The repayment endpoint returns HTTP 201 Created on success (it's
      // creating a settlement record), not 200 OK like the read-only loan
      // endpoints — confirmed against the OBDX capture. Treat both as
      // success so a completed payment isn't reported as a failure.
      final failure = _checkBusinessError<LoanRepaymentOutcome>(
        statusCode,
        body,
        successCodes: const [StatusCode.OK, 201],
      );
      if (failure != null) return failure;

      return ResponseHandler.success(
        LoanRepaymentCompleted(LoanRepaymentResult.fromPayload(body)),
        code: statusCode,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  ResponseHandler<T>? _checkBusinessError<T>(
    int statusCode,
    Map<String, dynamic> body, {
    List<int> successCodes = const [StatusCode.OK],
  }) {
    if (!successCodes.contains(statusCode)) {
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
    return null;
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
