import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Calculators (docs/obdx/features/calculators.md). `td`, `loan`,
/// `forexdeal` and `common` all live under `/digx-common/{app}/v1`
/// (framework/js/api-catalogue.js:106-109, 156-159, 181-184, 306-309).
class ObdxCalculatorsApi extends ObdxApiBase {
  ObdxCalculatorsApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _loan = '/digx-common/loan/v1/loancalculators';

  /// `GET common bankConfiguration` → `bankConfigurationDTO.localCurrency`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBankConfiguration() =>
      _get('/digx-common/common/v1/bankConfiguration', const {});

  /// `GET loan loancalculators/defaultRange?for=<calculator>&var=<field>`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDefaultRange(String forCalculator, String variable) =>
      _get('$_loan/defaultRange', {'for': forCalculator, 'var': variable});

  /// `GET forexdeal forex/currencyPairs` (OBDX sends no params).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCurrencyPairs() =>
      _get('/digx-common/forexdeal/v1/forex/currencyPairs', const {});

  /// `POST td tdcalculators/deposit/maturity`.
  Future<ResponseHandler<Map<String, dynamic>>> tdMaturity(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _post('/digx-common/td/v1/tdcalculators/deposit/maturity', body, challengeResponseHeader);

  /// `POST loan loancalculators/mortgage/schedule`.
  Future<ResponseHandler<Map<String, dynamic>>> loanSchedule(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _post('$_loan/mortgage/schedule', body, challengeResponseHeader);

  /// `POST loan loancalculators/loanEligibility`.
  Future<ResponseHandler<Map<String, dynamic>>> loanEligibility(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _post('$_loan/loanEligibility', body, challengeResponseHeader);

  /// `POST forexdeal calculators/foreignExchange`.
  Future<ResponseHandler<Map<String, dynamic>>> foreignExchange(Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _post('/digx-common/forexdeal/v1/calculators/foreignExchange', body, challengeResponseHeader);

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path, Map<String, dynamic> query) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: query,
        options: Options(headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue}),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// A POST: 202 (approval) and 417 (OTP) come back as data, not errors.
  Future<ResponseHandler<Map<String, dynamic>>> _post(String path, Map<String, dynamic> body, String? challengeResponseHeader) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(path),
        data: body,
        options: Options(
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            if (challengeResponseHeader != null && challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) => status == 200 || status == 201 || status == 202 || status == 417,
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
