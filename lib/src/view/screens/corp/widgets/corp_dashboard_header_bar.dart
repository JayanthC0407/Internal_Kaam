import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/screens/common/dashboard/dashboard_top_bar.dart';

/// Corporate dashboard top bar — the shared [DashboardTopBar], fed from the
/// corporate profile.
///
/// The profile menu shows the user's name over their corporate entity, and
/// the notification bell shows the live unread count from
/// `collaboration/v1/mailbox/count`.
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

  /// Opens the Personalize Dashboard panel from the settings menu.
  /// `null` omits the entry entirely.
  final VoidCallback? onPersonalizeDashboard;

  /// Fallback display name when the `me` response has not resolved a full
  /// name (used for the avatar initials and the profile menu header).
  final String userName;

  final VoidCallback onLogout;

  /// Opens the hamburger drawer. Only passed below desktop width — desktop
  /// has the persistent `CorpNavigationSidebar` instead, so this is `null`
  /// there and the menu button is not shown.
  final VoidCallback? onMenuTap;

  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onFavouritesTap;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onHelpTap;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(corpProfileProvider);

    return DashboardTopBar(
      displayName: profileState.displayName(userName),
      initials: profileState.profile?.initials,
      subtitle: profileState.entityName,
      unreadNotificationCount: profileState.unreadMessageCount,
      onLogout: onLogout,
      onMenuTap: onMenuTap,
      onSearchSubmitted: onSearchSubmitted,
      onFavouritesTap: onFavouritesTap,
      onLanguageTap: onLanguageTap,
      onHelpTap: onHelpTap,
      onNotificationsTap: onNotificationsTap,
      onPersonalizeDashboard: onPersonalizeDashboard,
    );
  }
}
