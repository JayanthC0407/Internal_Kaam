import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/limits/my_limits_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';

/// My Limits (docs/obdx/features/my-limits.md). autoDispose: loaded while
/// the screen is open, dropped afterwards and on logout.

/// Channel list (`accessPoints?accessType=INT&accessPointStatus=Y`).
final limitChannelsProvider = FutureProvider.autoDispose<List<LimitChannel>>((ref) async {
  final result = await ref.read(limitsRepositoryProvider).fetchChannels();
  if (result is Success<List<LimitChannel>> && result.data != null) return result.data!;
  throw LimitsLoadError(result is Error<List<LimitChannel>> ? result.error : null);
});

/// Transactions list (`resourceTasks?aspects=limit&view=list`).
final limitTransactionsProvider = FutureProvider.autoDispose<List<LimitTransaction>>((ref) async {
  final result = await ref.read(limitsRepositoryProvider).fetchTransactions();
  if (result is Success<List<LimitTransaction>> && result.data != null) return result.data!;
  throw LimitsLoadError(result is Error<List<LimitTransaction>> ? result.error : null);
});

/// Limits, custom limits and utilisation for one channel id.
final myLimitsProvider = FutureProvider.autoDispose.family<MyLimits, String>((ref, channelId) async {
  final result = await ref.read(limitsRepositoryProvider).fetchMyLimits(channelId);
  if (result is Success<MyLimits> && result.data != null) return result.data!;
  throw LimitsLoadError(result is Error<MyLimits> ? result.error : null);
});

/// Load failure; [message] is OBDX's text when the server sent one.
class LimitsLoadError implements Exception {
  const LimitsLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'LimitsLoadError';
}
