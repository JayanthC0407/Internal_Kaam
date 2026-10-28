import 'package:dio/dio.dart';
import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Sweep-In. Paths and queries from the source:
/// docs/obdx/features/sweep-in.md.
class ObdxSweepInApi extends ObdxApiBase {
  ObdxSweepInApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _dda = '/digx-common/dda/v1';

  /// The account picker (stage1/hooks.js:73).
  Future<ResponseHandler<Map<String, dynamic>>> fetchPickerAccounts() =>
      _get('$_dda/demandDeposit', const {'status': 'ACTIVE', 'accountType': 'CURRENT,SAVING'});

  /// `GET dda demandDeposit/{id}/sweepInInstructions`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchInstructions(String accountId) =>
      _get('$_dda/demandDeposit/${Uri.encodeComponent(accountId)}/sweepInInstructions');

  /// The CASA list: OBDX calls `demandDeposit` with no query
  /// (`demandDepositgetCall()`, stage1/hooks.js:345, 362, 479).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCasaAccounts() => _get('$_dda/demandDeposit');

  /// The TD list: `td deposit` with no query (`depositgetCall()`).
  Future<ResponseHandler<Map<String, dynamic>>> fetchDeposits() => _get('/digx-common/td/v1/deposit');

  /// Delete: `DELETE dda demandDeposit/{id}/sweepInInstructions/{instructionNumber}`
  /// (stage1/hooks.js:553-581). 417 (OTP) and 202 (approval) come back as
  /// results.
  Future<ResponseHandler<Map<String, dynamic>>> deleteInstruction(
    String accountId,
    String instructionNumber, {
    String? challengeResponseHeader,
  }) async {
    try {
      final response = await dio.delete(
        ObdxApiUtils.appendLocaleQuery(
          '$_dda/demandDeposit/${Uri.encodeComponent(accountId)}/sweepInInstructions/${Uri.encodeComponent(instructionNumber)}',
        ),
        options: Options(
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            if (challengeResponseHeader != null && challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) => status == 200 || status == 202 || status == 204 || status == 417,
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Confirm: `POST /digx-common/batch` (dda's domain; appshell-properties.js
  /// 296-307), one part per provider, built by the shared [ObdxBatchEncoder].
  /// OBDX sends no `X-BATCH_TYPE`: the flow passes "MSI" where the batch
  /// reads options, and `params.type` is undefined (service-base.js:875-884;
  /// sweep-in.md §3). 200 / 207 carry a result per part; 417 asks one OTP.
  Future<ResponseHandler<Map<String, dynamic>>> linkProviders(
    List<ObdxBatchItem> items, {
    String? challengeResponseHeader,
    String? boundary,
  }) async {
    try {
      final separator = boundary ?? ObdxBatchEncoder.newBoundary();
      final contentType = 'multipart/form-data; boundary=$separator';
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery('/digx-common/batch'),
        data: ObdxBatchEncoder.encode(items, separator),
        options: Options(
          contentType: contentType,
          headers: {
            ApiConst.contentTypeKey: contentType,
            // The servlet splits the body on this header.
            'boundary': separator,
            if (challengeResponseHeader != null && challengeResponseHeader.isNotEmpty)
              ApiConst.xChallengeResponse: challengeResponseHeader,
          },
          validateStatus: (status) => status == 200 || status == 202 || status == 207 || status == 417,
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
