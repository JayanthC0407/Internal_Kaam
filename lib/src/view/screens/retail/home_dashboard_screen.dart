import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/casa_accounts_panel.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';

import 'home/home_colors.dart';
import 'home/tabs/insights_tab_screen.dart';
import 'home/tabs/more_tab_screen.dart';
import 'home/tabs/rewards_tab_screen.dart';
import 'home/tabs/transfer_tab_screen.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_descriptor.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_arrange.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/personalize_panel.dart';
import 'package:ubci_bank/src/view/screens/retail/dashboard_widgets/retail_widget_registry.dart';
import 'package:ubci_bank/src/view/widgets/sidebar_content_navigator.dart';

import 'package:ubci_bank/src/view/screens/common/navigation/dashboard_navigation.dart';
import 'home/widgets/home_content.dart';
import 'home/widgets/bottom_nav.dart';
import 'home/widgets/dashboard_header_bar.dart';
import 'home/widgets/top_hero_section.dart';
import 'home/widgets/retail_nav.dart';
// Payments, payees and transfers are shared with Corporate, so they live
// under `screens/common/` rather than in the Retail tree.
import '../common/payments/transfers_module_screen.dart';
import '../common/payments/transfer_money_screen.dart';
import '../common/payments/internal_payment_screen.dart';
import '../common/payments/adhoc_payee_transfer_screen.dart';
import '../common/payments/international_payment_screen.dart';
import '../common/payees/payee_hub_screen.dart';
import '../common/payees/add_bank_account_payee_screen.dart';
import '../common/payees/add_demand_draft_payee_screen.dart';
import '../common/payees/add_peer_to_peer_payee_screen.dart';
import '../common/payees/payees_screen.dart';
import '../common/transfer/own_account_transfer_screen.dart';

class HomeDashboardArgs {
  const HomeDashboardArgs({
    required this.userName,
    this.loginTrace,
    this.initialTab = 0,
  });

  final String userName;
  final Map<String, dynamic>? loginTrace;

