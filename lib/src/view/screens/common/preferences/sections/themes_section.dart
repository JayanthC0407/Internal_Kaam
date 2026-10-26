import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/theme/app_palette.dart';
import 'package:ubci_bank/src/view/providers/common/app_settings_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/language_picker.dart';

/// Preferences → Appearance & Language. The theme part is OBDX's Themes
/// (`theme-config/preview-brand-list`): "Select a
/// theme to change the look of the application", a preview card per theme,
/// Apply (only once a different theme is chosen), "Switch to Default
/// Theme" and Back. OBDX's themes are server brands; here they are the
/// app's own palettes ([AppThemePalette]) together with light / dark, so
/// this page, App Settings and the top-bar menu all change the same
/// [appSettingsProvider].
class ThemesSection extends ConsumerStatefulWidget {
  const ThemesSection({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<ThemesSection> createState() => _ThemesSectionState();
}

class _ThemesSectionState extends ConsumerState<ThemesSection> {
  AppThemePalette? _palette;
  Brightness? _brightness;

  Brightness _appliedBrightness(AppSettings s) => switch (s.themeMode) {
        ThemeMode.dark => Brightness.dark,
        ThemeMode.light => Brightness.light,
        ThemeMode.system => MediaQuery.platformBrightnessOf(context),
      };

  Future<void> _apply(AppSettings applied) async {
    final notifier = ref.read(appSettingsProvider.notifier);
    final palette = _palette ?? applied.palette;
    final brightness = _brightness ?? _appliedBrightness(applied);
    if (palette != applied.palette) await notifier.setPalette(palette);
    if (brightness != _appliedBrightness(applied)) {
      await notifier.setThemeMode(brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light);
    }
    if (!mounted) return;
    setState(() {
      _palette = null;
      _brightness = null;
    });
    prefSnack(context, AppLocalizations.of(context).prefThemeApplied);
  }

  Future<void> _switchToDefault() async {
    await ref.read(appSettingsProvider.notifier).setPalette(AppThemePalette.fallback);
    if (!mounted) return;
    setState(() => _palette = null);
    prefSnack(context, AppLocalizations.of(context).prefThemeApplied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final applied = ref.watch(appSettingsProvider);
    final palette = _palette ?? applied.palette;
    final brightness = _brightness ?? _appliedBrightness(applied);
    final changed = palette != applied.palette || brightness != _appliedBrightness(applied);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.prefThemesIntro,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: HomeColors.textSecondary(context)),
        ),
        const SizedBox(height: 14),
        PaySegmented<Brightness>(
          options: [(Brightness.light, l10n.lightTheme), (Brightness.dark, l10n.darkTheme)],
          selected: brightness,
          onChanged: (b) => setState(() => _brightness = b),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) => PayGrid(
            columns: c.maxWidth >= 900 ? 3 : (c.maxWidth >= 520 ? 2 : 1),
            gap: 14,
            children: [
              for (final p in AppThemePalette.values)
                _ThemePreviewCard(
                  palette: p,
                  brightness: brightness,
                  selected: p == palette,
                  applied: p == applied.palette && brightness == _appliedBrightness(applied),
                  onTap: () => setState(() => _palette = p),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PaySection(
          title: l10n.language,
          icon: Icons.language_rounded,
          child: PayPickerField(
            placeholder: l10n.language,
            title: LocaleConfig.displayName(l10n, applied.locale.languageCode),
            icon: Icons.translate_rounded,
            dense: true,
            // Applies at once, like the App Settings picker it replaces.
            onTap: () => showLanguagePicker(context, ref),
          ),
        ),
        if (applied.palette != AppThemePalette.fallback) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _switchToDefault,
              style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
              child: Text(l10n.prefSwitchDefaultTheme),
            ),
          ),
        ],
        const SizedBox(height: 16),
        PrefActions(children: [
          PayPrimaryButton(label: l10n.prefApply, onPressed: changed ? () => _apply(applied) : null),
          PaySecondaryButton(label: l10n.prefBack, onPressed: widget.onBack),
        ]),
      ],
    );
  }
}

/// OBDX's `preview-brand` tile: a small mock of the app — header with logo,
/// side menu, page title, body text and the buttons — in [palette]'s real
/// colours, whatever theme the app is in now.
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.palette,
    required this.brightness,
    required this.selected,
    required this.applied,
    required this.onTap,
  });

  final AppThemePalette palette;
  final Brightness brightness;
  final bool selected;
  final bool applied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final AppColors c = palette.colors(brightness);
    final ring = selected ? HomeColors.success(context) : HomeColors.divider(context);
    return Semantics(
      button: true,
      selected: selected,
      label: palette.label(l10n),
      child: Material(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ring, width: selected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 150,
                    color: c.scaffoldBg,
                    child: Column(
                      children: [
                        // Header bar with the logo.
                        Container(
                          height: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(gradient: c.brandGradient),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Container(width: 38, height: 6, color: Colors.white.withValues(alpha: 0.85)),
                              const Spacer(),
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Side menu.
                              Container(
                                width: 40,
                                color: c.cardBg,
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < 4; i++)
                                      Container(
                                        height: 6,
                                        margin: const EdgeInsets.only(bottom: 7),
                                        decoration: BoxDecoration(
                                          color: i == 0 ? c.brand : c.navInactive.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Page.
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.prefPreviewPageTitle,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: c.cardBg,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: c.divider),
                                        ),
                                        child: Text(
                                          l10n.prefPreviewBody,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 8.5, color: c.textSecondary),
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          _MiniButton(label: l10n.prefPreviewPrimary, fill: c.brand, text: Colors.white),
                                          const SizedBox(width: 4),
                                          _MiniButton(label: l10n.prefPreviewSecondary, fill: c.secondaryButtonBg, text: c.brand),
                                          const SizedBox(width: 4),
                                          _MiniButton(label: l10n.prefBack, fill: Colors.transparent, text: c.brand, outline: c.brand),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: palette.swatch, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        palette.label(l10n),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                      ),
                    ),
                    if (applied)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: HomeColors.brand(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.prefCurrentTheme,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HomeColors.brand(context)),
                        ),
                      ),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded, color: HomeColors.success(context), size: 22),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.label, required this.fill, required this.text, this.outline});

  final String label;
  final Color fill;
  final Color text;
  final Color? outline;

  @override
  Widget build(BuildContext context) => Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: outline == null ? null : Border.all(color: outline!),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: text),
          ),
        ),
      );
}
