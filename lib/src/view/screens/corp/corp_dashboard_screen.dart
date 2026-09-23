import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/models/corp/corp_dashboard_config.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_grid_span.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_personalization_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/session_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_personalize_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_currency_exposure_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_financial_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_pickup_points_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart';
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

    // Both of these mutate providers, so they have to run after the first
    // frame — Riverpod throws if a provider is modified while the widget
    // tree is building, `initState` included.
    //
    // The `me` response captured at login is handed to the profile
    // notifier here so it can seed the header's name and initials without
    // waiting on the network; `CorpDashboardHeaderBar` renders
    // `args.fallbackDisplayName` for the one frame before that lands.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(corpAccountsProvider.notifier).ensureLoaded();
      ref
          .read(corpProfileProvider.notifier)
          .ensureLoaded(profileResponse: widget.args.profileResponse);
      // Personalization needs the profile's dashboard descriptors, which
      // the seed above has just parsed from the login trace.
      ref.read(corpPersonalizationProvider.notifier).ensureLoaded(
            ref.read(corpProfileProvider).profile,
          );
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

  /// Opens the Personalize panel as a side sheet rather than a full page,
  /// so the dashboard stays visible behind it and updates live as widgets
  /// are saved.
  void _openPersonalize() => _scaffoldKey.currentState?.openEndDrawer();

  /// §17's segment half. `corporateuser` is the role that routed us to this
  /// dashboard, so it is the segment the catalog is filtered against.
  String get _userSegment {
    final roles = ref.read(corpProfileProvider).profile?.roles ?? const [];
    for (final role in roles) {
      if (role.toLowerCase() == 'corporateuser') return role;
    }
    return 'corporateuser';
  }

  /// Side-sheet width: a comfortable fixed panel on desktop, near-full
  /// width on a phone where a 400px sheet would leave a useless sliver.
  static double _personalizePanelWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return width * 0.92;
    return 420;
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
          // Hidden when `me` resolved no personalizable dashboard, rather
          // than opening a screen with nothing to save to.
          onPersonalizeDashboard:
              ref.watch(corpPersonalizationProvider).isUnavailable ||
                      _destination != CorpNavDestination.home
                  ? null
                  : _openPersonalize,
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
      // Personalize opens as a side sheet so the dashboard stays on screen
      // behind it and re-renders the moment a change is saved.
      endDrawer: ref.watch(corpPersonalizationProvider).isUnavailable
          ? null
          : Drawer(
              backgroundColor: CorpColors.card(context),
              width: _personalizePanelWidth(context),
              shape: const RoundedRectangleBorder(),
              child: CorpPersonalizePanel(
                userSegment: _userSegment,
                onClose: () => Navigator.of(context).pop(),
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

  /// The dashboard body below the accounts hero, rendered from the user's
  /// saved configuration for the current breakpoint.
  ///
  /// Falls back to the designed default arrangement whenever personalization
  /// is unavailable — still loading, failed to load, or the user has no
  /// personalizable dashboard — so the dashboard is never blank.
  ///
  /// Note the render path filters on *authorization* and the registry, not
  /// on the catalog: a saved layout can legitimately hold components the
  /// catalog has never listed (5 of the 10 on the captured dashboard), and
  /// dropping those would silently gut a dashboard the user built.
  List<_DashboardTile> _buildPersonalizedTiles(bool sideBySide) {
    final state = ref.watch(corpPersonalizationProvider);
    final items = state.selectedItems;

    if (!state.isReady || items.isEmpty) {
      return _buildDefaultTiles(sideBySide);
    }

    final authorized = state.authorized;
    final tiles = <_DashboardTile>[];
    for (final item in items) {
      if (authorized.isNotEmpty && !authorized.contains(item.componentName)) {
        continue;
      }
      // Width comes from the item's own stored `style` first, then the
      // catalog's width for this breakpoint — so a dashboard arranged on
      // the web keeps its proportions here.
      final span = sideBySide
          ? CorpGridSpan.resolve(
              style: item.style,
              catalogWidth: state.catalog
                  .byName(item.componentName)
                  ?.widthFor(_catalogWidthKey(state.breakpoint)),
            )
          : CorpGridSpan.columns;
      tiles.add(
        _DashboardTile(
          span: span,
          child: CorpWidgetRegistry.build(item.componentName),
        ),
      );
    }

    if (tiles.isEmpty) return _buildDefaultTiles(sideBySide);
    return tiles;
  }

  static String _catalogWidthKey(CorpLayoutBreakpoint breakpoint) {
    switch (breakpoint) {
      case CorpLayoutBreakpoint.small:
        return 'small';
      case CorpLayoutBreakpoint.medium:
        return 'medium';
      case CorpLayoutBreakpoint.large:
      case CorpLayoutBreakpoint.defaultLayout:
        return 'large';
    }
  }

  /// The designed arrangement, used when there is no saved configuration to
  /// render — so the dashboard is never blank.
  List<_DashboardTile> _buildDefaultTiles(bool sideBySide) {
    final half = sideBySide ? 6 : CorpGridSpan.columns;
    return [
      _DashboardTile(
        span: sideBySide ? 6 : CorpGridSpan.columns,
        child: const CorpQuickLinksCard(),
      ),
      _DashboardTile(
        span: CorpGridSpan.columns,
        child: const CorpFinancialSummaryWidget(),
      ),
      _DashboardTile(span: half, child: const CorpCurrencyExposureWidget()),
      _DashboardTile(span: half, child: const CorpPickupPointsWidget()),
      _DashboardTile(
        span: CorpGridSpan.columns,
        child: CorpAccountSummaryCard(onAccountTap: _openAccount),
      ),
    ];
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

        // Both mobile and desktop are supported, so the layout the user
        // reads and personalizes is the one matching the screen they are
        // actually on — the same mapping the web client uses.
        final breakpoint = CorpLayoutBreakpoint.forWidth(
          MediaQuery.of(context).size.width,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(corpPersonalizationProvider.notifier)
              .setBreakpoint(breakpoint);
        });

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
            child: LayoutBuilder(
              builder: (context, inner) {
                // The accounts hero is not personalizable — it is the
                // account context selector, and OBDX has no component name
                // that maps to it — so it leads the grid at a fixed span.
                // Quick Links is NOT placed here: it is the catalog's
                // `account-quick-links`, so it arrives through the saved
                // configuration like any other widget. Hard-coding it here
                // as well is what made it render twice.
                final tiles = <_DashboardTile>[
                  _DashboardTile(
                    span: sideBySide ? 5 : CorpGridSpan.columns,
                    child: CorpAccountsCard(
                      onViewAll: _openAccounts,
                      onAccountTap: _openAccount,
                    ),
                  ),
                  ..._buildPersonalizedTiles(sideBySide),
                ];

                return _DashboardGrid(
                  tiles: tiles,
                  available: inner.maxWidth,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// One widget on the dashboard, with the number of grid columns it spans.
class _DashboardTile {
  const _DashboardTile({required this.span, required this.child});

  /// Columns out of [CorpGridSpan.columns].
  final int span;
  final Widget child;
}

/// Lays dashboard tiles out on OBDX's 12-column grid.
///
/// Uses a [Wrap] rather than a fixed Row/Column so a row fills up and
/// overflows naturally — matching how the web grid reflows, and meaning the
/// dashboard never overflows horizontally however the user arranges it.
class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.tiles, required this.available});

  final List<_DashboardTile> tiles;
  final double available;

  static const double _gap = 20;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _gap,
      runSpacing: _gap,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        for (final tile in tiles)
          SizedBox(
            width: CorpGridSpan.widthFor(
              span: tile.span,
              available: available,
              gap: _gap,
            ),
            child: tile.child,
          ),
      ],
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
