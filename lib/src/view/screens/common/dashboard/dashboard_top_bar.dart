import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/theme/app_palette.dart';
import 'package:ubci_bank/src/core/utils/common/profile_initials.dart';
import 'package:ubci_bank/src/view/providers/common/app_settings_providers.dart';
import 'package:ubci_bank/src/view/widgets/language_picker.dart';

/// The web dashboard top bar shared by Retail and Corporate: search field on
/// the left, icon strip on the right (favourites, language, help,
/// notifications, settings, profile).
///
/// One widget for both so the two headers cannot drift apart. It takes
/// plain data rather than reading a user type's providers — each dashboard
/// has a thin adapter (`CorpDashboardHeaderBar`, `WebDashboardHeaderBar`)
/// that resolves the signed-in user its own way.
///
/// The settings gear holds the light/dark switch and the colour theme
/// (palette) choice; the initials open My Preferences. Only the icons are
/// tap targets — no chevrons beside them. The remaining
/// icons take optional callbacks so their destinations can be plugged in
/// later without touching this widget.
class DashboardTopBar extends ConsumerWidget {
  const DashboardTopBar({
    super.key,
    required this.displayName,
    required this.onLogout,
    this.subtitle,
    this.initials,
    this.unreadNotificationCount = 0,
    this.onMenuTap,
    this.onSearchSubmitted,
    this.onFavouritesTap,
    this.onLanguageTap,
    this.onHelpTap,
    this.onNotificationsTap,
    this.onProfileTap,
    this.profileTooltip,
  });

  /// Tapping the initials runs this (My Preferences, where Personalize
  /// Dashboard and Log out also live). `null` makes the initials open the
  /// profile menu (who is signed in, Log out) instead.
  final VoidCallback? onProfileTap;

  /// Tooltip of the initials when [onProfileTap] is set.
  final String? profileTooltip;

  /// Shown at the top of the profile menu, and the source of the avatar's
  /// initials when [initials] is not given.
  final String displayName;

  /// Second line of the profile menu — the corporate entity, or the
  /// sign-in ID. Omitted when null or empty.
  final String? subtitle;

  /// Avatar initials. Derived from [displayName] when null or empty.
  final String? initials;

  /// Count bubble on the bell; hidden at zero.
  final int unreadNotificationCount;

  final VoidCallback onLogout;

  /// Opens the hamburger drawer. Pass it only when there is no persistent
  /// sidebar (below desktop width); `null` hides the menu button.
  final VoidCallback? onMenuTap;

  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onFavouritesTap;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final menuTap = onMenuTap;

    // Phones: room for search, the bell, settings and profile only.
    // Favourites, Language and Help do nothing yet, so they go first; once
    // one does something it belongs in the settings menu on a phone.
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: _TopBarColors.card(context),
        border: Border(
          bottom: BorderSide(color: _TopBarColors.border(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: _TopBarColors.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (menuTap != null) ...[
            _TopBarIconButton(
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
                child: _TopBarSearchField(
                  hint: l10n.searchPlaceholder,
                  onSubmitted: onSearchSubmitted,
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 12),
          if (!compact) ...[
            _TopBarIconButton(
              icon: Icons.favorite_border_rounded,
              tooltip: 'Favourites',
              onTap: onFavouritesTap,
            ),
            _TopBarIconButton(
              icon: Icons.language_rounded,
              tooltip: 'Language',
              // The shared picker unless a dashboard brings its own.
              onTap: onLanguageTap ?? () => showLanguagePicker(context, ref),
            ),
            _TopBarIconButton(
              icon: Icons.help_outline_rounded,
              tooltip: l10n.help,
              onTap: onHelpTap,
            ),
          ],
          _TopBarIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            badgeCount: unreadNotificationCount,
            onTap: onNotificationsTap,
          ),
          const _SettingsMenu(),
          const SizedBox(width: 4),
          _ProfileMenu(
            displayName: displayName,
            initials: initials,
            subtitle: subtitle,
            onLogout: onLogout,
            onAvatarTap: onProfileTap,
            avatarTooltip: profileTooltip,
          ),
        ],
      ),
    );
  }
}

/// The top bar's palette, from the shared [AppColors] theme extension —
/// the tokens Corporate's `CorpColors` defines for the same surfaces.
class _TopBarColors {
  const _TopBarColors._();

  static AppColors _of(BuildContext context) => AppColors.of(context);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color card(BuildContext context) => _of(context).cardBg;

  static Color textPrimary(BuildContext context) => _of(context).textPrimary;

  static Color textSecondary(BuildContext context) =>
      _of(context).textSecondary;

  static Color brand(BuildContext context) => _of(context).brand;

  static Color navInactive(BuildContext context) => _of(context).navInactive;

  static Color error(BuildContext context) => _of(context).error;

  /// Cyan-tinted 1px outline, matching the dashboard cards.
  static Color border(BuildContext context) => _isDark(context)
      ? _of(context).divider
      : _of(context).brand.withValues(alpha: 0.22);

