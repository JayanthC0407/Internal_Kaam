import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Corporate profile / context APIs: the party behind the logged-in user,
/// the bank configuration its totals are reported in, and the mailbox badge
/// count shown on the header bell.
///
/// The `me` call itself is not repeated here — it already runs during login
/// (`ObdxUserApi.fetchProfile`) and its response is handed to the dashboard
/// on the login trace, which is where `CorpUserProfile` is parsed from.
class ObdxCorpProfileApi extends ObdxApiBase {
  ObdxCorpProfileApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  /// `GET /digx-common/user/v1/me/party`
  Future<ResponseHandler<Map<String, dynamic>>> fetchParty() =>
      _get(CorpApiConst.partyApi);

  /// `GET /digx-common/common/v1/bankConfiguration`
  Future<ResponseHandler<Map<String, dynamic>>> fetchBankConfiguration() =>
      _get(CorpApiConst.bankConfigurationApi);

  /// `GET /digx-common/common/v1/currency` — the bank's currency master.
  ///
  /// Sits alongside `bankConfiguration` because both are session-level
  /// `digx-common/common/v1` reference lookups the dashboard reads once.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCurrencies() =>
      _get(CorpApiConst.currencyApi);

  /// `GET /digx-common/collaboration/v1/mailbox/count?msgFlag=T`
  Future<ResponseHandler<Map<String, dynamic>>> fetchMailboxCount({
    String messageFlag = 'T',
  }) =>
      _get(
        CorpApiConst.mailboxCountApi,
        queryParameters: {'msgFlag': messageFlag},
      );

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
