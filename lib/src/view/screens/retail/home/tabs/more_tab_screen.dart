import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/theme/app_palette.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';
import 'package:ubci_bank/src/view/widgets/biometric_enrollment_prompt.dart';
import 'package:ubci_bank/src/view/widgets/biometric_ui_copy.dart';
import 'package:ubci_bank/src/view/widgets/login_help_dialog.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
import 'package:ubci_bank/src/view/widgets/profile_avatar.dart';

import '../home_colors.dart';

/// "Menu" (designer mock): profile card, Networth / Rewards / Languages
/// tiles and the menu list. App Settings opens in place and holds Theme,
/// Language, biometric login and Forget device.
class MoreTabScreen extends ConsumerStatefulWidget {
  const MoreTabScreen({
    super.key,
    this.displayName = '',
    this.onRewardsTap,
    this.onPersonalize,
  });

  /// Opens Personalize Dashboard; null hides the row (no personalisable
  /// OBDX dashboard for this customer).
  final VoidCallback? onPersonalize;

  /// Signed-in customer's name for the profile card.
  final String displayName;

  /// Opens the Rewards tab.
  final VoidCallback? onRewardsTap;

  @override
  ConsumerState<MoreTabScreen> createState() => _MoreTabScreenState();
}

class _MoreTabScreenState extends ConsumerState<MoreTabScreen> {
  bool _settingsOpen = false;
  bool? _biometricEnabled;
  bool? _biometricAvailable;
  BiometricPresentation _biometricPresentation = BiometricPresentation.android;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
    // The profile card shows the primary account — load the list if the
    // Menu is opened before Home has.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(casaAccountsProvider.notifier).ensureLoaded();
    });
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
    // Root: on web this tab sits in the dashboard's content navigator.
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
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

  Future<void> _pickPalette(AppThemePalette current) async {
    final l10n = AppLocalizations.of(context);
    final selected = await AppBottomSheet.pick<AppThemePalette>(
      context: context,
      title: l10n.colorTheme,
      selected: current,
      options: [
        for (final palette in AppThemePalette.values)
          (value: palette, label: palette.label(l10n)),
      ],
    );
    if (selected == null || !mounted) return;
    await ref.read(appSettingsProvider.notifier).setPalette(selected);
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

  void _comingSoon(String label) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label · ${l10n.featureComingSoon}')),
    );
  }

  Widget _menuPage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final textPrimary = HomeColors.textPrimary(context);
    final session = ref.read(sessionManagerProvider);
    final accounts =
        ref.watch(casaAccountsProvider).summary?.accounts ?? const [];
    final primary = accounts.isEmpty
        ? null
        : accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);

    final wide = responsive.useWideLayout;

    final title = Text(
      l10n.menuTitle,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    );

    final profile = _ProfileCard(
      name: widget.displayName.trim().isEmpty
          ? l10n.menuWelcome
          : widget.displayName.trim(),
      accountNumber:
          primary == null ? null : groupAccountNumber(primary.displayNumber),
    );

    final tiles = Row(
      children: [
        Expanded(
          child: _MenuTile(
            icon: Icons.pie_chart_outline_rounded,
            label: l10n.menuNetworth,
            onTap: () => _comingSoon(l10n.menuNetworth),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MenuTile(
            icon: Icons.card_giftcard_rounded,
            label: l10n.rewards,
            onTap: widget.onRewardsTap ?? () => _comingSoon(l10n.rewards),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MenuTile(
            icon: Icons.language_rounded,
            label: l10n.menuLanguages,
            onTap: () => _pickLanguage(ref.read(appSettingsProvider).locale),
          ),
        ),
      ],
    );

    // Wide screens get desktop-sized rows with icons; the phone keeps the
    // designer's plain list.
    final menu = _SettingsCard(
      children: [
        _MenuRow(
          title: l10n.menuWhatsNew,
          icon: wide ? Icons.campaign_outlined : null,
          compact: wide,
          onTap: () => _comingSoon(l10n.menuWhatsNew),
        ),
        _MenuRow(
          title: l10n.menuExploreProducts,
          icon: wide ? Icons.storefront_outlined : null,
          compact: wide,
          onTap: () => _comingSoon(l10n.menuExploreProducts),
        ),
        _MenuRow(
          title: l10n.menuNotification,
          icon: wide ? Icons.notifications_none_rounded : null,
          compact: wide,
          onTap: () => _comingSoon(l10n.menuNotification),
        ),
        if (widget.onPersonalize != null)
          _MenuRow(
            title: l10n.menuPersonalizeDashboard,
            icon: wide ? Icons.dashboard_customize_outlined : null,
            compact: wide,
            onTap: widget.onPersonalize!,
          ),
        _MenuRow(
          title: l10n.menuAppSettings,
          icon: wide ? Icons.settings_outlined : null,
          compact: wide,
          onTap: () => setState(() => _settingsOpen = true),
        ),
        _MenuRow(
          title: l10n.menuNeedHelp,
          icon: wide ? Icons.help_outline_rounded : null,
          compact: wide,
          onTap: () => LoginHelpDialog.show(context),
        ),
        _MenuRow(
          title: l10n.logOut,
          icon: wide ? Icons.logout_rounded : null,
          compact: wide,
          destructive: wide,
          showChevron: false,
          showDivider: false,
          onTap: () => _confirmAndRun(
            context,
            title: l10n.logOut,
            message: l10n.logOutConfirm,
            action: session.logout,
          ),
        ),
      ],
    );

    if (wide) {
      // Desktop / tablet: profile and shortcuts on the left, the menu on
      // the right, so the whole Menu fits one screen.
      return SafeArea(
        child: ResponsiveBody(
          maxWidth: 1080,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            children: [
              title,
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [profile, const SizedBox(height: 14), tiles],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: menu),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: ResponsiveBody(
        maxWidth: responsive.formMaxWidth + 80,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            title,
            const SizedBox(height: 16),
            profile,
            const SizedBox(height: 14),
            tiles,
            const SizedBox(height: 14),
            menu,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsOpen) return _menuPage(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _settingsOpen = false);
      },
      child: _settingsPage(context),
    );
  }

  /// App Settings: Theme, Language, biometric login, Forget device.
  Widget _settingsPage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final currentThemeMode = settings.themeMode;
    final currentPalette = settings.palette;
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
            // Top offset matches the side menu's top padding (22) around
            // the sidebar logo, and the dashboard header's top padding —
            // so "More" sits on the same line as the Demobank logo instead
            // of floating above it (desktop/wide only; phones keep 16).
            responsive.isPhone ? 16 : 28,
            responsive.isPhone ? 20 : 24,
            24,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => setState(() => _settingsOpen = false),
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: brand),
                ),
                Text(
                  l10n.menuAppSettings,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SettingsCard(
              children: [
                _SettingsNavTile(
                  icon: Icons.palette_outlined,
                  title: l10n.theme,
                  value: themeLabel,
                  onTap: () => _pickTheme(currentThemeMode),
                ),
                _SettingsNavTile(
                  icon: Icons.color_lens_outlined,
                  title: l10n.colorTheme,
                  value: currentPalette.label(l10n),
                  valueSwatch: currentPalette.swatch,
                  onTap: () => _pickPalette(currentPalette),
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
        boxShadow: [
          BoxShadow(
            color: HomeColors.brandLight(context).withValues(alpha: 0.30),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        // Stretch so section headings (e.g. "Security") sit left like
        // the rows below them.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
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
    this.valueSwatch,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool showDivider;

  /// Small colour dot shown before [value] (used by the colour theme row).
  final Color? valueSwatch;

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
              if (valueSwatch != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: valueSwatch,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
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

/// Profile card at the top of the Menu (designer mock).
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, this.accountNumber});

  final String name;
  final String? accountNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.primary(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Initials (or photo) — the app's standard profile avatar.
          ProfileAvatar(name: name, radius: 32, onDarkBackground: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (accountNumber != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    accountNumber!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Square shortcut under the profile card (Networth / Rewards / Languages).
class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: brand.withValues(alpha: 0.8)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: brand, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the Menu list. [compact] (wide screens) uses desktop-sized
/// rows with a leading [icon]; [destructive] colours it as an exit action.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.title,
    required this.onTap,
    this.showChevron = true,
    this.showDivider = true,
    this.icon,
    this.compact = false,
    this.destructive = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool showChevron;
  final bool showDivider;
  final IconData? icon;
  final bool compact;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? HomeColors.error(context) : HomeColors.brand(context);
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          dense: compact,
          visualDensity: compact ? VisualDensity.compact : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: compact ? 2 : 0),
          leading: icon == null ? null : Icon(icon, color: accent, size: 22),
          title: Text(
            title,
            style: TextStyle(
              fontSize: compact ? 15 : 17,
              fontWeight: compact ? FontWeight.w500 : null,
              color: destructive ? accent : HomeColors.textPrimary(context),
            ),
          ),
          trailing: showChevron
              ? Icon(
                  Icons.chevron_right_rounded,
                  color: compact ? HomeColors.navInactive(context) : HomeColors.brand(context),
                )
              : null,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: icon == null ? 18 : 58,
            endIndent: 18,
            color: HomeColors.divider(context),
          ),
      ],
    );
  }
}
