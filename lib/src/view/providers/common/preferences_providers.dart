import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/models/common/security_question.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';

/// Account Settings → Preferences. autoDispose: loaded while a section is
/// open, dropped afterwards and on logout. Writes invalidate what they
/// change.

T _unwrap<T>(ResponseHandler<T> result) {
  if (result is Success<T> && result.data != null) return result.data as T;
  throw PreferencesLoadError(result is Error<T> ? result.error : null);
}

/// `me/party` + `profileConfig`.
final partyProfileProvider = FutureProvider.autoDispose<PartyProfile>(
  (ref) async => _unwrap(await ref.read(preferencesRepositoryProvider).fetchProfile()),
);

/// `enumerations/country`, for the address editor.
final profileCountriesProvider = FutureProvider.autoDispose<List<ProfileCountry>>(
  (ref) async => _unwrap(await ref.read(preferencesRepositoryProvider).fetchCountries()),
);

/// `userPreferences` — Primary Account, Third Party Applications, Settings.
final userPreferencesProvider = FutureProvider.autoDispose<UserPreferences>(
  (ref) async => _unwrap(await ref.read(preferencesRepositoryProvider).fetchUserPreferences()),
);

/// The user's external apps, from their `userAccessPointRelationship`.
final thirdPartyAppsProvider = FutureProvider.autoDispose<List<ThirdPartyApp>>((ref) async {
  final prefs = await ref.watch(userPreferencesProvider.future);
  return _unwrap(await ref.read(preferencesRepositoryProvider).fetchThirdPartyApps(prefs));
});

/// Accounts and tasks mapped to one app.
final consentSetupProvider = FutureProvider.autoDispose.family<ConsentSetup, String>(
  (ref, accessPointId) async => _unwrap(await ref.read(preferencesRepositoryProvider).fetchConsentSetup(accessPointId)),
);

/// The questions the user has set; empty → "have not been setup yet".
final userSecurityQuestionsProvider = FutureProvider.autoDispose<List<UserSecurityQuestion>>(
  (ref) async => _unwrap(await ref.read(preferencesRepositoryProvider).fetchUserSecurityQuestions()),
);

/// The bank's question list and how many to answer.
final securityQuestionSetupProvider = FutureProvider.autoDispose<({List<SecurityQuestionOption> catalog, int count})>((ref) async {
  final repo = ref.read(preferencesRepositoryProvider);
  final results = await Future.wait([repo.fetchSecurityQuestionCatalog(), repo.fetchSecurityQuestionCount()]);
  return (
    catalog: _unwrap(results[0] as ResponseHandler<List<SecurityQuestionOption>>),
    count: results[1] as int,
  );
});

final smsBankingProvider = FutureProvider.autoDispose<SmsBankingRegistration>(
  (ref) async => _unwrap(await ref.read(preferencesRepositoryProvider).fetchSmsBanking()),
);

final registeredDevicesProvider = FutureProvider.autoDispose<DeviceCounts>(
  (ref) async => _unwrap(await ref.read(preferencesRepositoryProvider).fetchRegisteredDevices()),
);

final pushTokensProvider = FutureProvider.autoDispose<DeviceCounts>(
  (ref) async => _unwrap(await ref.read(preferencesRepositoryProvider).fetchPushTokens()),
);

/// Load failure; [message] is OBDX's text when the server sent one.
class PreferencesLoadError implements Exception {
  const PreferencesLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'PreferencesLoadError';
}
