import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/account_settings/account_settings_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/preferences_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';

/// Session Summary, Alerts Subscription and Change Password. autoDispose:
/// loaded while the section is open. Failures surface as
/// [PreferencesLoadError], so the Preferences error widgets show them.

T _unwrap<T>(ResponseHandler<T> result) {
  if (result is Success<T> && result.data != null) return result.data as T;
  throw PreferencesLoadError(result is Error<T> ? result.error : null);
}

final userSessionsProvider = FutureProvider.autoDispose<List<UserSession>>(
  (ref) async => _unwrap(await ref.read(accountSettingsRepositoryProvider).fetchSessions()),
);

/// What happened in one session; read when its row is expanded.
final sessionActivityProvider = FutureProvider.autoDispose.family<List<SessionActivity>, String>(
  (ref, sessionId) async => _unwrap(await ref.read(accountSettingsRepositoryProvider).fetchSessionActivity(sessionId)),
);

final passwordPolicyProvider = FutureProvider.autoDispose<PasswordPolicy>(
  (ref) async => _unwrap(await ref.read(accountSettingsRepositoryProvider).fetchPasswordPolicy()),
);

/// The user strip on Alerts Subscription, and who alerts are saved for.
final alertsUserProvider = FutureProvider.autoDispose<AlertsUser>(
  (ref) async => _unwrap(await ref.read(accountSettingsRepositoryProvider).fetchUser()),
);

final alertModulesProvider = FutureProvider.autoDispose<List<AlertModule>>(
  (ref) async => _unwrap(await ref.read(accountSettingsRepositoryProvider).fetchModules()),
);

final alertEventsProvider = FutureProvider.autoDispose<List<AlertEvent>>(
  (ref) async => _unwrap(await ref.read(accountSettingsRepositoryProvider).fetchEvents()),
);

final alertSubscriptionsProvider = FutureProvider.autoDispose<List<AlertSubscription>>((ref) async {
  final user = await ref.watch(alertsUserProvider.future);
  return _unwrap(await ref.read(accountSettingsRepositoryProvider).fetchSubscriptions(user));
});

/// A module's accounts (by module id), or the party for party-level
/// modules.
final alertTargetsProvider = FutureProvider.autoDispose.family<List<AlertTarget>, String>((ref, moduleId) async {
  final user = await ref.watch(alertsUserProvider.future);
  final modules = await ref.watch(alertModulesProvider.future);
  final module = modules.firstWhere((m) => m.id == moduleId);
  return _unwrap(await ref.read(accountSettingsRepositoryProvider).fetchTargets(user, module));
});
