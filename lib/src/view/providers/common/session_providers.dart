import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/session/session_manager.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';
import 'package:ubci_bank/src/view/providers/common/user_session_state_reset.dart';

final preferenceHelperProvider = Provider(
  (_) => PreferenceHelper.getInstance(),
);

final sessionManagerProvider = Provider(
  (ref) => SessionManager(
    ref.watch(preferenceHelperProvider),
    authApi: ref.watch(obdxAuthApiProvider),
    userApi: ref.watch(obdxUserApiProvider),
    onSessionCleared: () async {
      resetUserSessionState(ref);
    },
  ),
);

/// Application-level session lifecycle facade.
///
/// Keep logout/forget-device flows going through this provider when a caller
/// needs an explicit UI/session-state boundary. SessionManager itself also
/// invokes the same reset callback, so direct SessionManager users remain safe.
final sessionLifecycleProvider = Provider<SessionLifecycle>(
  (ref) => SessionLifecycle(ref),
);

class SessionLifecycle {
  SessionLifecycle(this._ref);

  final Ref _ref;

  Future<void> logout() => _ref.read(sessionManagerProvider).logout();

  Future<void> forgetDevice() =>
      _ref.read(sessionManagerProvider).forgetDevice();

  void clearUserScopedUiState() => resetUserSessionState(_ref);
}
