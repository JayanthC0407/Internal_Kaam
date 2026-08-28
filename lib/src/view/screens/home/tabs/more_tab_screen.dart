import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';
import 'package:ubci_bank/src/view/widgets/biometric_enrollment_prompt.dart';
import 'package:ubci_bank/src/view/widgets/biometric_ui_copy.dart';

import '../home_colors.dart';

class MoreTabScreen extends ConsumerStatefulWidget {
  const MoreTabScreen({super.key});

  @override
  ConsumerState<MoreTabScreen> createState() => _MoreTabScreenState();
}

class _MoreTabScreenState extends ConsumerState<MoreTabScreen> {
  bool? _biometricEnabled;
  bool? _biometricAvailable;
  BiometricPresentation _biometricPresentation = BiometricPresentation.android;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final enrollment = ref.read(biometricEnrollmentProvider);
    final enabled = await enrollment.isEnabled();
    final available = !kIsWeb;
    final presentation = available
        ? await ref.read(biometricServiceProvider).presentation()
        : BiometricPresentation.android;
    if (!mounted) return;
    setState(() {
      _biometricEnabled = enabled;
      _biometricAvailable = available;
      _biometricPresentation = presentation;
    });
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() action,
    bool destructive = false,
  }) async {
    final confirmed = await AppBottomSheet.confirm(
      context,
      title: title,
      message: message,
      destructive: destructive,
    );

    if (!confirmed || !context.mounted) return;
    await action();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RoutesConst.loginScreen,
      (route) => false,
    );
  }

  Future<void> _onBiometricToggle(bool value) async {
    if (value) {
      await BiometricEnrollmentPrompt.enableFromSettings(context, ref);
    } else {
      await BiometricEnrollmentPrompt.disableFromSettings(context, ref);
    }
    await _loadBiometricState();
  }

  Future<void> _pickTheme(ThemeMode current) async {
    final l10n = AppLocalizations.of(context);
    final selected = await AppBottomSheet.pick<ThemeMode>(
      context: context,
      title: l10n.theme,
      selected: current,
      options: [
        (value: ThemeMode.light, label: l10n.lightTheme),
        (value: ThemeMode.dark, label: l10n.darkTheme),
      ],
    );
    if (selected == null || !mounted) return;
    await ref.read(appSettingsProvider.notifier).setThemeMode(selected);
  }

  Future<void> _pickLanguage(Locale current) async {
    final l10n = AppLocalizations.of(context);
    final selected = await AppBottomSheet.pick<String>(
      context: context,
      title: l10n.language,
      selected: current.languageCode,
      options: LocaleConfig.supportedLanguageCodes
          .map(
            (code) => (
              value: code,
              label: LocaleConfig.displayName(l10n, code),
            ),
          )
          .toList(),
    );
    if (selected == null || !mounted) return;
    await ref.read(appSettingsProvider.notifier).setLocale(Locale(selected));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final currentThemeMode = settings.themeMode;
    final currentLocale = settings.locale;
    final session = ref.read(sessionManagerProvider);
    final themeLabel =
        currentThemeMode == ThemeMode.dark ? l10n.darkTheme : l10n.lightTheme;
    final languageLabel =
        LocaleConfig.displayName(l10n, currentLocale.languageCode);
    final biometricHelper = BiometricUiCopy.helperText(
      l10n,
      _biometricPresentation,
    );
    final responsive = Responsive.of(context);
    final textPrimary = HomeColors.textPrimary(context);
    final textSecondary = HomeColors.textSecondary(context);
    final brand = HomeColors.brand(context);
    final divider = HomeColors.divider(context);

    return SafeArea(
      child: ResponsiveBody(
        maxWidth: responsive.formMaxWidth + 80,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            responsive.isPhone ? 20 : 24,
            16,
            responsive.isPhone ? 20 : 24,
            24,
          ),
          children: [
            Text(
              l10n.moreTitle,
              style: TextStyle(
                fontSize: responsive.fontScale(phone: 28, tablet: 32),
                fontWeight: FontWeight.w700,
                color: textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            _SettingsCard(
              children: [
                _SettingsNavTile(
                  icon: Icons.palette_outlined,
                  title: l10n.theme,
                  value: themeLabel,
                  onTap: () => _pickTheme(currentThemeMode),
                ),
                _SettingsNavTile(
                  icon: Icons.language_rounded,
                  title: l10n.language,
                  value: languageLabel,
                  onTap: () => _pickLanguage(currentLocale),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    l10n.security,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (_biometricAvailable == true) ...[
                  SwitchListTile(
                    secondary: Icon(
                      BiometricUiCopy.icon(_biometricPresentation),
                      color: brand,
                    ),
                    title: Text(
                      BiometricUiCopy.enableLabel(
                        l10n,
                        _biometricPresentation,
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: biometricHelper == null
                        ? null
                        : Text(
                            biometricHelper,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                    value: _biometricEnabled ?? false,
                    activeThumbColor: brand,
                    onChanged: (value) => _onBiometricToggle(value),
                  ),
                  Divider(height: 1, indent: 56, color: divider),
                ],
                ListTile(
                  leading: Icon(Icons.logout, color: brand),
                  title: Text(
                    l10n.logOut,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  onTap: () => _confirmAndRun(
                    context,
                    title: l10n.logOut,
                    message: l10n.logOutConfirm,
                    action: session.logout,
                  ),
                ),
                Divider(height: 1, indent: 56, color: divider),
                ListTile(
                  leading: Icon(
                    Icons.phonelink_erase,
                    color: brand,
                  ),
                  title: Text(
                    l10n.forgetDevice,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  onTap: () => _confirmAndRun(
                    context,
                    title: l10n.forgetDevice,
                    message: l10n.forgetDeviceConfirm,
                    action: session.forgetDevice,
                    destructive: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final textPrimary = HomeColors.textPrimary(context);
    final textSecondary = HomeColors.textSecondary(context);
    final brand = HomeColors.brand(context);
    final divider = HomeColors.divider(context);
    final inactive = HomeColors.navInactive(context);

    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: brand),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: inactive,
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, indent: 56, color: divider),
      ],
    );
  }
}
