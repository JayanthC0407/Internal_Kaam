import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Corporate Loans & Finances. OBDX `apiType`s: `corporateloan` →
/// [_loans] (both `corporateloan/*` and `bulkCorporateLoan/*`),
/// `processmanagement` → [CorpApiConst.processManagementApi], `content` →
/// `/digx-common/content/v1`.
class ObdxCorpLoansApi extends ObdxApiBase {
  ObdxCorpLoansApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  /// `apiType: corporateloan`. Not in the channel bundle (the server maps
  /// it); it follows the Retail `loan` module (`/digx-common/loan/v1`) —
  /// change it here if the bank's server differs.
  static const _loans = '/digx-common/corporateloan/v1';
  static const _contents = '/digx-common/content/v1/contents';

  static String _loan(String id) => '$_loans/corporateloan/${Uri.encodeComponent(id)}';

  /// The loans the user may see: `GET corporateloan?taskCode=LN_I_CDD`, or
  /// Multiple Loan Repayment's Get Contracts with its filter.
  Future<ResponseHandler<Map<String, dynamic>>> fetchLoans(Map<String, dynamic> query) =>
      _get('$_loans/corporateloan', query: query);

  /// `GET corporateloan/{id}/transactions`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchTransactions(String id, Map<String, dynamic> query) =>
      _get('${_loan(id)}/transactions', query: query);

  /// Messages / Advices: `swiftMessageOrAdviceDetails?transactionType=`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchNotices(String id, String kind) =>
      _get('${_loan(id)}/swiftMessageOrAdviceDetails', query: {'transactionType': kind});

  /// One message / advice as a PDF.
  Future<ResponseHandler<List<int>>> downloadNotice(String id, String kind, String messageId) => _bytes(
        '${_loan(id)}/swiftMessageOrAdviceDetails',
        {'transactionType': kind, 'messageId': messageId, 'media': 'application/pdf', 'mediaFormat': 'pdf'},
      );

  /// `GET bulkCorporateLoan/generateBulkRefNumber` → `repaymentDetailDTO.bulkReferenceNumber`.
  Future<ResponseHandler<Map<String, dynamic>>> generateBulkReference() => _get('$_loans/bulkCorporateLoan/generateBulkRefNumber');

  /// How [amount] would be split over the loan's components.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAllocation(
    String id, {
    required double amount,
    required String currency,
    String? maturityDate,
  }) =>
      _get(
        '$_loans/bulkCorporateLoan/${Uri.encodeComponent(id)}/fetchRepaymentAllocation',
        query: {
          'repaymentSimulations': '',
          'currency': currency,
          'amount': amount,
          'settlementDate': '',
          'maturityDate': maturityDate ?? '',
          'actionType': '',
        },
      );

  /// `POST corporateloan/{id}/repayments`.
  Future<ResponseHandler<Map<String, dynamic>>> repay(String id, Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _write('POST', '${_loan(id)}/repayments', body, challengeResponseHeader);

  /// CASA accounts for the source accounts (Retail's `demandDeposit`).
  Future<ResponseHandler<Map<String, dynamic>>> fetchSourceAccounts() => _get(ApiConst.accountsApiDemandDeposit);

  /// Application Tracker: `processManagement?status=&moduleId=OBCLPM`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchApplications(String status, {String? partyId}) => _get(
        CorpApiConst.processManagementApi,
        query: {'status': status, 'moduleId': CorpApiConst.loanProcessModuleId, if (partyId != null) 'partyId': partyId},
      );

  /// Deletes a draft application.
  Future<ResponseHandler<Map<String, dynamic>>> deleteApplication(String refId) =>
      _write('DELETE', '${CorpApiConst.processManagementApi}/${Uri.encodeComponent(refId)}', null, null);

  /// An application's documents (`transactionType=MO`).
  Future<ResponseHandler<Map<String, dynamic>>> fetchApplicationDocuments(String refId, String partyId) => _get(
        '${CorpApiConst.processManagementApi}/${Uri.encodeComponent(refId)}/documents',
        query: {'partyId': partyId, 'transactionType': 'MO'},
      );

  /// A document's file.
  Future<ResponseHandler<List<int>>> downloadDocument(String contentId, String partyId) => _bytes(
        '$_contents/${Uri.encodeComponent(contentId)}',
        {'alt': 'media', 'ownerId': partyId, 'transactionType': 'MO', 'toBeDownloaded': 'true'},
      );

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: query,
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
          listFormat: ListFormat.multi,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<List<int>>> _bytes(String path, Map<String, dynamic> query) async {
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: query,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Accept': 'application/pdf, application/octet-stream, */*'},
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return ResponseHandler.exceptionError();
      return ResponseHandler.success(List<int>.from(bytes), code: response.statusCode ?? 0);
    } on DioException catch (error) {
      return getErrorResponse<List<int>>(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse<List<int>>(exc, stack);
    }
  }

  /// A write: 202 (approval) and 417 (OTP) come back as data, not errors.
  Future<ResponseHandler<Map<String, dynamic>>> _write(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? challengeResponseHeader,
  ) async {
    try {
      final response = await dio.request(
        ObdxApiUtils.appendLocaleQuery(path),
        data: body,
        options: Options(
          method: method,
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            if (challengeResponseHeader != null && challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) => status == 200 || status == 201 || status == 202 || status == 204 || status == 417,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }
}
