import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/view/providers/common/app_settings_providers.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';

/// The app's language choice, shared by the dashboard top bar and the Menu
/// tab (Languages tile, App Settings → Language). Saves through
/// [appSettingsProvider], so every screen rebuilds in the new locale.
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final selected = await AppBottomSheet.pick<String>(
    context: context,
    title: l10n.language,
    selected: ref.read(appSettingsProvider).locale.languageCode,
    options: LocaleConfig.supportedLanguageCodes
        .map(
          (code) => (
            value: code,
            label: LocaleConfig.displayName(l10n, code),
          ),
        )
        .toList(),
  );
  if (selected == null || !context.mounted) return;
  await ref.read(appSettingsProvider.notifier).setLocale(Locale(selected));
}
