import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/providers/common/preferences_providers.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';

/// The blocks of OBDX's `security/generic-settings`, placed where a user
/// looks for them:
///  - [RegisteredDevicesSettings] (Registered Phones/Tablets, Registered
///    Wearable) in Security & Login;
///  - [NotificationSettings] (Push Notification, Preferred Delivery Mode
///    (Only for OTP)) in Notifications & Alerts;
///  - [PrivacySettings] (Feedback Preferences, Live Help) in Privacy &
///    Consents.
/// Every change saves at once, as in OBDX: a device switch can only be
/// turned off (`DELETE mobileClient/…/os/{os}`); the rest `PUT`
/// userPreferences.

/// The control being saved, and the writes the blocks share.
mixin _SettingsWrites<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String? busy;

  /// This device's OS key, to drop the local alternate login when its
  /// registration is removed (OBDX clears its own preference the same way).
  String? get _thisOs {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => DeviceOs.android,
      TargetPlatform.iOS => DeviceOs.ios,
      _ => null,
    };
  }

  Future<void> unregisterDevices(String os) async {
    setState(() => busy = 'device-$os');
    final repo = ref.read(preferencesRepositoryProvider);
    final result = await runPrefWrite(context, (c, otp) => repo.unregisterDevices(os, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => busy = null);
    if (prefReportWrite(context, result) && os == _thisOs) {
      await ref.read(preferenceHelperProvider).clearBiometricSecrets();
    }
    ref.invalidate(registeredDevicesProvider);
  }

  Future<void> unregisterPush(String os) async {
    setState(() => busy = 'push-$os');
    final repo = ref.read(preferencesRepositoryProvider);
    final result = await runPrefWrite(context, (c, otp) => repo.unregisterPush(os, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => busy = null);
    prefReportWrite(context, result);
    ref.invalidate(pushTokensProvider);
  }

  Future<void> updatePreference(UserPreferences prefs, String key, Object? value) async {
    setState(() => busy = key);
    final repo = ref.read(preferencesRepositoryProvider);
    final result = await runPrefWrite(context, (c, otp) => repo.updateUserPreferences(prefs.withValue(key, value), challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => busy = null);
    prefReportWrite(context, result);
    ref.invalidate(userPreferencesProvider);
  }

  /// A device switch: on while any are registered, and only turns off.
  Widget deviceSwitch(String label, DeviceCounts counts, String os, String prefix, Future<void> Function(String) off) {
    final on = counts.of(os) > 0;
    return PrefSwitchRow(
      label: label,
      value: on,
      busy: busy == '$prefix-$os',
      onChanged: on && busy == null
          ? (v) {
              if (!v) off(os);
            }
          : null,
    );
  }

  Widget asyncBlock<V>(AsyncValue<V> value, VoidCallback retry, Widget Function(V) data) => value.when(
        loading: () => const PrefLoading(),
        error: (e, _) => PrefFailed(error: e, onRetry: retry),
        data: data,
      );
}

/// Registered Phones/Tablets and Registered Wearable.
class RegisteredDevicesSettings extends ConsumerStatefulWidget {
  const RegisteredDevicesSettings({super.key});

  @override
  ConsumerState<RegisteredDevicesSettings> createState() => _RegisteredDevicesSettingsState();
}

class _RegisteredDevicesSettingsState extends ConsumerState<RegisteredDevicesSettings> with _SettingsWrites {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return asyncBlock<DeviceCounts>(
      ref.watch(registeredDevicesProvider),
      () => ref.invalidate(registeredDevicesProvider),
      (d) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrefBlock(
            title: l10n.prefRegisteredDevices,
            icon: Icons.phone_android_rounded,
            note: l10n.prefRegisteredDevicesNote,
            children: [
              deviceSwitch(l10n.prefAndroidDevices, d, DeviceOs.android, 'device', unregisterDevices),
              deviceSwitch(l10n.prefIosDevices, d, DeviceOs.ios, 'device', unregisterDevices),
            ],
          ),
          const SizedBox(height: 14),
          PrefBlock(
            title: l10n.prefRegisteredWearable,
            icon: Icons.watch_outlined,
            note: l10n.prefRegisteredWearableNote,
            children: [
              deviceSwitch(l10n.prefAndroidDevices, d, DeviceOs.androidWear, 'device', unregisterDevices),
              deviceSwitch(l10n.prefIosDevices, d, DeviceOs.iosWear, 'device', unregisterDevices),
            ],
          ),
        ],
      ),
    );
  }
}

/// Push Notification and Preferred Delivery Mode (Only for OTP).
class NotificationSettings extends ConsumerStatefulWidget {
  const NotificationSettings({super.key});

  @override
  ConsumerState<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<NotificationSettings> with _SettingsWrites {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        asyncBlock<DeviceCounts>(
          ref.watch(pushTokensProvider),
          () => ref.invalidate(pushTokensProvider),
          (p) => PrefBlock(
            title: l10n.prefPushNotification,
            icon: Icons.notifications_active_outlined,
            note: l10n.prefPushNotificationNote,
            children: [
              deviceSwitch(l10n.prefAndroidDevices, p, DeviceOs.android, 'push', unregisterPush),
              deviceSwitch(l10n.prefIosDevices, p, DeviceOs.ios, 'push', unregisterPush),
              deviceSwitch(l10n.prefWebBrowser, p, DeviceOs.browser, 'push', unregisterPush),
            ],
          ),
        ),
        const SizedBox(height: 14),
        asyncBlock<UserPreferences>(
          ref.watch(userPreferencesProvider),
          () => ref.invalidate(userPreferencesProvider),
          (u) => PrefBlock(
            title: l10n.prefOtpDeliveryMode,
            icon: Icons.password_rounded,
            note: l10n.prefOtpDeliveryNote,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l10n.prefDispatchMethod),
              ),
              for (final (mode, label) in [('SMS', l10n.prefSms), ('EMAIL', l10n.prefEmail), ('BOTH', l10n.prefBoth)])
                PrefRadio<String>(
                  value: mode,
                  group: u.otpDeliveryMode,
                  label: label,
                  onChanged: busy == null && mode != u.otpDeliveryMode ? (v) => updatePreference(u, 'otpDeliveryMode', v) : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Feedback Preferences and Live Help.
class PrivacySettings extends ConsumerStatefulWidget {
  const PrivacySettings({super.key});

  @override
  ConsumerState<PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends ConsumerState<PrivacySettings> with _SettingsWrites {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return asyncBlock<UserPreferences>(
      ref.watch(userPreferencesProvider),
      () => ref.invalidate(userPreferencesProvider),
      (u) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrefBlock(
            title: l10n.prefFeedbackPreferences,
            icon: Icons.rate_review_outlined,
            note: l10n.prefFeedbackNote,
            children: [
              PrefSwitchRow(
                label: l10n.prefFeedbackPreferences,
                value: u.feedbackEnabled,
                busy: busy == 'feedbackEnabled',
                onChanged: busy == null ? (v) => updatePreference(u, 'feedbackEnabled', v) : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrefBlock(
            title: l10n.prefLiveHelp,
            icon: Icons.support_agent_rounded,
            note: l10n.prefLiveHelpNote,
            children: [
              PrefSwitchRow(
                label: l10n.prefLiveHelp,
                value: u.liveExpEnabled,
                busy: busy == 'liveExpEnabled',
                onChanged: busy == null ? (v) => updatePreference(u, 'liveExpEnabled', v) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
