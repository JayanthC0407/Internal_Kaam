import 'package:dio/dio.dart';
import 'package:ubci_bank/src/core/models/retail/certificate_models.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Certificates — Interest, Balance and TDS. Every path, query name
/// and task code is from the OBDX source: docs/obdx/features/certificates.md.
/// The screen's GET with `media=application/pdf` is the download.
class ObdxCertificatesApi extends ObdxApiBase {
  ObdxCertificatesApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _dda = '/digx-common/dda/v1';
  static const _td = '/digx-common/td/v1';
  static const _loan = '/digx-common/loan/v1';
  static const _pdf = 'application/pdf';

  /// `GET common currentDate` — the branch date the lists are built from.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCurrentDate() => _get('/digx-common/common/v1/currentDate');

  /// Interest Certificates' account list for [category], with OBDX's task
  /// code (interest-certificate-all/hooks.js:74-86; account-input model).
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccounts(CertificateCategory category) => switch (category) {
        CertificateCategory.casa => _get('$_dda/demandDeposit', {'taskCode': category.taskCode}),
        // `deposit?module=CON&module=ISL`: the module parameter twice.
        CertificateCategory.deposits =>
          _get('$_td/deposit', {'module': ['CON', 'ISL'], 'taskCode': category.taskCode}),
        CertificateCategory.loans => _get('$_loan/loan', {'taskCode': category.taskCode}),
      };

  /// Interest Certificates, on screen ([pdf] false) or as the PDF: the
  /// path and query OBDX uses for each category and Specific / All
  /// (interest-certificate-all/model.js; hooks.js:157-364, 414-485).
  /// [accountId] null = All Accounts.
  static (String, Map<String, dynamic>) interestRequest({
    required CertificateCategory category,
    required String? accountId,
    String? module,
    required String fromDate,
    required String toDate,
  }) {
    final dates = {'fromDate': fromDate, 'toDate': toDate};
    final id = accountId == null ? null : Uri.encodeComponent(accountId);
    return switch (category) {
      CertificateCategory.casa => id == null
          ? ('$_dda/demandDeposit/paidInterest', {...dates, 'taskCode': category.taskCode})
          : ('$_dda/demandDeposit/$id/interest', dates),
      CertificateCategory.loans => id == null
          ? ('$_loan/loan/paidInterest', {...dates, 'taskCode': category.taskCode})
          : ('$_loan/loan/$id/paidInterest', dates),
      // OBDX sends TD-all's `module` as its whole account-list type
      // string (hooks.js:330, a defect); the app sends the list's modules.
      CertificateCategory.deposits => id == null
          ? ('$_td/deposit/paidInterest', {...dates, 'taskCode': category.taskCode, 'module': ['CON', 'ISL']})
          : ('$_td/deposit/$id/paidInterest', {...dates, if (module != null) 'module': module}),
    };
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchInterest((String, Map<String, dynamic>) request) =>
      _get(request.$1, request.$2);

  /// The PDF: the same request with `media=application/pdf` and, as OBDX
  /// does for downloads, the category's task code.
  Future<ResponseHandler<List<int>>> downloadInterest(
    (String, Map<String, dynamic>) request,
    CertificateCategory category,
  ) =>
      _bytes(request.$1, {...request.$2, 'taskCode': category.taskCode});

  /// `GET account accounts/balanceCertificates?month={1-12}&year={YYYY}`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBalance(DateTime month) =>
      _get('/digx-common/account/v1/accounts/balanceCertificates', _monthQuery(month));

  Future<ResponseHandler<List<int>>> downloadBalance(DateTime month) =>
      _bytes('/digx-common/account/v1/accounts/balanceCertificates', _monthQuery(month));

  /// `GET td deposit/taxPaid?fromDate&toDate&taskCode=TD_I_TDS`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchTds(String fromDate, String toDate) =>
      _get('$_td/deposit/taxPaid', _tdsQuery(fromDate, toDate));

  Future<ResponseHandler<List<int>>> downloadTds(String fromDate, String toDate) =>
      _bytes('$_td/deposit/taxPaid', _tdsQuery(fromDate, toDate));

  static Map<String, dynamic> _monthQuery(DateTime m) => {'month': '${m.month}', 'year': '${m.year}'};

  static Map<String, dynamic> _tdsQuery(String fromDate, String toDate) =>
      {'fromDate': fromDate, 'toDate': toDate, 'taskCode': 'TD_I_TDS'};

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path, [Map<String, dynamic>? query]) async {
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
        queryParameters: {...query, 'media': _pdf},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          listFormat: ListFormat.multi,
          headers: {'Accept': '$_pdf, application/octet-stream, application/json, */*'},
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
}
