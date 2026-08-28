import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Manage Payee / Add Bank Account Payee APIs captured from the OBDX UI.
///
/// The domestic pre-submit APIs are implemented from the captured flow.
/// The supplied API document does not contain the final Domestic Payee POST
/// endpoint/payload, so no unverified domestic submit endpoint is invented.
class ObdxPayeeApi extends ObdxApiBase {
  ObdxPayeeApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  static const _maintenance =
      '/digx-payments/payment/v1/payments/maintenance';
  static const _customLimits = '/digx-admin/finlimit/v1/myCustomLimits';
  static const _assignedLimits = '/digx-admin/finlimit/v1/myAssignedLimits';
  static const _bankConfiguration =
      '/digx-common/common/v1/bankConfiguration';
  static const _payees = '/digx-payments/payment/v1/payments/payeesv3';
  static const _accountTypes =
      '/digx-payments/payment/v1/enumerations/payeeAccountType';
  static const _country = '/digx-payments/payment/v1/enumerations/country';
  static const _payeeContent =
      '/digx-payments/payment/v1/payments/maintenance/payeecontent';
  static const _fetchNetwork =
      '/digx-payments/payment/v1/payments/fetchNetwork';
  static const _internalPayee =
      '/digx-payments/payment/v1/payments/payeesv3/internal';

  Future<ResponseHandler<Map<String, dynamic>>> fetchMaintenance() =>
      _get(_maintenance);

  Future<ResponseHandler<Map<String, dynamic>>> fetchCustomLimits() =>
      _get(_customLimits);

  Future<ResponseHandler<Map<String, dynamic>>> fetchAssignedLimits() =>
      _get(_assignedLimits);

  Future<ResponseHandler<Map<String, dynamic>>> fetchBankConfiguration() =>
      _get(_bankConfiguration);

  Future<ResponseHandler<Map<String, dynamic>>> fetchCountries() =>
      _get(_country);

  Future<ResponseHandler<Map<String, dynamic>>> fetchPayeeContent() =>
      _get(_payeeContent);

  Future<ResponseHandler<Map<String, dynamic>>> fetchAccountTypes({
    String region = 'INDIA',
  }) =>
      _get(_accountTypes, queryParameters: {'REGION': region});

  Future<ResponseHandler<Map<String, dynamic>>> fetchDomesticNetworks() =>
      _get(_fetchNetwork, queryParameters: {'paymentType': 'DOMESTIC'});

  Future<ResponseHandler<Map<String, dynamic>>> fetchPayees() => _get(
        _payees,
        queryParameters: {
          'types': 'INTERNAL,INTERNATIONAL,GENERICDOMESTIC',
        },
      );

  Future<ResponseHandler<Map<String, dynamic>>> createInternalPayee({
    required String nickname,
    required String accountNumber,
    required String accountName,
    required String payeeEmail,
    bool shared = false,
    String status = 'ACT',
    bool validateOnly = true,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(_internalPayee),
        data: {
          'nickName': nickname,
          'status': status,
          'accountNumber': accountNumber,
          'accountName': accountName,
          'payeeEmail': payeeEmail,
          'shared': shared,
        },
        options: Options(
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            'X-Validate-Only': validateOnly ? 'Y' : 'N',
          },
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: queryParameters,
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
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
