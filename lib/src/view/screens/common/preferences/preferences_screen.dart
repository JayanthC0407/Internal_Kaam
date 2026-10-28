import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
import 'package:ubci_bank/src/view/providers/common/app_settings_providers.dart';
import 'package:ubci_bank/src/view/providers/common/preferences_providers.dart';
import 'package:ubci_bank/src/view/screens/common/limits/my_limits_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/alerts_subscription_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/change_password_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/primary_account_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/session_summary_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/profile_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/security_login_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/settings_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/themes_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/third_party_apps_section.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';
import 'package:ubci_bank/src/view/widgets/design_page.dart';
import 'package:ubci_bank/src/view/widgets/profile_avatar.dart';

/// My Preferences — everything about the signed-in user and their
/// account, opened from the initials in the dashboard header (Retail and
/// Corporate). Services, discovery and help live in More instead, so no
/// setting appears in both.
///
/// Built on OBDX's Account Settings → Preferences (`security/side-menu`),
/// regrouped the way people look for things:
///  - Account: Profile, Primary Account Number, Limits & Controls
///    (OBDX My Limits);
///  - Security & Privacy: Security & Login (with biometric login and
///    devices), Change Password, Session Summary, Privacy & Consents
///    (Third Party Applications, Feedback, Live Help);
///  - App: Notifications & Alerts (push, OTP delivery), Alerts
///    Subscription, Appearance & Language (OBDX Themes), Personalize
///    Dashboard;
///  - Log out.
/// Wide: two columns scrolling on their own — the title and the section
/// list; the profile card over the open section. Phone:
/// the card and the list, each row with its current value where cheap to
/// show; a section opens full-width and Back returns to the list.
enum PrefSection {
  profile(Icons.person_outline_rounded),
  primaryAccount(Icons.account_balance_wallet_outlined),
  limits(Icons.speed_rounded),
  securityLogin(Icons.lock_outline_rounded),
  changePassword(Icons.password_rounded),
  sessionSummary(Icons.history_rounded),
  privacy(Icons.privacy_tip_outlined),
  notifications(Icons.notifications_none_rounded),
  alertsSubscription(Icons.notifications_active_outlined),
  appearance(Icons.palette_outlined);

  const PrefSection(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
        PrefSection.profile => l10n.prefProfile,
        PrefSection.primaryAccount => l10n.prefPrimaryAccount,
        PrefSection.limits => l10n.prefLimitsControls,
        PrefSection.securityLogin => l10n.prefSecurityLogin,
        PrefSection.changePassword => l10n.cpTitle,
        PrefSection.sessionSummary => l10n.ssTitle,
        PrefSection.privacy => l10n.prefPrivacyConsents,
        PrefSection.alertsSubscription => l10n.asTitle,
        PrefSection.notifications => l10n.prefNotificationsAlerts,
        PrefSection.appearance => l10n.prefAppearanceLanguage,
      };

  /// What the row says under its title on the list.
  String hint(AppLocalizations l10n) => switch (this) {
        PrefSection.profile => l10n.prefProfileHint,
        PrefSection.primaryAccount => l10n.prefPrimaryAccountHint,
        PrefSection.limits => l10n.prefLimitsHint,
        PrefSection.securityLogin => l10n.prefSecurityHint,
        PrefSection.changePassword => l10n.cpHint,
        PrefSection.sessionSummary => l10n.ssHint,
        PrefSection.privacy => l10n.prefPrivacyHint,
        PrefSection.alertsSubscription => l10n.asHint,
        PrefSection.notifications => l10n.prefNotificationsHint,
        PrefSection.appearance => l10n.prefAppearanceHint,
      };
}

/// The list's groups, in order.
const _groups = [
  [PrefSection.profile, PrefSection.primaryAccount, PrefSection.limits],
  [PrefSection.securityLogin, PrefSection.changePassword, PrefSection.sessionSummary, PrefSection.privacy],
  [PrefSection.notifications, PrefSection.alertsSubscription, PrefSection.appearance],
];

