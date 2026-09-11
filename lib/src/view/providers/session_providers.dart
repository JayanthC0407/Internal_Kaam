import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/session/session_manager.dart';
import 'package:ubci_bank/src/view/providers/network_providers.dart';

final preferenceHelperProvider = Provider(
  (_) => PreferenceHelper.getInstance(),
);

final sessionManagerProvider = Provider(
  (ref) => SessionManager(
    ref.watch(preferenceHelperProvider),
    authApi: ref.watch(obdxAuthApiProvider),
    userApi: ref.watch(obdxUserApiProvider),
  ),
);