  static Color shadow(BuildContext context) =>
      _of(context).brandLight.withValues(alpha: _isDark(context) ? 0.14 : 0.22);
}

class _TopBarSearchField extends StatelessWidget {
  const _TopBarSearchField({required this.hint, this.onSubmitted});

  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: _TopBarColors.border(context)),
    );

    return SizedBox(
      height: 40,
      child: TextField(
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: 13,
          color: _TopBarColors.textPrimary(context),
        ),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: _TopBarColors.brand(context),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 12.5,
            color: _TopBarColors.navInactive(context),
          ),
          filled: true,
          fillColor: _TopBarColors.card(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(
              color: _TopBarColors.brand(context),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// Shows a count bubble when greater than zero (notification bell).
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 20, color: _TopBarColors.textSecondary(context)),
              if (badgeCount > 0)
                Positioned(
                  right: -5,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 14),
                    decoration: BoxDecoration(
                      color: _TopBarColors.error(context),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gear + chevron: quick light/dark and colour theme (palette) switches.
/// Personalize Dashboard lives in My Preferences only.
class _SettingsMenu extends ConsumerWidget {
  const _SettingsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final isDark = settings.themeMode == ThemeMode.dark;
    final currentPalette = settings.palette;

    return PopupMenuButton<String>(
      tooltip: 'Settings',
      position: PopupMenuPosition.under,
      color: _TopBarColors.card(context),
      onSelected: (value) {
        if (value.startsWith(_palettePrefix)) {
          ref.read(appSettingsProvider.notifier).setPalette(
                AppThemePalette.parse(value.substring(_palettePrefix.length)),
              );
          return;
        }
        if (value != 'theme') return;
        ref.read(appSettingsProvider.notifier).setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            );
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'theme',
          child: _MenuRow(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(
            l10n.colorTheme,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _TopBarColors.textSecondary(context),
              letterSpacing: 0.2,
            ),
          ),
        ),
        for (final palette in AppThemePalette.values)
          PopupMenuItem<String>(
            value: '$_palettePrefix${palette.name}',
            child: _PaletteMenuRow(
              label: palette.label(l10n),
              swatch: palette.swatch,
              selected: palette == currentPalette,
            ),
          ),
      ],
      // The gear alone, like the other header icons — no chevron.
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.settings_outlined,
          size: 20,
          color: _TopBarColors.textSecondary(context),
        ),
      ),
    );
  }
}

/// Menu value prefix for the colour theme entries (`palette:<name>`).
const _palettePrefix = 'palette:';

/// Swatch + label (+ check when active) row for a colour theme entry.
class _PaletteMenuRow extends StatelessWidget {
  const _PaletteMenuRow({
    required this.label,
    required this.swatch,
    required this.selected,
  });

  final String label;
  final Color swatch;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: swatch,
            shape: BoxShape.circle,
            border: Border.all(
              color: _TopBarColors.textPrimary(context).withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 10),
          Icon(
            Icons.check_rounded,
            size: 18,
            color: _TopBarColors.brand(context),
          ),
        ],
      ],
    );
  }
}

/// Icon + label row for a popup menu item.
///
/// The label is [Flexible] because popup menus are width-constrained — a
/// plain Row would overflow on the longer labels.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor ?? _TopBarColors.brand(context)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// The initials, with no chevron. With [onAvatarTap] (Retail and
/// Corporate: My Preferences, which also holds Log out) they only do that;
/// without it they open a menu of who is signed in and Log out.
class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({
    required this.displayName,
    required this.initials,
    required this.subtitle,
    required this.onLogout,
    this.onAvatarTap,
    this.avatarTooltip,
  });

  final String displayName;
  final String? initials;
  final String? subtitle;
  final VoidCallback onLogout;
  final VoidCallback? onAvatarTap;
  final String? avatarTooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final given = initials?.trim() ?? '';
    final resolvedInitials =
        given.isNotEmpty ? given : ProfileInitials.fromName(displayName);
    final secondLine = subtitle?.trim() ?? '';

    final avatar = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _TopBarColors.brand(context).withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        resolvedInitials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _TopBarColors.brand(context),
        ),
      ),
    );
    final avatarTap = onAvatarTap;
    if (avatarTap != null) {
      return Tooltip(
        message: avatarTooltip ?? displayName,
        child: InkWell(
          onTap: avatarTap,
          customBorder: const CircleBorder(),
          child: Padding(padding: const EdgeInsets.all(4), child: avatar),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: displayName,
      position: PopupMenuPosition.under,
      color: _TopBarColors.card(context),
      onSelected: (value) {
        if (value == 'logout') onLogout();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _TopBarColors.textPrimary(context),
                ),
              ),
              if (secondLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondLine,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _TopBarColors.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: _MenuRow(
            icon: Icons.logout_rounded,
            label: l10n.logOut,
            iconColor: _TopBarColors.error(context),
          ),
        ),
      ],
      child: Padding(padding: const EdgeInsets.all(4), child: avatar),
    );
  }
}