String _groupTitle(AppLocalizations l10n, int i) => switch (i) {
      0 => l10n.prefGroupAccount,
      1 => l10n.prefGroupSecurity,
      _ => l10n.prefGroupApp,
    };

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({
    super.key,
    required this.userName,
    required this.onLogout,
    this.displayName = '',
    this.lastLogin,
    this.onPersonalize,
    this.embedded = false,
    this.onBack,
    this.initialSection,
  });

  /// The signed-in user id — shown on the card, and sent as `userId` with
  /// consent changes.
  final String userName;

  /// The name on the card until `me/party` gives the full one.
  final String displayName;

  /// `userProfile.lastLoginTime` from `me`, when the bank sends it.
  final DateTime? lastLogin;

  /// Opens Personalize Dashboard; null hides the row (no personalisable
  /// dashboard for this user).
  final VoidCallback? onPersonalize;

  /// Logs out; asked to confirm first.
  final VoidCallback onLogout;
  final bool embedded;
  final VoidCallback? onBack;

  /// Opens straight on a section (OBDX `sideMenuOption`).
  final PrefSection? initialSection;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  /// Null on a phone shows the list.
  PrefSection? _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  void _exit() {
    if (widget.embedded) {
      widget.onBack?.call();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppBottomSheet.confirm(context, title: l10n.logOut, message: l10n.logOutConfirm, destructive: true);
    if (confirmed && mounted) widget.onLogout();
  }

  Widget _body(PrefSection section, {required bool wide, required VoidCallback onDone}) => switch (section) {
        PrefSection.profile => const ProfileSection(),
        PrefSection.primaryAccount => const PrimaryAccountSection(),
        PrefSection.limits => MyLimitsView(wide: wide),
        PrefSection.securityLogin => const SecurityLoginSection(),
        PrefSection.changePassword => ChangePasswordSection(
            userName: widget.userName,
            onCancel: onDone,
            // OBDX: "Please click below to Login" — the session ends.
            onLogin: widget.onLogout,
          ),
        PrefSection.sessionSummary => const SessionSummarySection(),
        PrefSection.alertsSubscription => const AlertsSubscriptionSection(),
        PrefSection.privacy => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ThirdPartyAppsSection(userName: widget.userName, onCancel: onDone),
              const SizedBox(height: 24),
              const PrivacySettings(),
            ],
          ),
        PrefSection.notifications => const NotificationSettings(),
        PrefSection.appearance => ThemesSection(onBack: onDone),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kPayWideFlow;
        final open = wide ? (_section ?? PrefSection.profile) : _section;
        final card = _ProfileCard(userName: widget.userName, displayName: widget.displayName, lastLogin: widget.lastLogin);
        final list = _SectionList(
          selected: wide ? open : null,
          onSelect: (s) => setState(() => _section = s),
          onPersonalize: widget.onPersonalize,
          onLogout: _logout,
        );
        // Wide: two columns that scroll on their own — the title and the
        // section list on the left; the user card and the open section on
        // the right — so the list stays in reach however long a section is.
        if (wide) {
          return Scaffold(
            backgroundColor: HomeColors.bg(context),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 300,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DesignPageHeader(title: l10n.prefTitle, onBack: _exit, compact: true),
                          const SizedBox(height: 20),
                          Expanded(
                            child: ListView(
                              key: const PageStorageKey('pref-sections'),
                              padding: const EdgeInsets.only(bottom: 32),
                              children: [list],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ListView(
                        // A new section starts at its top.
                        key: PageStorageKey('pref-body-$open'),
                        padding: const EdgeInsets.only(bottom: 32),
                        children: [
                          card,
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, c) => KeyedSubtree(
                              key: ValueKey(open),
                              child: _body(open!, wide: c.maxWidth >= 640, onDone: _exit),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // Phone: the card and the list; a section opens on its own page.
        // System back on a section returns to the list first.
        return PopScope(
          canPop: open == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _section = null);
          },
          child: PayMenuPage(
            title: open != null ? open.label(l10n) : l10n.prefTitle,
            subtitle: open != null ? l10n.prefTitle : null,
            onBack: open != null ? () => setState(() => _section = null) : _exit,
            builder: (context, _) {
              if (open == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [card, const SizedBox(height: 16), list],
                );
              }
              return KeyedSubtree(
                key: ValueKey(open),
                child: _body(open, wide: false, onDone: () => setState(() => _section = null)),
              );
            },
          ),
        );
      },
    );
  }
}

