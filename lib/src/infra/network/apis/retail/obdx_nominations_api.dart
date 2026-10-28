import 'package:dio/dio.dart';
import 'package:ubci_bank/src/core/models/retail/nomination_models.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Nominations. Paths and queries from the source:
/// docs/obdx/features/nominations.md.
class ObdxNominationsApi extends ObdxApiBase {
  ObdxNominationsApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _dda = '/digx-common/dda/v1';
  static const _td = '/digx-common/td/v1';

  /// The Account Number picker (nominations/hooks.js:13-36).
  Future<ResponseHandler<Map<String, dynamic>>> fetchPickerAccounts(NominationCategory c) => switch (c) {
        NominationCategory.casa => _get('$_dda/demandDeposit', const {
            'status': 'ACTIVE',
            'accountType': 'CURRENT,SAVING',
            'taskCode': 'CH_I_IC',
          }),
        NominationCategory.termDeposits => _get('$_td/deposit', const {
            'module': ['CON', 'ISL'],
            'taskCode': 'TD_I_IC',
          }),
        NominationCategory.recurringDeposits => _get('$_td/deposit', const {'module': 'RD'}),
      };

  /// The list with the nominee status ({casa,td,rd}-nominee-list/model.js).
  Future<ResponseHandler<Map<String, dynamic>>> fetchNominationRows(NominationCategory c) => switch (c) {
        NominationCategory.casa => _get('$_dda/demandDeposit', const {'accountType': 'CURRENT,SAVING'}),
        NominationCategory.termDeposits => _get('$_td/deposit', const {'module': 'CON'}),
        NominationCategory.recurringDeposits => _get('$_td/deposit', const {'module': 'RD'}),
      };

  /// `GET party nominee/{accountId}` (view-nominee/model.js:30-32).
  Future<ResponseHandler<Map<String, dynamic>>> fetchNominee(String accountId) =>
      _get('/digx-common/party/v1/nominee/${Uri.encodeComponent(accountId)}');

  /// `GET td enumerations/nomineeRelations` and `enumerations/country`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchRelations() => _get('$_td/enumerations/nomineeRelations');
  Future<ResponseHandler<Map<String, dynamic>>> fetchCountries() => _get('$_td/enumerations/country');

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
}
