import 'package:dio/dio.dart';
import 'package:ubci_bank/src/core/models/retail/cheque_book_models.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Cheque Book Request. Paths and queries from the source:
/// docs/obdx/features/cheque-book-request.md.
class ObdxChequeBookApi extends ObdxApiBase {
  ObdxChequeBookApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _dda = '/digx-common/dda/v1';
  static const _location = '/digx-common/location/v1/locations';

  /// `GET dda corpDDAConfig` (stage1/model.js:51-63).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCorpDdaConfig() => _get('$_dda/corpDDAConfig');

  /// `GET dda demandDeposit/config/inputNoOfChequeBooks` (stage1/model.js:11-23).
  Future<ResponseHandler<Map<String, dynamic>>> fetchBooksConfig() =>
      _get('$_dda/demandDeposit/config/inputNoOfChequeBooks');

  /// `GET dda enumerations/chequeBookType` (stage1/model.js:38-50).
  Future<ResponseHandler<Map<String, dynamic>>> fetchBookTypes() => _get('$_dda/enumerations/chequeBookType');

  /// The account picker (stage1/hooks.js:70; `task-code="CH_N_CBR"`).
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccounts() => _get('$_dda/demandDeposit', const {
        'status': 'ACTIVE',
        'accountType': 'CURRENT,SAVING',
        'taskCode': chequeBookTaskCode,
      });

  /// My Address when `corpDDAEnabled`: `GET dda demandDeposit/{id}/address`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccountAddress(String accountId) =>
      _get('$_dda/demandDeposit/${Uri.encodeComponent(accountId)}/address');

  /// My Address otherwise: `GET user me/party` (address/model.js:32-37).
  Future<ResponseHandler<Map<String, dynamic>>> fetchParty() => _get('/digx-common/user/v1/me/party');

  /// `GET dda enumerations/addressType` (address/model.js:38-43).
  Future<ResponseHandler<Map<String, dynamic>>> fetchAddressTypes() => _get('$_dda/enumerations/addressType');

  /// Branch Near Me (address/model.js:10-31).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCities() => _get('$_location/country/all/city');

  Future<ResponseHandler<Map<String, dynamic>>> fetchBranches(String city) =>
      _get('$_location/country/all/city/${Uri.encodeComponent(city)}/branchCode');

  Future<ResponseHandler<Map<String, dynamic>>> fetchBranchAddress(String branchCode) =>
      _get('$_location/branches', {'branchCode': branchCode});

  /// Confirm: `POST dda demandDeposit/{accountId}/chequeBooks`
  /// (review/model.js; review.js:56). 417 (OTP) and 202 (approval) come
  /// back as results, as for the other writes.
  Future<ResponseHandler<Map<String, dynamic>>> requestChequeBook(
    String accountId,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery('$_dda/demandDeposit/${Uri.encodeComponent(accountId)}/chequeBooks'),
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

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path, [Map<String, dynamic>? query]) async {
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
}