  /// Bottom-nav / sidebar index. `0` is the Home dashboard.
  final int initialTab;
}

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.args,
  });

  final HomeDashboardArgs args;

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  final PageController _heroActionPager = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The web desktop content area's navigator — see
  /// [SidebarContentNavigator].
  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();

  int _heroSlideIndex = 0;
  int _selectedTopTabIndex = 0;
  late int _selectedBottomNavIndex;

  WebPayeeDestination? _selectedPayeeDestination;
  WebAccountsDestination? _selectedAccountsDestination;

  String? _selectedCasaAccountId;
  LoanAccount? _selectedLoanAccount;

  bool _addPayeeOpenedFromManage = false;

  /// Tab to return to once the Manage/Add-Payee flow (indices 5-8) is
  /// exited without landing back on Manage Payees — i.e. the tab that
  /// launched "Manage Payees" or an "Add ... Payee" screen directly. Set
  /// right before switching into that flow; defaults to the Dashboard for
  /// any caller that doesn't set it explicitly.
  int _payeeFlowHomeIndex = 0;

  /// Tab to return to when "Transfer Money" (index 13) is closed — it has
  /// two entry points (the Transfer tab's own "Transfer" Quick Action, and
  /// the "Transfers" module's "Transfer Money" tile), so this records
  /// which one was actually used. Set right before switching to 13.
  int _transferMoneyReturnIndex = 2;

  bool _hideTotalBalance = true;
  final Set<String> _revealedAccountIds = <String>{};

  void _toggleAccountVisibility(String accountKey) {
    setState(() {
      if (_revealedAccountIds.contains(accountKey)) {
        _revealedAccountIds.remove(accountKey);
      } else {
        _revealedAccountIds.add(accountKey);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedBottomNavIndex = widget.args.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
      ref.read(loanAccountsProvider.notifier).ensureLoaded();
      // Retail reads its dashboard descriptor straight off the `me`
      // response on the login trace — it has no typed profile model the
      // way Corporate does, and does not need one. A restored session
      // whose `me` call failed has no response here; that resolves as
      // "unknown", and personalization reads `me` itself.
      ref.read(personalizationProvider.notifier).ensureLoaded(
            DashboardDescriptorLookup.fromProfileResponse(
              widget.args.loginTrace?['profileResponse'],
            ),
            userKey: _signedInUserName(),
          );
    });
  }

  /// The signed-in user, for scoping personalization state.
  ///
  /// Read from the `me` response rather than [HomeDashboardArgs.userName],
  /// which is what was typed at login and can differ in case or spacing
  /// from the host's canonical user name.
  String _signedInUserName() {
    final profileResponse = widget.args.loginTrace?['profileResponse'];
    if (profileResponse is Map) {
      final body = profileResponse['body'];
      if (body is Map) {
        final userProfile = body['userProfile'];
        if (userProfile is Map) {
          final name = userProfile['userName']?.toString().trim();
          if (name != null && name.isNotEmpty) return name;
        }
      }
    }
    return widget.args.userName;
  }

  /// Which `componentName`s the Retail dashboard can draw.
  static const _registry = RetailWidgetRegistry();

  /// §17's segment half for Retail.
  static const _userSegment = 'retailuser';

  void _openPersonalize() => _scaffoldKey.currentState?.openEndDrawer();

  /// The Retail dashboard's widget area.
  ///
  /// Distinct states, which matter because they look different:
  ///
  ///  - **No personalizable dashboard**: the original hand-built
  ///    [HomeContent] layout, untouched. Its two-column arrangement and
  ///    widget sizes are a designed thing, and approximating it on the
  ///    12-column grid changed proportions users were already used to.
  ///  - **A dashboard that failed to load**: an error with Retry, not the
  ///    original layout — the saved layout is unknown, and the original
  ///    would put back widgets the user may have removed.
  ///  - **A saved configuration with widgets**: those widgets, on the grid,
  ///    at the sizes the configuration asks for.
  ///  - **A saved configuration with nothing selected**: empty, bar the
  ///    static widgets. A user who unselects everything means it — falling
  ///    back to a default set there put widgets back that they had just
  ///    removed.
  ///
  /// Filters on *authorization* and the registry, never the catalog: a
  /// saved layout can hold components the catalog has never listed.
  Widget _buildWidgetArea(
    CasaAccountsState accountsState, {
    required bool isWide,
  }) {
    final state = ref.watch(personalizationProvider);

    // The same decision the Corporate dashboard uses — see
    // [PersonalizationState.bodyStatus].
    switch (state.bodyStatus) {
      case PersonalizedBodyStatus.loading:
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        );
      case PersonalizedBodyStatus.unavailable:
        // No personalizable dashboard — keep the dashboard exactly as it
        // was before personalization existed.
        return _buildOriginalLayout(accountsState, isWide);
      case PersonalizedBodyStatus.loadFailed:
        return _withStaticWidgets(
          state,
          status: _buildBodyMessage(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load your dashboard",
            message: state.errorMessage ??
                'Your dashboard layout could not be loaded.',
            onRetry: () => ref.read(personalizationProvider.notifier).retry(),
          ),
        );
      case PersonalizedBodyStatus.authorizationFailed:
        return _withStaticWidgets(
          state,
          status: _buildBodyMessage(
            icon: Icons.lock_outline_rounded,
            title: "Couldn't load your widgets",
            message: state.authorizationError ??
                'Your widget permissions could not be checked.',
            onRetry: () => ref.read(personalizationProvider.notifier).retry(),
          ),
        );
      case PersonalizedBodyStatus.empty:
        return _withStaticWidgets(state, status: _buildNoWidgetsSelected());
      case PersonalizedBodyStatus.ready:
        break;
    }

    // Sizes come from the registry first — see
    // [DashboardWidgetRegistry.spanFor]. Pinned widgets (My Spendings) are
    // placed by [_withStaticWidgets] instead, so selecting one cannot draw
    // it twice, and unselecting everything cannot take it away.
    final tiles = [
      for (final item in state.visibleItems)
        if (!_registry.pinnedComponents.contains(item.componentName))
          _registry.tileFor(
            item,
            breakpoint: state.breakpoint,
            catalog: state.catalog,
            // Held and dropped elsewhere — see [DashboardArrange].
            draggable: true,
          ),
    ];

    // Everything renderable may have been a static widget.
    return tiles.isEmpty
        ? _withStaticWidgets(state, status: _buildNoWidgetsSelected())
        : _withStaticWidgets(
            state,
            tiles: tiles,
            onMove: DashboardArrange.isAvailable(ref)
                ? (dragged, target) => DashboardArrange.move(
                      context,
                      ref,
                      registry: _registry,
                      dragged: dragged,
                      target: target,
                    )
                : null,
          );
  }

  /// The personalized grid, laid out like the fixed Retail home: two
  /// columns, each widget in its own card, one column below the same width
  /// [HomeContent] switches at.
  ///
  /// My Spendings, which this dashboard always shows, takes the top-right
  /// slot it has on the fixed home — beside the first widget, or beside a
  /// [status] card when there are no widgets to show.
  Widget _withStaticWidgets(
    PersonalizationState state, {
    List<DashboardTile> tiles = const [],
    Widget? status,
    void Function(String dragged, String target)? onMove,
  }) {
    final spendings = _registry.tileFor(
      const DashboardLayoutItem(
        componentName: 'spend-summary',
        module: 'personal-finance-management',
      ),
      breakpoint: state.breakpoint,
      catalog: state.catalog,
    );
    final leading = [
      if (status != null)
        DashboardTile(span: 6, child: Center(child: status))
      else if (tiles.isNotEmpty)
        tiles.first,
    ];

    return DashboardTileGrid(
      layout: DashboardGridLayout.twoColumns,
      collapseBelow: 920,
      tileDecoration: RetailWidgetRegistry.tileDecoration,
      onMove: onMove,
      tiles: [
        ...leading,
        spendings,
        ...tiles.skip(status == null ? 1 : 0),
      ],
    );
  }

  Widget _buildBodyMessage({
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(icon, size: 30, color: HomeColors.navInactive(context)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: HomeColors.textSecondary(context),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }

  /// Shown when the user has deliberately unselected every widget.
  Widget _buildNoWidgetsSelected() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 30,
            color: HomeColors.navInactive(context),
          ),
          const SizedBox(height: 12),
          Text(
            'No widgets on your dashboard',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add some from Personalize Dashboard.',
            style: TextStyle(
              fontSize: 12.5,
              color: HomeColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// The dashboard as it was before personalization — the original
  /// [HomeContent] layout, with its own column arrangement and sizing.
  Widget _buildOriginalLayout(CasaAccountsState accountsState, bool isWide) {
    return HomeContent(
      selectedTopTabIndex: _selectedTopTabIndex,
      onTopTabSelected: (index) => setState(() => _selectedTopTabIndex = index),
      revealedAccountIds: _revealedAccountIds,
      onToggleAccountVisibility: _toggleAccountVisibility,
      accounts: accountsState.summary?.accounts ?? const [],
      accountsLoading: accountsState.isLoading,
      accountsError: accountsState.errorMessage,
      onRetryAccounts: () => ref.read(casaAccountsProvider.notifier).refresh(),
      onViewAllLoans: () =>
          _openAccountsDestination(WebAccountsDestination.loans),
      onViewAllAccountsTap: () =>
          _openAccountsDestination(WebAccountsDestination.casa),
      onCasaAccountTap: _openCasaAccountDetails,
      onLoanAccountTap: _openLoanAccountDetails,
      isWide: isWide,
      displayName: _displayNameFromTrace(),
      onTransferTap: () => setState(() => _selectedBottomNavIndex = 2),
    );
  }

  /// Side-sheet width — just the module headings.
  ///
  /// The widget flyout renders in the app overlay to the *left* of this
  /// panel, over the dashboard, so the panel stays narrow rather than
  /// reserving a column that is empty whenever no heading is open.
  double _personalizePanelWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return width * 0.92;
    return 320;
  }

  /// The Personalize side sheet, or null when `me` resolved no
  /// personalizable dashboard for this user.
  Widget? _buildPersonalizeDrawer() {
    if (ref.watch(personalizationProvider).isUnavailable) return null;
    return Drawer(
      backgroundColor: HomeColors.card(context),
      width: _personalizePanelWidth(context),
      shape: const RoundedRectangleBorder(),
      child: PersonalizePanel(
        userSegment: _userSegment,
        registry: _registry,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  void dispose() {
    _heroActionPager.dispose();
    super.dispose();
  }

  Future<void> _refreshHomeData() async {
    await Future.wait([
      ref.read(casaAccountsProvider.notifier).refresh(),
      ref.read(loanAccountsProvider.notifier).refresh(),
    ]);
    await ref.read(recentTransactionsWidgetProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final bg = HomeColors.bg(context);
    final accountsState = ref.watch(casaAccountsProvider);

    // Read and personalize the layout for this screen size, as Corporate
    // does. Without this Retail always used `large`, so a phone showed —
    // and saved over — the desktop layout. Post-frame: it mutates a
    // provider.
    final breakpoint = DashboardBreakpoint.forWidth(responsive.width);
    if (ref.read(personalizationProvider).breakpoint != breakpoint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(personalizationProvider.notifier).setBreakpoint(breakpoint);
      });
    }

    if (responsive.useWideHome) {
      final destination = _selectedBottomNavIndex == 0
          ? RefreshIndicator(
              onRefresh: _refreshHomeData,
              child: _buildWebDashboard(accountsState),
            )
          : _buildWideDestination(accountsState);
      // The shared top bar above every destination, as on Corporate — not
      // only above Home.
      final content = SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: destination),
          ],
        ),
      );
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: bg,
        drawer: responsive.isDesktop ? null : _buildNavDrawer(),
        endDrawer: _buildPersonalizeDrawer(),
        onEndDrawerChanged: (open) {
          if (!open) DashboardArrange.panelClosed(ref);
        },
        body: responsive.isDesktop
            ? Row(
                children: [
                  // The side menu both dashboards share, with Retail's
                  // entries. No Payee group: Payee has its own entry point
                  // on the Transfer tab, so it is not reachable two ways.
                  DashboardNavigationSidebar(
                    items: RetailNav.items(AppLocalizations.of(context)),
                    selectedId: _selectedNavId,
                    onSelected: _onNavSelected,
                    footer: RetailNav.footer(AppLocalizations.of(context)),
                  ),
                  // Screens opened from here open beside the sidebar on
                  // web, not over it.
                  Expanded(
                    child: SidebarContentNavigator(
                      navigatorKey: _contentNavigatorKey,
                      child: content,
                    ),
                  ),
                ],
              )
            : content,
        bottomNavigationBar: responsive.isDesktop
            ? null
            : BottomNav(
                selectedIndex: _selectedBottomNavIndex,
                onSelected: (index) =>
                    setState(() => _selectedBottomNavIndex = index),
              ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bg,
      drawer: _buildNavDrawer(),
      endDrawer: _buildPersonalizeDrawer(),
      onEndDrawerChanged: (open) {
        if (!open) DashboardArrange.panelClosed(ref);
      },
      body: RefreshIndicator(
        onRefresh: _refreshHomeData,
        child: _buildCurrentBody(accountsState),
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: _selectedBottomNavIndex,
        onSelected: (index) => setState(() => _selectedBottomNavIndex = index),
      ),
    );
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  /// Log out from the top bar's profile menu — the same flow as the
  /// Corporate dashboard's.
  Future<void> _logout() async {
    await ref.read(sessionManagerProvider).logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
      RoutesConst.loginScreen,
      (route) => false,
    );
  }

  void _openCasaAccountsList() {
    Navigator.of(context).pushNamed(RoutesConst.casaAccountsListScreen);
  }

  void _openLoanAccountsList() {
    Navigator.of(context).pushNamed(RoutesConst.loanAccountsListScreen);
  }

  /// "Accounts" ▸ CASA / Loans from the side panel / nav drawer. On the
  /// wide/desktop shell both destinations embed next to the persistent
  /// sidebar (CASA at index 9, Loans at index 10 — see
  /// [_buildWideDestination]); on phones, both push their own full screen
  /// since there's no sidebar to keep around.
  void _openAccountsDestination(WebAccountsDestination destination) {
    SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
    switch (destination) {
      case WebAccountsDestination.casa:
        // On the wide/desktop shell, CASA is embedded next to the persistent
        // sidebar so it never disappears. On phones there's no sidebar to
        // preserve, so it pushes its own full screen for a normal back-stack.
        if (Responsive.of(context).useWideHome) {
          setState(() {
            _selectedAccountsDestination = WebAccountsDestination.casa;
            _selectedPayeeDestination = null;
            _selectedCasaAccountId = null;
            _selectedLoanAccount = null;
            _selectedBottomNavIndex = 9;
          });
        } else {
          _selectedAccountsDestination = WebAccountsDestination.casa;
          _selectedPayeeDestination = null;
          _selectedLoanAccount = null;
          _openCasaAccountsList();
        }

      case WebAccountsDestination.loans:
        // On the wide/desktop shell, Loans is embedded next to the
        // persistent sidebar exactly like CASA (index 10) so the sidebar
        // never disappears. On phones there's no sidebar to preserve, so
        // it keeps pushing its own full screen for a normal back-stack.
        if (Responsive.of(context).useWideHome) {
          setState(() {
            _selectedAccountsDestination = WebAccountsDestination.loans;
            _selectedPayeeDestination = null;
            _selectedCasaAccountId = null;
            _selectedLoanAccount = null;
            _selectedBottomNavIndex = 10;
          });
        } else {
          _selectedAccountsDestination = WebAccountsDestination.loans;
          _selectedPayeeDestination = null;
          _selectedCasaAccountId = null;
          _openLoanAccountsList();
        }
    }
  }

  /// Opens a CASA account's details from a Home-tab preview tap. On the
  /// wide/desktop shell it embeds next to the persistent sidebar (index 9,
  /// same destination [_openAccountsDestination] uses) so the sidebar never
  /// disappears; on phones it pushes [CasaAccountDetailsScreen] directly.
  void _openCasaAccountDetails(CasaAccount account) {
    if (Responsive.of(context).useWideHome) {
      setState(() {
        _selectedAccountsDestination = WebAccountsDestination.casa;
        _selectedCasaAccountId = account.id;
        _selectedPayeeDestination = null;
        _selectedLoanAccount = null;
        _selectedBottomNavIndex = 9;
      });
    } else {
      Navigator.of(context).pushNamed(
        RoutesConst.casaAccountDetailsScreen,
        arguments: CasaAccountDetailsArgs(accountId: account.id),
      );
    }
  }

  /// Same idea for a Loan account tapped from a Home-tab preview — embeds
  /// at index 10 on wide/desktop, otherwise pushes
  /// [LoanAccountDetailsScreen] directly.
  void _openLoanAccountDetails(LoanAccount loan) {
    if (Responsive.of(context).useWideHome) {
      setState(() {
        _selectedAccountsDestination = WebAccountsDestination.loans;
        _selectedLoanAccount = loan;
        _selectedPayeeDestination = null;
        _selectedCasaAccountId = null;
        _selectedBottomNavIndex = 10;
      });
    } else {
      Navigator.of(context).pushNamed(
        RoutesConst.loanAccountDetailsScreen,
        arguments: LoanAccountDetailsArgs(loan: loan),
      );
    }
  }

  /// Bottom-nav index that renders the given Payee destination.
  int _navIndexForPayeeDestination(WebPayeeDestination destination) {
    switch (destination) {
      case WebPayeeDestination.manage:
        return 5;
      case WebPayeeDestination.add:
        return 6;
      case WebPayeeDestination.addDemandDraft:
        return 7;
      case WebPayeeDestination.addPeerToPeer:
        return 8;
    }
  }

  /// Hamburger drawer — below desktop width. The same shared menu as the
  /// desktop sidebar, driving the same state the bottom nav does, so all
  /// three stay in sync.
  Widget _buildNavDrawer() {
    final l10n = AppLocalizations.of(context);
    return DashboardNavDrawer(
      items: RetailNav.items(l10n),
      selectedId: _selectedNavId,
      onSelected: _onNavSelected,
      footer: RetailNav.footer(l10n),
    );
  }

  /// The side menu's selection, from the tab and accounts state.
  String? get _selectedNavId {
    switch (_selectedAccountsDestination) {
      case WebAccountsDestination.casa:
        return RetailNav.accountsCasa;
      case WebAccountsDestination.loans:
        return RetailNav.accountsLoans;
      case null:
        break;
    }
    final index = _selectedBottomNavIndex;
    // Tabs past the first five are screens opened from within one (payees,
    // transfers), which the menu has no entry for.
    return index < RetailNav.tabIds.length ? RetailNav.tabIds[index] : null;
  }

  void _onNavSelected(String id) {
    switch (id) {
      case RetailNav.accountsCasa:
        _openAccountsDestination(WebAccountsDestination.casa);
        return;
      case RetailNav.accountsLoans:
        _openAccountsDestination(WebAccountsDestination.loans);
        return;
    }
    final index = RetailNav.tabIds.indexOf(id);
    if (index < 0) return;
    // A menu choice replaces whatever was opened on top.
    SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
    setState(() {
      _selectedBottomNavIndex = index;
      _selectedPayeeDestination = null;
      _selectedAccountsDestination = null;
      _selectedCasaAccountId = null;
      _selectedLoanAccount = null;
    });
  }

  /// The shared top bar — the same one Corporate shows.
  Widget _buildTopBar() {
    return WebDashboardHeaderBar(
      displayName: _displayNameFromTrace(),
      userId: _signedInUserName(),
      onLogout: _logout,
      onMenuTap: Responsive.of(context).isDesktop ? null : _openMenu,
      // Personalize applies to Home, so it is offered only there.
      onPersonalizeDashboard: _selectedBottomNavIndex != 0 ||
              ref.watch(personalizationProvider).isUnavailable
          ? null
          : _openPersonalize,
    );
  }

  Widget _buildCurrentBody(CasaAccountsState accountsState) {
    switch (_selectedBottomNavIndex) {
      case 1:
        return const InsightsTabScreen();
      case 2:
        return TransferTabScreen(
          onOwnAccountTransferTap: () =>
              setState(() => _selectedBottomNavIndex = 11),
          onTransfersTap: () => setState(() => _selectedBottomNavIndex = 12),
          onPayeeHubTap: () => setState(() => _selectedBottomNavIndex = 14),
          onTransferMoneyTap: () => setState(() {
            _transferMoneyReturnIndex = 2;
            _selectedBottomNavIndex = 13;
          }),
        );
      case 3:
        return const RewardsTabScreen();
      case 4:
        return const MoreTabScreen();
      case 5:
        return PayeesScreen(
          embedded: true,
          onAddPayee: (flow) => setState(() {
            _addPayeeOpenedFromManage = true;
            _selectedPayeeDestination = switch (flow) {
              AddPayeeFlow.bankAccount => WebPayeeDestination.add,
              AddPayeeFlow.demandDraft => WebPayeeDestination.addDemandDraft,
              AddPayeeFlow.peerToPeer => WebPayeeDestination.addPeerToPeer,
            };
            _selectedBottomNavIndex = switch (flow) {
              AddPayeeFlow.bankAccount => 6,
              AddPayeeFlow.demandDraft => 7,
              AddPayeeFlow.peerToPeer => 8,
            };
          }),
          onBack: () => setState(() {
            _selectedPayeeDestination = null;
            _selectedBottomNavIndex = _payeeFlowHomeIndex;
          }),
        );
      case 6:
        return AddBankAccountPayeeScreen(
          embedded: true,
          onBack: () => setState(() => _returnFromAddPayee()),
          onCompleted: () => setState(() => _returnFromAddPayee()),
        );
      case 7:
        return AddDemandDraftPayeeScreen(
          embedded: true,
          onBack: () => setState(() => _returnFromAddPayee()),
          onCompleted: () => setState(() => _returnFromAddPayee()),
        );
      case 8:
        return AddPeerToPeerPayeeScreen(
          embedded: true,
          onBack: () => setState(() => _returnFromAddPayee()),
          onCompleted: () => setState(() => _returnFromAddPayee()),
        );
      case 11:
        // "Between My Accounts" — embedded (per the widget's own
        // "Push on top of home (embedded tab)" / "Never replace" comments,
        // this was clearly meant to run this way) so the drawer/sidebar
        // stays visible instead of a pushed full screen covering it.
        return OwnAccountTransferScreen(
          embedded: true,
          onClose: () => setState(() => _selectedBottomNavIndex = 2),
        );
      case 12:
        // "Transfers" (Transfer Money / Adhoc Payee module) — same reasoning
        // as case 11. "Transfer Money" itself is now also embedded (case 13),
        // and so are the deeper steps reached from there and from here
        // (Existing Payee 15, Adhoc Payee 16, International Low Value
        // Payment 17) — all embedded so the sidebar/drawer stays visible
        // all the way through.
        return TransfersModuleScreen(
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 2),
          onTransferMoneyTap: () => setState(() {
            _transferMoneyReturnIndex = 12;
            _selectedBottomNavIndex = 13;
          }),
          onInternationalPaymentTap: () =>
              setState(() => _selectedBottomNavIndex = 17),
        );
      case 13:
        // "Transfer Money" (Existing/Adhoc Payee chooser) — same reasoning
        // as case 12. Reachable from two places (the Transfer tab's
        // "Transfer" Quick Action, and the "Transfers" module's own
        // "Transfer Money" tile) so it returns to whichever one was
        // actually used (see [_transferMoneyReturnIndex]) instead of a
        // fixed tab.
        return TransferMoneyScreen(
          embedded: true,
          onBack: () => setState(
              () => _selectedBottomNavIndex = _transferMoneyReturnIndex),
          onExistingPayeeTap: () =>
              setState(() => _selectedBottomNavIndex = 15),
          onAdhocPayeeTap: () => setState(() => _selectedBottomNavIndex = 16),
        );
      case 15:
        // "Existing Payee" transfer, reached from Transfer Money (13) —
        // embedded so the sidebar/drawer never disappears here either.
        return InternalPaymentScreen(
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 13),
        );
      case 16:
        // "Adhoc Payee" transfer, reached from Transfer Money (13) — same
        // reasoning as case 15.
        return AdhocPayeeTransferScreen(
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 13),
        );
      case 17:
        // "International Low Value Payment", reached from the Transfers
        // module (12) directly (not via Transfer Money) — same reasoning
        // as case 15/16.
        return InternationalPaymentScreen(
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 12),
        );
      case 14:
        // "Payee" hub — reached directly from the Transfer tab (Quick
        // Actions and Payment Services), now embedded the same way. The
        // separate Payee accordion in the nav drawer/sidebar was removed
        // since this is already reachable from here.
        //
        // Its four items (Manage Payees / Add Account / Add Draft / Add
        // Peer To Peer) route into the existing embedded tabs 5-8 instead
        // of pushing a route, so they keep the hamburger/sidebar too.
        // _payeeFlowHomeIndex records that they were opened from here (14)
        // rather than Manage Payees itself, so their own back/complete
        // handlers return to this hub instead of the Dashboard.
        return PayeeHubScreen(
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 2),
          onManagePayeesTap: () => setState(() {
            _payeeFlowHomeIndex = 14;
            _selectedBottomNavIndex = 5;
          }),
          onAddAccountPayeeTap: () => setState(() {
            _payeeFlowHomeIndex = 14;
            _addPayeeOpenedFromManage = false;
            _selectedBottomNavIndex = 6;
          }),
          onAddDraftPayeeTap: () => setState(() {
            _payeeFlowHomeIndex = 14;
            _addPayeeOpenedFromManage = false;
            _selectedBottomNavIndex = 7;
          }),
          onAddPeerToPeerPayeeTap: () => setState(() {
            _payeeFlowHomeIndex = 14;
            _addPayeeOpenedFromManage = false;
            _selectedBottomNavIndex = 8;
          }),
        );
      case 0:
      default:
        return _buildHomeBody(accountsState);
    }
  }

  /// Shared back/complete handler for the three "Add Payee" screens
  /// (Bank Account / Demand Draft / Peer To Peer): returns to Manage Payee
  /// when opened from there, otherwise back to whichever tab launched the
  /// Add-Payee screen directly (see [_payeeFlowHomeIndex]).
  void _returnFromAddPayee() {
    if (_addPayeeOpenedFromManage) {
      _selectedPayeeDestination = WebPayeeDestination.manage;
      _selectedBottomNavIndex = 5;
    } else {
      _selectedPayeeDestination = null;
      _selectedBottomNavIndex = _payeeFlowHomeIndex;
    }
    _addPayeeOpenedFromManage = false;
  }

  Widget _buildHomeBody(CasaAccountsState accountsState) {
    final displayName = _displayNameFromTrace();
    final summary = accountsState.summary;
    final balanceText = _heroBalanceText(summary);
    final balanceSubtitle = _heroBalanceSubtitle(context, summary);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: TopHeroSection(
            displayName: displayName,
            hideBalance: _hideTotalBalance,
            currentActionSlide: _heroSlideIndex,
            actionPageController: _heroActionPager,
            onToggleBalance: () =>
                setState(() => _hideTotalBalance = !_hideTotalBalance),
            onActionSlideChanged: (index) =>
                setState(() => _heroSlideIndex = index),
            onTransferTap: () => setState(() => _selectedBottomNavIndex = 2),
            onProfileTap: () => setState(() => _selectedBottomNavIndex = 4),
            onMenuTap: _openMenu,
            balanceText: balanceText,
            balanceSubtitle: balanceSubtitle,
            isBalanceLoading: accountsState.isLoading,
          ),
        ),
        SliverToBoxAdapter(
          child: _buildWidgetArea(accountsState, isWide: false),
        ),
      ],
    );
  }

  /// The Home destination on wide screens. The top bar above it belongs to
  /// the shell — see [_buildTopBar].
  Widget _buildWebDashboard(CasaAccountsState accountsState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            width < 900 ? 20 : 30,
            32,
            width < 900 ? 20 : 30,
            32,
          ),
          // Dashboard content — keep max width 1400
          child: ResponsiveBody(
            maxWidth: 1400,
            child: _buildWidgetArea(accountsState, isWide: true),
          ),
        );
      },
    );
  }

  Widget _buildWebBalanceCard({
    required AppLocalizations l10n,
    required CasaAccountsSummary? summary,
    required String balanceText,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: AppGradients.primary(context),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26003D37),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  summary?.primaryCurrency ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.totalBalance,
            style: const TextStyle(
              color: Color(0xBFFFFFFF),
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Flexible(
                child: Text(
                  _hideTotalBalance ? '******' : balanceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () =>
                    setState(() => _hideTotalBalance = !_hideTotalBalance),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x22FFFFFF),
                ),
                icon: Icon(
                  _hideTotalBalance
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _heroBalanceSubtitle(context, summary) ??
                l10n.availableBalanceLabel,
            style: const TextStyle(
              color: Color(0xBFFFFFFF),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebAccountsPreview({
    required CasaAccountsState accountsState,
    required List<CasaAccount> accounts,
  }) {
    final l10n = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeColors.divider(context)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.accounts,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _selectedTopTabIndex = 1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.viewAll,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HomeColors.brand(context),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: HomeColors.brand(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          CasaAccountsPanel(
            accounts: accounts.take(2).toList(growable: false),
            revealedAccountIds: _revealedAccountIds,
            onToggleAccountVisibility: _toggleAccountVisibility,
            isLoading: accountsState.isLoading,
            errorMessage: accountsState.errorMessage,
            onRetry: () => ref.read(casaAccountsProvider.notifier).refresh(),
          ),
        ],
      ),
    );
  }

  Widget _buildWideDestination(CasaAccountsState accountsState) {
    switch (_selectedBottomNavIndex) {
      case 9:
        if (_selectedCasaAccountId != null) {
          return SafeArea(
            child: CasaAccountDetailsScreen(
              accountId: _selectedCasaAccountId!,
              embedded: true,
              onBack: () {
                setState(() {
                  _selectedCasaAccountId = null;
                });
              },
            ),
          );
        }

        return SafeArea(
          child: CasaAccountsListScreen(
            embedded: true,
            onAccountSelected: (account) {
              setState(() {
                _selectedCasaAccountId = account.id;
              });
            },
            onBack: () {
              setState(() {
                _selectedAccountsDestination = null;
                _selectedCasaAccountId = null;
                _selectedPayeeDestination = null;
                _selectedBottomNavIndex = 0;
              });
            },
          ),
        );

      case 10:
        if (_selectedLoanAccount != null) {
          return SafeArea(
            child: LoanAccountDetailsScreen(
              args: LoanAccountDetailsArgs(loan: _selectedLoanAccount!),
              embedded: true,
              onBack: () {
                setState(() {
                  _selectedLoanAccount = null;
                });
              },
            ),
          );
        }

        return SafeArea(
          child: LoanAccountsListScreen(
            embedded: true,
            onLoanSelected: (loan) {
              setState(() {
                _selectedLoanAccount = loan;
              });
            },
            onBack: () {
              setState(() {
                _selectedAccountsDestination = null;
                _selectedLoanAccount = null;
                _selectedPayeeDestination = null;
                _selectedBottomNavIndex = 0;
              });
            },
          ),
        );

      default:
        return SafeArea(
          child: _buildCurrentBody(accountsState),
        );
    }
  }

  String? _heroBalanceText(CasaAccountsSummary? summary) {
    if (summary == null) return null;
    final currency = summary.primaryCurrency;
    final total = summary.primaryTotal;
    if (currency == null || total == null) return null;
    return MoneyFormat.format(total, currencyCode: currency);
  }

  String? _heroBalanceSubtitle(
    BuildContext context,
    CasaAccountsSummary? summary,
  ) {
    final l10n = AppLocalizations.of(context);
    if (summary == null) return null;
    if (summary.hasMultipleCurrencies) {
      return l10n.accountsMultipleCurrencies;
    }
    final currency = summary.primaryCurrency;
    if (currency == null || currency.isEmpty) {
      return l10n.availableBalanceLabel;
    }
    return '${l10n.availableBalanceLabel} · $currency';
  }

  String _displayNameFromTrace() {
    final displayName =
        widget.args.loginTrace?['displayName']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final profileResponse = widget.args.loginTrace?['profileResponse'];
    if (profileResponse is! Map<String, dynamic>) return widget.args.userName;

    final body = profileResponse['body'];
    if (body is! Map<String, dynamic>) return widget.args.userName;

    final userProfile = body['userProfile'];
    if (userProfile is! Map<String, dynamic>) return widget.args.userName;

    final first = (userProfile['firstName'] ?? '').toString().trim();
    final last = (userProfile['lastName'] ?? '').toString().trim();
    final full = [first, last].where((e) => e.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;

    final exactUserName = (userProfile['userName'] ?? '').toString().trim();
    return exactUserName.isNotEmpty ? exactUserName : widget.args.userName;
  }
}
