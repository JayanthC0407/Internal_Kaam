import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/view/providers/app_settings_providers.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Redesigned **web** dashboard header: a search field on the left and a
/// quick-action icon strip on the right (theme switch, favourites,
/// language, help, notifications, profile menu trigger).
///
/// The theme switch is fully wired to [appSettingsProvider]. The remaining
/// icons accept optional callbacks so behaviour can be plugged in later
/// without touching this widget again; the profile trigger intentionally
/// has no callback yet — it's a static placeholder per the current design.
class WebDashboardHeaderBar extends ConsumerWidget {
  const WebDashboardHeaderBar({
    super.key,
    this.onMenuTap,
    this.onSearchSubmitted,
    this.onFavouritesTap,
    this.onLanguageTap,
    this.onHelpTap,
    this.onNotificationsTap,
  });

  /// Opens the hamburger drawer. Only passed on tablet — desktop has the
  /// persistent `WebNavigationSidebar` instead, so this is `null` there and
  /// the menu button is not shown.
  final VoidCallback? onMenuTap;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onFavouritesTap;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(appSettingsProvider).themeMode;
    final isDark = themeMode == ThemeMode.dark;
    final menuTap = onMenuTap;

    return Row(
      children: [
        if (menuTap != null) ...[
          _HeaderIconButton(
            icon: Icons.menu_rounded,
            tooltip: 'Menu',
            onTap: menuTap,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _HeaderSearchField(
                hint: l10n.searchPlaceholder,
                onSubmitted: onSearchSubmitted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        _ThemeModeSwitch(
          isDark: isDark,
          onChanged: (value) => ref
              .read(appSettingsProvider.notifier)
              .setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
        ),
        const SizedBox(width: 10),
        _HeaderIconButton(
          icon: Icons.favorite_border_rounded,
          tooltip: 'Favourites',
          onTap: onFavouritesTap,
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.language_rounded,
          tooltip: 'Language',
          onTap: onLanguageTap,
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.help_outline_rounded,
          tooltip: l10n.help,
          onTap: onHelpTap,
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: onNotificationsTap,
        ),
        const SizedBox(width: 10),
        // Static for now — dropdown menu / navigation to be wired up later.
        const _ProfileMenuTrigger(),
      ],
    );
  }
}

/// Compact search + notifications + profile row used to replace the
/// greeting row inside the **mobile** hero card. Rendered on top of the
/// brand gradient, so colours are fixed to white/translucent-white rather
/// than theme-derived — the gradient itself already adapts to dark/light
/// mode (see [AppGradients.primary]).
class MobileDashboardHeaderRow extends StatelessWidget {
  const MobileDashboardHeaderRow({
    super.key,
    this.onMenuTap,
    this.onSearchSubmitted,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  /// Opens the hamburger drawer. `null` hides the icon.
  final VoidCallback? onMenuTap;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final menuTap = onMenuTap;

    return Row(
      children: [
        if (menuTap != null) ...[
          IconButton(
            onPressed: menuTap,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.menu_rounded,
              color: HomeColors.textPrimary(context),
              size: 26,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              onSubmitted: onSearchSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: HomeColors.brand(context),
              style: TextStyle(fontSize: 13, color: HomeColors.textPrimary(context)),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: HomeColors.textSecondary(context),
                ),
                hintText: l10n.searchPlaceholder,
                hintStyle: TextStyle(fontSize: 12.5, color: HomeColors.navInactive(context)),
                filled: true,
                fillColor: HomeColors.card(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: HomeColors.divider(context),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: HomeColors.divider(context),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: HomeColors.brand(context),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNotificationsTap,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.notifications_none_rounded,
            color: HomeColors.textPrimary(context),
            size: 26,
          ),
        ),
        InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(20),
          child: const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.neutral100,
            child: Icon(Icons.person, size: 20, color: AppColors.neutral600),
          ),
        ),
      ],
    );
  }
}

class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({required this.hint, this.onSubmitted});

  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 13, color: HomeColors.textPrimary(context)),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 19,
            color: HomeColors.navInactive(context),
          ),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: HomeColors.navInactive(context)),
          filled: true,
          fillColor: HomeColors.card(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: HomeColors.divider(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: HomeColors.divider(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: HomeColors.brand(context), width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeSwitch extends StatelessWidget {
  const _ThemeModeSwitch({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: Switch(
        value: isDark,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: HomeColors.brand(context),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: HomeColors.navInactive(context).withValues(alpha: 0.4),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
          if (states.contains(WidgetState.selected)) {
            return const Icon(
              Icons.dark_mode_rounded,
              size: 14,
              color: Color(0xFF0B1B2B),
            );
          }
          return Icon(
            Icons.light_mode_rounded,
            size: 14,
            color: HomeColors.brand(context),
          );
        }),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HomeColors.divider(context)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: HomeColors.navInactive(context)),
          ),
        ),
      ),
    );
  }
}

/// Static profile / account trigger — avatar + chevron. Non-functional for
/// now: no dropdown menu or navigation wired up yet, by design.
class _ProfileMenuTrigger extends StatelessWidget {
  const _ProfileMenuTrigger();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.neutral100,
            child: Icon(Icons.person, size: 16, color: AppColors.neutral600),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: HomeColors.navInactive(context),
          ),
        ],
      ),
    );
  }
}