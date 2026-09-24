import 'package:ubci_bank/src/core/models/corp/corp_pickup_point.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_cash_management_api.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_api_constants.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

class CorpCashManagementRepository extends CorpRepositoryBase {
  CorpCashManagementRepository({
    required ObdxCorpCashManagementApi cashManagementApi,
  }) : _api = cashManagementApi;

  final ObdxCorpCashManagementApi _api;

  /// Pickup and delivery points across every collection type, merged the
  /// way digx-ui does it — one request per type, results concatenated.
  ///
  /// A type that fails is skipped rather than failing the whole widget:
  /// a party may be set up for cash collection but not paper-based, and
  /// showing the half we have beats showing an error. Only when *every*
  /// request fails does this surface the failure.
  Future<ResponseHandler<List<CorpPickupPoint>>> fetchPickupPoints({
    List<String> collectionTypes = CorpApiConst.pickupCollectionTypes,
  }) async {
    try {
      final merged = <CorpPickupPoint>[];
      final seen = <String>{};
      ResponseHandler<dynamic>? lastFailure;
      var anySucceeded = false;

      for (final type in collectionTypes) {
        final result = await _api.fetchPickupPoints(collectionType: type);
        final parsed = await parseBody(
          result,
          (body) => CorpPickupPoint.listFromPayload(body, collectionType: type),
        );

        if (parsed is! Success<List<CorpPickupPoint>>) {
          lastFailure = parsed;
          continue;
        }
        anySucceeded = true;
        for (final point in parsed.data ?? const <CorpPickupPoint>[]) {
          // The same physical point can be returned for more than one
          // collection type; key on both so it is listed once per type
          // but never twice for the same one.
          final key = '${point.collectionType}::${point.code}';
          if (seen.add(key)) merged.add(point);
        }
      }

      if (!anySucceeded && lastFailure != null) {
        return mapFailure<List<CorpPickupPoint>>(lastFailure);
      }
      return ResponseHandler.success(merged, code: 200);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }
}
