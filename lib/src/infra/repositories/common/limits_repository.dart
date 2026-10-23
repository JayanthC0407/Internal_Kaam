import 'package:ubci_bank/src/core/models/common/limits/my_limits_models.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_limits_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// My Limits — parses [ObdxLimitsApi] responses into
/// `my_limits_models.dart` (docs/obdx/features/my-limits.md).
class LimitsRepository extends ObdxRepositoryBase {
  LimitsRepository({required ObdxLimitsApi api}) : _api = api;

  final ObdxLimitsApi _api;

  Future<ResponseHandler<List<LimitChannel>>> fetchChannels() async =>
      parseBody(await _api.fetchChannels(), LimitChannel.listFromPayload);

  Future<ResponseHandler<List<LimitTransaction>>> fetchTransactions() async =>
      parseBody(await _api.fetchLimitTransactions(), LimitTransaction.listFromPayload);

  /// The five calls OBDX runs together for a channel (hooks.js:428-436),
  /// plus `effectiveToday`. Like OBDX's `Promise.all`, one failure fails the
  /// load; only `effectiveToday` may fail (OBDX then leaves the flag unset).
  Future<ResponseHandler<MyLimits>> fetchMyLimits(String channelId, {DateTime? today}) async {
    final results = await Future.wait([
      _body(_api.fetchTaskGroups()),
      _body(_api.fetchMyAssignedLimits(channelId)),
      _body(_api.fetchUtilization(channelId, 'DAILY')),
      _body(_api.fetchUtilization(channelId, 'MONTHLY')),
      _body(_api.fetchMyCustomLimits(channelId)),
      _body(_api.fetchEffectiveToday()),
    ]);
    for (final r in results.take(5)) {
      if (r is! Success<Map<String, dynamic>>) return mapFailure(r);
    }
    Map<String, dynamic> body(int i) => (results[i] as Success<Map<String, dynamic>>).data!;
    final config = results[5];
    try {
      return ResponseHandler.success(
        MyLimits.fromPayloads(
          taskGroups: body(0),
          assigned: body(1),
          utilizedDaily: body(2),
          utilizedMonthly: body(3),
          custom: body(4),
          effectiveSameDay: config is Success<Map<String, dynamic>> && config.data!['isEffectiveSameDay'] == 'Y',
          today: today ?? DateTime.now(),
        ),
        code: 200,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// [parseBody] without a model: the checked body itself.
  Future<ResponseHandler<Map<String, dynamic>>> _body(Future<ResponseHandler<Map<String, dynamic>>> call) async =>
      parseBody(await call, (b) => b);
}
