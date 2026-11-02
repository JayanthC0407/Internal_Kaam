import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Credit Facility Management (corporate). `apiType: creditfacility` has no
/// domain, so every call is `/digx-creditfacility/v1/…` (api-catalogue.js
/// 251-255). Queries are sent as OBDX sends them, including the hard-coded
/// `currencyCode=INR` and an empty `partyId=` (card §2, user decision
/// 2026-10-31). All reads; no writes here.
class ObdxCorpCreditFacilityApi extends ObdxApiBase {
  ObdxCorpCreditFacilityApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _cf = '/digx-creditfacility/v1';

  /// `GET liabilities`, with `partyId` only when OBDX passes one
  /// (Facility Summary passes the selected party, even when empty).
  Future<ResponseHandler<Map<String, dynamic>>> fetchLiabilities({String? partyId}) =>
      _get('$_cf/liabilities', {if (partyId != null) 'partyId': partyId});

  /// `GET liabilities/{id}/facilities?partyId&branchCode&currencyCode`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchFacilities(String liabilityId,
          {required String partyId, String? branchCode, String currencyCode = 'INR'}) =>
      _get('$_cf/liabilities/${Uri.encodeComponent(liabilityId)}/facilities',
          {'partyId': partyId, 'branchCode': branchCode ?? '', 'currencyCode': currencyCode});

  /// Facility Summary's Download: the same list as a PDF.
  Future<ResponseHandler<List<int>>> downloadFacilities(String liabilityId,
          {required String partyId, String? branchCode, String currencyCode = 'INR'}) =>
      _pdf('$_cf/liabilities/${Uri.encodeComponent(liabilityId)}/facilities',
          {'partyId': partyId, 'branchCode': branchCode ?? '', 'currencyCode': currencyCode});

  /// `GET liabilities/{id}/facilities/{lineCode_lineSerialNumber}` → `facilityDTO`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchFacility(String liabilityId, String facilityKey) =>
      _get('$_cf/liabilities/${Uri.encodeComponent(liabilityId)}/facilities/${Uri.encodeComponent(facilityKey)}');

  /// Transaction Summary: `…/facilities/{key}/utilization[?fromDate&toDate]`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchUtilization(String liabilityId, String facilityKey,
          {String? fromDate, String? toDate}) =>
      _get(_utilization(liabilityId, facilityKey), {
        if (fromDate != null) 'fromDate': fromDate,
        if (toDate != null) 'toDate': toDate,
      });

  Future<ResponseHandler<List<int>>> downloadUtilization(String liabilityId, String facilityKey,
          {String? fromDate, String? toDate}) =>
      _pdf(_utilization(liabilityId, facilityKey), {
        if (fromDate != null) 'fromDate': fromDate,
        if (toDate != null) 'toDate': toDate,
      });

  /// `GET liabilities/{id}/collaterals?partyId&branchCode&currencyCode`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollaterals(String liabilityId,
          {required String partyId, String? branchCode, String currencyCode = 'INR'}) =>
      _get('$_cf/liabilities/${Uri.encodeComponent(liabilityId)}/collaterals',
          {'partyId': partyId, 'branchCode': branchCode ?? '', 'currencyCode': currencyCode});

  /// `GET liabilities/{id}/collateralgroups?partyId&branchCode&currencyCode`
  /// → `collateralgroupdtos[]` (Collateral Summary).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollateralGroups(String liabilityId,
          {required String partyId, String? branchCode, String currencyCode = 'INR'}) =>
      _get('$_cf/liabilities/${Uri.encodeComponent(liabilityId)}/collateralgroups',
          {'partyId': partyId, 'branchCode': branchCode ?? '', 'currencyCode': currencyCode});

  /// `GET liabilities/{id}/collaterals/{collateralId}` → `collateralDTO`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollateral(String liabilityId, String collateralId) =>
      _get('$_cf/liabilities/${Uri.encodeComponent(liabilityId)}/collaterals/${Uri.encodeComponent(collateralId)}');

  /// `GET liabilities/{id}/collateralgroups/{poolId}` → `collateralGroupDTO`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCollateralGroup(String liabilityId, String poolId) =>
      _get('$_cf/liabilities/${Uri.encodeComponent(liabilityId)}/collateralgroups/${Uri.encodeComponent(poolId)}');

  /// Selected Party: `user me/party`, then `me/party/relations`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchParty() => _get('/digx-common/user/v1/me/party');

  Future<ResponseHandler<Map<String, dynamic>>> fetchPartyRelations() =>
      _get('/digx-common/user/v1/me/party/relations');

  /// The filter's Currency list: `common currency` (no `moduleType`).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCurrencies() => _get('/digx-common/common/v1/currency');

  /// "Group Corporate Id": `gcif groupCorporates/{id}` → `groupCorporate.name`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchGroupCorporate(String id) =>
      _get('/digx-admin/gcif/v1/groupCorporates/${Uri.encodeComponent(id)}');

  String _utilization(String liabilityId, String facilityKey) =>
      '$_cf/liabilities/${Uri.encodeComponent(liabilityId)}/facilities/${Uri.encodeComponent(facilityKey)}/utilization';

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

  /// OBDX `downloadFile` with `media=application/pdf`.
  Future<ResponseHandler<List<int>>> _pdf(String path, Map<String, dynamic> query) async {
    const media = 'application/pdf';
    try {
      final response = await dio.get<List<int>>(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: {...query, 'media': media},
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
}
