import 'package:flutter/material.dart';
import 'package:demo_bank/src/view/widgets/brand_logo.dart';
import 'package:demo_bank/src/view/widgets/notification_bell.dart';
import 'package:demo_bank/src/view/widgets/profile_avatar.dart';
import 'package:demo_bank/l10n/app_localizations.dart';
import 'package:demo_bank/src/core/theme/app_colors.dart';
import 'package:demo_bank/src/view/screens/common/dashboard/dashboard_top_bar.dart';
import 'package:demo_bank/src/view/screens/retail/home/home_colors.dart';

/// Retail **web** dashboard top bar — the shared [DashboardTopBar], the same
/// bar the Corporate dashboard uses, fed from the Retail session.
///
/// The initials open My Preferences; the settings gear holds the
/// light/dark and colour theme switches.
class WebDashboardHeaderBar extends StatelessWidget {
  const WebDashboardHeaderBar({
    super.key,
    required this.displayName,
    required this.onLogout,
    this.userId,
    this.onMenuTap,
    this.onSearchSubmitted,
    this.onFavouritesTap,
    this.onLanguageTap,
    this.onHelpTap,
    this.onNotificationsTap,
    this.unreadNotificationCount = 0,
    this.onProfileTap,
  });

  /// The initials: opens My Preferences (which holds Log out).
  final VoidCallback? onProfileTap;

  /// The signed-in customer's name, for the profile menu and avatar.
  final String displayName;

  /// Sign-in ID, shown under [displayName] in the profile menu. Omitted
  /// when it would only repeat the name.
  final String? userId;

  final VoidCallback onLogout;

  /// Opens the hamburger drawer. Only passed on tablet — desktop has the
  /// persistent side menu instead, so this is `null` there and
  /// the menu button is not shown.
  final VoidCallback? onMenuTap;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onFavouritesTap;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onNotificationsTap;

  /// Unread mails + alerts + notifications, on the bell.
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context) {
    final id = userId?.trim() ?? '';
    final repeatsName = id.toLowerCase() == displayName.trim().toLowerCase();

    return DashboardTopBar(
      displayName: displayName,
      subtitle: repeatsName ? null : id,
      onLogout: onLogout,
      onMenuTap: onMenuTap,
      onSearchSubmitted: onSearchSubmitted,
      onFavouritesTap: onFavouritesTap,
      onLanguageTap: onLanguageTap,
      onHelpTap: onHelpTap,
      onNotificationsTap: onNotificationsTap,
      unreadNotificationCount: unreadNotificationCount,
      onProfileTap: onProfileTap,
      profileTooltip: AppLocalizations.of(context).prefTitle,
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
    this.unreadNotificationCount = 0,
    this.onProfileTap,
  });

  /// Unread mails + alerts + notifications, on the bell.
  final int unreadNotificationCount;

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
        NotificationBell(
          count: unreadNotificationCount,
          color: HomeColors.textPrimary(context),
          size: 26,
          onTap: onNotificationsTap,
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

/// Phone Home header: menu on the left, the Demobank logo in the middle,
/// the notification bell (with OBDX's red unread count; opens Mailbox) and
/// the customer's initials (open My Preferences, as OBDX's header profile
/// does) on the right.
class DemobankHomeHeader extends StatelessWidget {
  const DemobankHomeHeader({
    super.key,
    this.onMenuTap,
    this.onProfileTap,
    this.onNotificationsTap,
    this.unreadNotificationCount = 0,
    this.displayName = '',
  });

  final VoidCallback? onMenuTap;
  final VoidCallback? onProfileTap;

  /// The bell; `null` hides it.
  final VoidCallback? onNotificationsTap;

  /// Unread mails + alerts + notifications, on the bell.
  final int unreadNotificationCount;

  /// For the avatar's initials.
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final iconColor = HomeColors.textPrimary(context);
    final bell = onNotificationsTap;
    // Both sides as wide, so the logo stays centred.
    final side = bell == null ? 48.0 : 92.0;
    return Row(
      children: [
        SizedBox(
          width: side,
          // At the start of its side, not centred in it: the side is wider
          // when the bell is there, and the menu stays at the left edge.
          child: onMenuTap == null
              ? null
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                    onPressed: onMenuTap,
                    icon: Icon(Icons.sort_rounded, color: iconColor, size: 26),
                  ),
                ),
        ),
        Expanded(
          child: Center(
            // White in dark mode.
            child: BrandLogo(height: 36, fallbackColor: iconColor),
          ),
        ),
        SizedBox(
          width: side,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (bell != null) ...[
                NotificationBell(
                  count: unreadNotificationCount,
                  color: iconColor,
                  size: 26,
                  padding: const EdgeInsets.all(6),
                  onTap: bell,
                ),
                const SizedBox(width: 4),
              ],
              Tooltip(
                message: l10n.prefTitle,
                child: ProfileAvatar(
                  name: displayName.trim().isEmpty ? '?' : displayName,
                  radius: 18,
                  onTap: onProfileTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
