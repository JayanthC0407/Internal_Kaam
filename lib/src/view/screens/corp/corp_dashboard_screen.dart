import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/session_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_account_summary_card.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_accounts_card.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_dashboard_header_bar.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_nav_content.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_navigation_sidebar.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_quick_links_card.dart';

/// Arguments for the Corporate dashboard.
///
/// Mirrors Retail's `HomeDashboardArgs` (which lives alongside its own
/// screen for the same reason) and is built from it by
/// `AuthenticatedHomeGate` once `me` resolves the user as `corporateuser`.
/// Keeping a corporate-specific args type is what lets the whole `corp/`
/// tree stay free of imports from the Retail dashboard.
class CorpDashboardArgs {
  const CorpDashboardArgs({
    required this.userName,
    this.loginTrace,
    this.initialDestination = CorpNavDestination.home,
  });

  final String userName;

  /// The login trace captured during sign-in. `loginTrace['profileResponse']`
  /// holds the `me` response the corporate profile is parsed from, so the
  /// header renders the real user without a second `me` call.
  final Map<String, dynamic>? loginTrace;

  final CorpNavDestination initialDestination;

  Map<String, dynamic>? get profileResponse =>
      loginTrace?['profileResponse'] as Map<String, dynamic>?;

  /// `displayName` recorded on the trace at login — used only as the
  /// fallback when the `me` response has no usable name.
  String get fallbackDisplayName {
    final displayName = loginTrace?['displayName']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return userName;
  }
}

/// The Corporate (`corporateuser`) dashboard.
///
/// Opened by `AuthenticatedHomeGate` when the `me` response resolves
/// `dashboardClassValue == corporateuser`; the Retail dashboard is
/// untouched. Layout follows the corporate design: a persistent left nav,
/// a top bar, then the Accounts card and Quick Links side by side above a
/// full-width Account Summary grid.
///
/// Data comes from the endpoints captured in the corporate
/// "LOGIN to DASHBOARD" HAR — see `CorpApiConst` for the per-endpoint
/// mapping. Nothing on this screen is mocked.
class CorpDashboardScreen extends ConsumerStatefulWidget {
  const CorpDashboardScreen({super.key, required this.args});

  final CorpDashboardArgs args;

  @override
  ConsumerState<CorpDashboardScreen> createState() =>
      _CorpDashboardScreenState();
}

class _CorpDashboardScreenState extends ConsumerState<CorpDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late CorpNavDestination _destination;

  @override
  void initState() {
    super.initState();
    _destination = widget.args.initialDestination;

    // The `me` response is already in hand from login — seed the profile
    // synchronously so the header's name and initials are correct on the
    // first frame, then confirm the party / bank configuration.
    ref
        .read(corpProfileProvider.notifier)
        .seedFromProfileResponse(widget.args.profileResponse);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(corpAccountsProvider.notifier).ensureLoaded();
      ref.read(corpProfileProvider.notifier).ensureLoaded();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(corpAccountsProvider.notifier).refresh(),
      ref.read(corpProfileProvider.notifier).refresh(),
    ]);
  }

  Future<void> _logout() async {
    await ref.read(sessionManagerProvider).logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RoutesConst.loginScreen,
      (route) => false,
    );
  }

  void _selectDestination(CorpNavDestination destination) {
    setState(() => _destination = destination);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _showUnavailable(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is not available yet.')),
    );
  }

  /// "View all …" and account taps land on the Accounts destination for
  /// now — the corporate account list / detail screens are the next thing
  /// to build behind this dashboard.
  void _openAccounts(CorpAccountGroup group) {
    _selectDestination(CorpNavDestination.accounts);
  }

  void _openAccount(CorpAccount account) {
    _selectDestination(CorpNavDestination.accounts);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final isDesktop = responsive.isDesktop;

    final shell = Column(
      children: [
        CorpDashboardHeaderBar(
          userName: widget.args.fallbackDisplayName,
          onLogout: _logout,
          onMenuTap: isDesktop
              ? null
              : () => _scaffoldKey.currentState?.openDrawer(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _buildDestination(responsive),
          ),
        ),
      ],
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: CorpColors.bg(context),
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: CorpColors.card(context),
              child: SafeArea(
                child: CorpNavContent(
                  selected: _destination,
                  onSelected: _selectDestination,
                ),
              ),
            ),
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  CorpNavigationSidebar(
                    selected: _destination,
                    onSelected: _selectDestination,
                  ),
                  Expanded(child: shell),
                ],
              )
            : shell,
      ),
    );
  }

  Widget _buildDestination(Responsive responsive) {
    if (_destination == CorpNavDestination.home) {
      return _buildHome(responsive);
    }
    return _CorpDestinationPlaceholder(destination: _destination);
  }

  Widget _buildHome(Responsive responsive) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Below this the two top panels stack; the design's side-by-side
        // arrangement needs room for a 4-across Quick Links grid next to
        // the account carousel.
        final sideBySide = width >= 900;
        final horizontalPadding = width < 600 ? 16.0 : 24.0;

        final accountsCard = CorpAccountsCard(
          onViewAll: _openAccounts,
          onAccountTap: _openAccount,
        );
        final quickLinks = CorpQuickLinksCard(onUnavailable: _showUnavailable);

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            28,
          ),
          child: ResponsiveBody(
            maxWidth: 1400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sideBySide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: accountsCard),
                      const SizedBox(width: 20),
                      Expanded(flex: 6, child: quickLinks),
                    ],
                  )
                else ...[
                  accountsCard,
                  const SizedBox(height: 20),
                  quickLinks,
                ],
                const SizedBox(height: 20),
                CorpAccountSummaryCard(onAccountTap: _openAccount),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder for the corporate destinations whose screens are not built
/// yet. Rendered *inside* the corporate shell so the nav, header, session
/// timeout and logout all stay live while those modules are developed.
class _CorpDestinationPlaceholder extends StatelessWidget {
  const _CorpDestinationPlaceholder({required this.destination});

  final CorpNavDestination destination;

  @override
  Widget build(BuildContext context) {
    // Scrollable so the enclosing RefreshIndicator still works here.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: CorpColors.brand(context).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    destination.icon,
                    size: 30,
                    color: CorpColors.brand(context),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  destination.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This corporate module is coming soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
