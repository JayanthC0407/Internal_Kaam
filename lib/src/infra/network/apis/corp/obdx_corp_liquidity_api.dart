import 'package:dio/dio.dart';
import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Liquidity Management (corporate). `apiType: liquiditymanagement` has no
/// domain, so every call is `/digx-liquiditymanagement/v1/…`
/// (api-catalogue.js 201-205). All reads; no writes here.
class ObdxCorpLiquidityApi extends ObdxApiBase {
  ObdxCorpLiquidityApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _lm = '/digx-liquiditymanagement/v1';

  /// Charge Description options: `charges/definitions` (limit, offset and
  /// q are unset in OBDX, so none is sent).
  Future<ResponseHandler<Map<String, dynamic>>> fetchChargeDefinitions() => _get('$_lm/charges/definitions');

  /// Collection Status options.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollectionStatuses() =>
      _get('$_lm/enumerations/fetchLMChargeCollectionStatus');

  /// `maintenances` → `configurationDetails[]` (LM_CHARGE_INQUIRY_MAX_PERIOD).
  Future<ResponseHandler<Map<String, dynamic>>> fetchMaintenances() => _get('$_lm/maintenances');

  /// Search: `charges[?q=…]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCharges(String? q) =>
      _get('$_lm/charges', {if (q != null) 'q': q});

  /// Download: the same query with `media=text/csv&mediaFormat=csv`.
  Future<ResponseHandler<List<int>>> downloadCharges(String? q) =>
      _file('$_lm/charges', {if (q != null) 'q': q, 'media': 'text/csv', 'mediaFormat': 'csv'}, 'text/csv');

  Future<ResponseHandler<List<int>>> _file(String path, Map<String, dynamic> query, String media) async {
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: query,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Accept': '$media, application/octet-stream, application/json, */*'},
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

  // ---------------------------------------------------------------- Overview
  //
  // The widgets' queries are passed in as OBDX builds them, including the
  // literal `null` values (card §3): each widget sends its own set.

  /// `liquidityManagement/accounts?…`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccounts(Map<String, String> query) =>
      _get('$_lm/liquidityManagement/accounts', query);

  /// `liquidityManagement/currencies[?…]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCurrencies([Map<String, String>? query]) =>
      _get('$_lm/liquidityManagement/currencies', query);

  /// `common bankConfiguration` (the default currency).
  Future<ResponseHandler<Map<String, dynamic>>> fetchBankConfiguration() =>
      _get('/digx-common/common/v1/bankConfiguration');

  /// `user me/party[?…]` (Party Name).
  Future<ResponseHandler<Map<String, dynamic>>> fetchParty([Map<String, String>? query]) =>
      _get('/digx-common/user/v1/me/party', query);

  /// `liquidityManagement/structures?…` (Structure Details).
  Future<ResponseHandler<Map<String, dynamic>>> fetchStructures(Map<String, String> query) =>
      _get('$_lm/liquidityManagement/structures', query);

  /// `liquidityManagement/structures/sweeplogs?…`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchSweepLogs(Map<String, String> query) =>
      _get('$_lm/liquidityManagement/structures/sweeplogs', query);

  /// Sweep Monitor's Download: the same query with `media` / `mediaFormat`.
  Future<ResponseHandler<List<int>>> downloadSweepLogs(Map<String, String> query,
          {required String media, required String mediaFormat}) =>
      _file('$_lm/liquidityManagement/structures/sweeplogs', {...query, 'media': media, 'mediaFormat': mediaFormat}, media);

  /// FX rates: `POST /digx-common/batch` (`apiType forexdeal`, url `batch`;
  /// api-catalogue.js 181-185), one `GET /forex/rates` part each. Reads only.
  Future<ResponseHandler<Map<String, dynamic>>> fetchRates(List<ObdxBatchItem> items, {String? boundary}) async {
    try {
      final separator = boundary ?? ObdxBatchEncoder.newBoundary();
      final contentType = 'multipart/form-data; boundary=$separator';
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery('/digx-common/batch'),
        data: ObdxBatchEncoder.encode(items, separator),
        options: Options(
          contentType: contentType,
          headers: {ApiConst.contentTypeKey: contentType, 'boundary': separator},
          validateStatus: (status) => status == 200 || status == 207,
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
