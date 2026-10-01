import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Cash-management APIs behind the `pickup-point-collections` dashboard
/// widget (Home widgets capture, entries #45/#46 and #51).
///
/// These endpoints take a digx-style JSON criteria filter in a single
/// `queryParams` / `q` query parameter rather than discrete parameters —
/// [buildCriteria] assembles it in the shape the capture shows.
class ObdxCorpCashManagementApi extends ObdxApiBase {
  ObdxCorpCashManagementApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  /// `{"criteria":[{"operand":…,"operator":…,"value":[…]}]}` — the filter
  /// shape digx-ui sends. Dio encodes the JSON once, matching the capture.
  static String buildCriteria(List<Map<String, dynamic>> criteria) {
    return jsonEncode({'criteria': criteria});
  }

  /// `GET …/cashmanagement/collections/maintenances/pickupAndDeliveryPoints`
  ///
  /// The capture filters `serviceType EQUALS P` plus one `collection` type,
  /// and calls the endpoint once per type.
  Future<ResponseHandler<Map<String, dynamic>>> fetchPickupPoints({
    required String collectionType,
    String serviceType = 'P',
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(CorpApiConst.pickupAndDeliveryPointsApi),
        queryParameters: {
          'queryParams': buildCriteria([
            {
              'operand': 'serviceType',
              'operator': 'EQUALS',
              'value': [serviceType],
            },
            {
              'operand': 'collection',
              'operator': 'EQUALS',
              'value': [collectionType],
            },
          ]),
        },
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

  /// `GET /digx-cms/cms/v1/aggregator/resource/cheques` — cheque collection
  /// amounts grouped by pickup point, for [from]..[to].
  ///
  /// Returned `aggregatedData` is empty for the captured party, so callers
  /// must render without it rather than treating empty as a failure.
  Future<ResponseHandler<Map<String, dynamic>>> fetchChequeAggregate({
    required DateTime from,
    required DateTime to,
    bool localCurrencyOnly = true,
    String data = 'Amount',
    String grouping = 'PickupPoint',
  }) async {
    String isoDate(DateTime value) =>
        value.toIso8601String().split('T').first;

    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(CorpApiConst.chequeAggregatorApi),
        queryParameters: {
          'data': data,
          'grouping': grouping,
          'q': buildCriteria([
            {
              'operand': 'localCurrency',
              'operator': 'EQUALS',
              'value': [localCurrencyOnly],
            },
            {
              'operand': 'chequeDate',
              'operator': 'BETWEEN',
              'value': [isoDate(from), isoDate(to)],
            },
          ]),
        },
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

  /// `GET …/cashmanagement/collections/{transactionType}` — collections of
  /// one type, grouped by [interval] (`D` day, `M` month) over
  /// [from]..[to], oldest first. The filter and sort are the JSON the
  /// widgets capture sends.
  Future<ResponseHandler<Map<String, dynamic>>> fetchCashCollections({
    required String transactionType,
    required String interval,
    required DateTime from,
    required DateTime to,
  }) async {
    String isoDate(DateTime value) =>
        value.toIso8601String().split('T').first;

    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(
          CorpApiConst.cashCollectionsApi(transactionType),
        ),
        queryParameters: {
          'queryParams': buildCriteria([
            {
              'operand': 'interval',
              'operator': 'ENUM',
              'value': [interval],
            },
            {
              'operand': 'date',
              'operator': 'BETWEEN',
              'value': [isoDate(from), isoDate(to)],
            },
          ]),
          'sortBy': jsonEncode([
            {'sortBy': 'date', 'sortOrder': 'ASC'},
          ]),
        },
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