/// Who is signed in: initials, name (from `me/party`), user id and the
/// last login — a quick fraud check.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.userName, required this.displayName, this.lastLogin});

  final String userName;
  final String displayName;
  final DateTime? lastLogin;

  static String _when(BuildContext context, DateTime t) {
    final local = t.toLocal();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '${payDate(local)}, $time';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(partyProfileProvider).valueOrNull;
    final name = profile?.displayName.isNotEmpty == true ? profile!.displayName : (displayName.isEmpty ? userName : displayName);
    const muted = TextStyle(color: Colors.white, fontSize: 12.5);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.primary(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ProfileAvatar(name: name, radius: 30, onDarkBackground: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(l10n.prefUserId(userName), style: muted.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                if (lastLogin != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.history_rounded, size: 14, color: Colors.white.withValues(alpha: 0.85)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.prefLastLogin(_when(context, lastLogin!)),
                          style: muted.copyWith(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ),
                    ],
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

/// The grouped section list, then Personalize Dashboard and Log out.
class _SectionList extends ConsumerWidget {
  const _SectionList({required this.selected, required this.onSelect, required this.onLogout, this.onPersonalize});

  /// The open section on wide layouts; null on a phone's list.
  final PrefSection? selected;
  final ValueChanged<PrefSection> onSelect;
  final VoidCallback? onPersonalize;
  final VoidCallback onLogout;

  /// A row's current value, where it is already in memory.
  String? _value(WidgetRef ref, AppLocalizations l10n, PrefSection s) {
    if (s != PrefSection.appearance) return null;
    final settings = ref.watch(appSettingsProvider);
    final mode = settings.themeMode == ThemeMode.dark ? l10n.darkTheme : l10n.lightTheme;
    return '$mode · ${settings.palette.label(l10n)} · ${LocaleConfig.displayName(l10n, settings.locale.languageCode)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final phone = selected == null;
    Widget group(String title, List<Widget> rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: HomeColors.textSecondary(context),
                ),
              ),
            ),
            // No box: the rows on the page, a line between each two.
            Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final (i, row) in rows.indexed) ...[
                    if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: HomeColors.divider(context)),
                    row,
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, sections) in _groups.indexed)
          group(_groupTitle(l10n, i), [
            for (final s in sections)
              _Row(
                icon: s.icon,
                title: s.label(l10n),
                subtitle: _value(ref, l10n, s) ?? (phone ? s.hint(l10n) : null),
                selected: s == selected,
                showChevron: phone,
                onTap: () => onSelect(s),
              ),
            if (i == _groups.length - 1 && onPersonalize != null)
              _Row(
                icon: Icons.dashboard_customize_outlined,
                title: l10n.menuPersonalizeDashboard,
                subtitle: phone ? l10n.prefPersonalizeHint : null,
                showChevron: phone,
                onTap: onPersonalize!,
              ),
          ]),
        Material(
          type: MaterialType.transparency,
          child: _Row(icon: Icons.logout_rounded, title: l10n.logOut, destructive: true, showChevron: false, onTap: onLogout),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.showChevron = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool showChevron;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final accent = destructive ? HomeColors.error(context) : brand;
    return Material(
      color: selected ? brand.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: selected,
        onTap: onTap,
        leading: Icon(icon, color: accent),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: destructive ? accent : (selected ? brand : HomeColors.textPrimary(context)),
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
        trailing: showChevron ? Icon(Icons.chevron_right_rounded, color: HomeColors.navInactive(context)) : null,
      ),
    );
  }
}
