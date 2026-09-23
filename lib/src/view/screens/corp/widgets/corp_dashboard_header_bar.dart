import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/utils/profile_initials.dart';
import 'package:ubci_bank/src/view/providers/app_settings_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';

/// Corporate dashboard top bar: search field on the left, icon strip on the
/// right (favourites, language, help, notifications, settings, profile).
///
/// The notification bell shows the live unread count from
/// `collaboration/v1/mailbox/count`; the settings and profile menus are
/// wired to the real theme switch and to logout. The remaining icons take
/// optional callbacks so their destinations can be plugged in later without
/// touching this widget again.
class CorpDashboardHeaderBar extends ConsumerWidget {
  const CorpDashboardHeaderBar({
    super.key,
    required this.userName,
    required this.onLogout,
    this.onMenuTap,
    this.onSearchSubmitted,
    this.onFavouritesTap,
    this.onLanguageTap,
    this.onHelpTap,
    this.onNotificationsTap,
    this.onPersonalizeDashboard,
  });

  /// Opens the Personalize Dashboard screen from the settings menu.
  /// `null` omits the entry entirely.
  final VoidCallback? onPersonalizeDashboard;

  /// Fallback display name when the `me` response has not resolved a full
  /// name (used for the avatar initials and the profile menu header).
  final String userName;

  final VoidCallback onLogout;

  /// Opens the hamburger drawer. Only passed below desktop width — desktop
  /// has the persistent [CorpNavigationSidebar] instead, so this is `null`
  /// there and the menu button is not shown.
  final VoidCallback? onMenuTap;

  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onFavouritesTap;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileState = ref.watch(corpProfileProvider);
    final displayName = profileState.displayName(userName);
    final menuTap = onMenuTap;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        border: Border(
          bottom: BorderSide(color: CorpColors.cardBorder(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: CorpColors.cardShadow(context),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (menuTap != null) ...[
            _CorpHeaderIconButton(
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
                child: _CorpSearchField(
                  hint: l10n.searchPlaceholder,
                  onSubmitted: onSearchSubmitted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _CorpHeaderIconButton(
            icon: Icons.favorite_border_rounded,
            tooltip: 'Favourites',
            onTap: onFavouritesTap,
          ),
          _CorpHeaderIconButton(
            icon: Icons.language_rounded,
            tooltip: 'Language',
            onTap: onLanguageTap,
          ),
          _CorpHeaderIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: l10n.help,
            onTap: onHelpTap,
          ),
          _CorpHeaderIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            badgeCount: profileState.unreadMessageCount,
            onTap: onNotificationsTap,
          ),
          _CorpSettingsMenu(onPersonalizeDashboard: onPersonalizeDashboard),
          const SizedBox(width: 4),
          _CorpProfileMenu(
            displayName: displayName,
            initials: profileState.profile?.initials ?? '',
            entityName: profileState.entityName,
            fallbackName: userName,
            onLogout: onLogout,
          ),
        ],
      ),
    );
  }
}

class _CorpSearchField extends StatelessWidget {
  const _CorpSearchField({required this.hint, this.onSubmitted});

  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: CorpColors.cardBorder(context)),
    );

    return SizedBox(
      height: 40,
      child: TextField(
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 13, color: CorpColors.textPrimary(context)),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: CorpColors.brand(context),
          ),
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 12.5,
            color: CorpColors.navInactive(context),
          ),
          filled: true,
          fillColor: CorpColors.card(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: CorpColors.brand(context), width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _CorpHeaderIconButton extends StatelessWidget {
  const _CorpHeaderIconButton({
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
              Icon(icon, size: 20, color: CorpColors.textSecondary(context)),
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
                      color: CorpColors.negativeBalance(context),
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

/// Gear + chevron, per the design. Holds the Personalize Dashboard action
/// and the light/dark theme switch.
class _CorpSettingsMenu extends ConsumerWidget {
  const _CorpSettingsMenu({this.onPersonalizeDashboard});

  /// `null` hides the entry — used when `me` gave the user no
  /// personalizable dashboard, so the action would have nothing to open.
  final VoidCallback? onPersonalizeDashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appSettingsProvider).themeMode == ThemeMode.dark;
    final personalize = onPersonalizeDashboard;

    return PopupMenuButton<String>(
      tooltip: 'Settings',
      position: PopupMenuPosition.under,
      color: CorpColors.card(context),
      onSelected: (value) {
        if (value == 'personalize') {
          personalize?.call();
          return;
        }
        if (value != 'theme') return;
        ref.read(appSettingsProvider.notifier).setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            );
      },
      itemBuilder: (context) => [
        if (personalize != null)
          PopupMenuItem(
            value: 'personalize',
            child: _MenuRow(
              icon: Icons.dashboard_customize_outlined,
              label: 'Personalize Dashboard',
            ),
          ),
        if (personalize != null) const PopupMenuDivider(),
        PopupMenuItem(
          value: 'theme',
          child: _MenuRow(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.settings_outlined,
              size: 20,
              color: CorpColors.textSecondary(context),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: CorpColors.navInactive(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon + label row for a popup menu item.
///
/// The label is [Flexible] because popup menus are width-constrained
/// (256px here) — a plain Row would overflow on the longer labels.
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
        Icon(icon, size: 18, color: iconColor ?? CorpColors.brand(context)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Initials avatar + chevron. Shows who is signed in (name, corporate
/// entity) and holds the logout action.
class _CorpProfileMenu extends StatelessWidget {
  const _CorpProfileMenu({
    required this.displayName,
    required this.initials,
    required this.entityName,
    required this.fallbackName,
    required this.onLogout,
  });

  final String displayName;
  final String initials;
  final String? entityName;
  final String fallbackName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolvedInitials = initials.isNotEmpty
        ? initials
        : ProfileInitials.fromName(
            displayName.isNotEmpty ? displayName : fallbackName,
          );

    return PopupMenuButton<String>(
      tooltip: displayName,
      position: PopupMenuPosition.under,
      color: CorpColors.card(context),
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
                  color: CorpColors.textPrimary(context),
                ),
              ),
              if (entityName != null && entityName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  entityName!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: CorpColors.textSecondary(context),
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
            iconColor: CorpColors.negativeBalance(context),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CorpColors.brand(context).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                resolvedInitials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CorpColors.brand(context),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: CorpColors.navInactive(context),
            ),
          ],
        ),
      ),
    );
  }
}
