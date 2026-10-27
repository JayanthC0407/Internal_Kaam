import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';
import 'package:ubci_bank/src/view/widgets/login_help_dialog.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
import 'package:ubci_bank/src/view/widgets/profile_avatar.dart';

import '../home_colors.dart';

/// "More" — the services hub: what else the bank can do for the customer.
/// Everything about the customer and their account (profile, security,
/// limits, notifications, appearance, language, Personalize Dashboard)
/// lives in My Preferences, opened from the header initials or the
/// profile card here, so nothing is offered in both places.
class MoreTabScreen extends ConsumerStatefulWidget {
  const MoreTabScreen({
    super.key,
    this.displayName = '',
    this.onRewardsTap,
    this.onMailboxTap,
    this.onProfileTap,
    this.onServiceRequestsTap,
    this.onCalculatorsTap,
  });

  /// Opens Calculators; null hides the row.
  final VoidCallback? onCalculatorsTap;

  /// Opens Service Requests (Track / Raise); null hides the row.
  final VoidCallback? onServiceRequestsTap;

  /// Opens Mailbox; null keeps the old Coming soon.
  final VoidCallback? onMailboxTap;

  /// The profile card: opens My Preferences.
  final VoidCallback? onProfileTap;

  /// Signed-in customer's name for the profile card.
  final String displayName;

  /// Opens the Rewards tab.
  final VoidCallback? onRewardsTap;

  @override
  ConsumerState<MoreTabScreen> createState() => _MoreTabScreenState();
}

class _MoreTabScreenState extends ConsumerState<MoreTabScreen> {
  @override
  void initState() {
    super.initState();
    // The profile card shows the primary account — load the list if the
    // Menu is opened before Home has.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(casaAccountsProvider.notifier).ensureLoaded();
    });
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppBottomSheet.confirm(
      context,
      title: l10n.logOut,
      message: l10n.logOutConfirm,
    );
    if (!confirmed || !mounted) return;
    await ref.read(sessionManagerProvider).logout();
    if (!mounted) return;
    // Root: on web this tab sits in the dashboard's content navigator.
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
      RoutesConst.loginScreen,
      (route) => false,
    );
  }

  void _comingSoon(String label) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label · ${l10n.featureComingSoon}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final textPrimary = HomeColors.textPrimary(context);
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
      onTap: widget.onProfileTap,
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
      ],
    );

    // Wide screens get desktop-sized rows with icons; the phone keeps the
    // designer's plain list.
    _MenuRow row(String title, IconData icon, VoidCallback onTap, {bool last = false}) => _MenuRow(
          title: title,
          icon: wide ? icon : null,
          compact: wide,
          showDivider: !last,
          onTap: onTap,
        );

    final menu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupTitle(l10n.moreGroupServices),
        _SettingsCard(
          children: [
            row(
              // OBDX's name for it: Mailbox (Mails, Alerts, Notifications).
              widget.onMailboxTap == null ? l10n.menuNotification : l10n.mailboxTitle,
              Icons.notifications_none_rounded,
              widget.onMailboxTap ?? () => _comingSoon(l10n.menuNotification),
              last: widget.onServiceRequestsTap == null && widget.onCalculatorsTap == null,
            ),
            if (widget.onServiceRequestsTap != null)
              row(l10n.srTitle, Icons.support_agent_rounded, widget.onServiceRequestsTap!,
                  last: widget.onCalculatorsTap == null),
            if (widget.onCalculatorsTap != null)
              row(l10n.calcTitle, Icons.calculate_outlined, widget.onCalculatorsTap!, last: true),
          ],
        ),
        const SizedBox(height: 14),
        _GroupTitle(l10n.moreGroupDiscover),
        _SettingsCard(
          children: [
            row(l10n.menuWhatsNew, Icons.campaign_outlined, () => _comingSoon(l10n.menuWhatsNew)),
            row(l10n.menuExploreProducts, Icons.storefront_outlined, () => _comingSoon(l10n.menuExploreProducts), last: true),
          ],
        ),
        const SizedBox(height: 14),
        _GroupTitle(l10n.moreGroupHelp),
        _SettingsCard(
          children: [
            row(l10n.menuNeedHelp, Icons.help_outline_rounded, () => LoginHelpDialog.show(context), last: true),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          children: [
            _MenuRow(
              title: l10n.logOut,
              icon: wide ? Icons.logout_rounded : null,
              compact: wide,
              destructive: wide,
              showChevron: false,
              showDivider: false,
              onTap: _logout,
            ),
          ],
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
}

/// A group's heading: Services, Discover, Help.
class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: HomeColors.textSecondary(context),
          ),
        ),
      );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Profile card at the top of the Menu (designer mock); opens My
/// Preferences.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, this.accountNumber, this.onTap});

  final String name;
  final String? accountNumber;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
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
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.9)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square shortcut under the profile card (Networth / Rewards).
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
