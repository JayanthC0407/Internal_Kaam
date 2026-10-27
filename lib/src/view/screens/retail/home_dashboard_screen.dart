import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/infra/security/device_security_models.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/term_deposit_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/term_deposits_list_screen.dart';
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
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/add_biller_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/bill_payment_history_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/bill_payments_hub_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/billers_screen.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/credit_card_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/credit_cards_hub_screen.dart';
import 'package:ubci_bank/src/view/screens/common/mailbox/mailbox_screen.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/preferences_screen.dart';
import 'package:ubci_bank/src/view/screens/common/service_requests/service_requests_screen.dart';
import 'package:ubci_bank/src/view/providers/common/mailbox_providers.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/credit_cards_screen.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_arrange.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/personalize_sheet.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/personalize_panel.dart';
import 'package:ubci_bank/src/view/screens/retail/dashboard_widgets/retail_dashboard_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/dashboard_widgets/retail_widget_registry.dart';
import 'package:ubci_bank/src/view/widgets/sidebar_content_navigator.dart';

import 'package:ubci_bank/src/view/screens/common/navigation/dashboard_navigation.dart';
import 'home/widgets/home_content.dart';
import 'home/widgets/bottom_nav.dart';
import 'home/widgets/dashboard_header_bar.dart';
import 'home/widgets/accounts_tab_card.dart';
import 'home/widgets/quick_actions_strip.dart';
import 'home/widgets/retail_nav.dart';
// Payments, payees and transfers are shared with Corporate, so they live
// under `screens/common/` rather than in the Retail tree.
import '../common/payments/transfers_module_screen.dart';
import '../common/payments/transfer_money_screen.dart';
import '../common/payments/multiple_transfers_screen.dart';
import '../common/payments/network_transfer_screen.dart';
import '../common/payments/other_transfers_screen.dart';
import '../common/payments/repeat_transfers_screen.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The web desktop content area's navigator — see
  /// [SidebarContentNavigator].
  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();

  int _selectedTopTabIndex = 0;
  late int _selectedBottomNavIndex;

  WebPayeeDestination? _selectedPayeeDestination;
  WebAccountsDestination? _selectedAccountsDestination;

  String? _selectedCasaAccountId;
  LoanAccount? _selectedLoanAccount;
  TermDeposit? _selectedTermDeposit;

  bool _addPayeeOpenedFromManage = false;

  /// Tab to return to once the Manage/Add-Payee flow (indices 5-8) is
  /// exited without landing back on Manage Payees — i.e. the tab that
  /// launched "Manage Payees" or an "Add ... Payee" screen directly. Set
  /// right before switching into that flow; defaults to the Dashboard for
  /// any caller that doesn't set it explicitly.
  int _payeeFlowHomeIndex = 0;

  /// Tab to return to when "Transfer Money" (index 13) is closed. Nothing
  /// opens 13 since the Transfer hub replaced its chooser (the hub starts
  /// each kind of transfer directly); 13, 15, 16 and 17 stay until the old
  /// chooser screens are removed.
  final int _transferMoneyReturnIndex = 2;

  /// The payee transfer shown at index 19, chosen from the Transfers menu.
  NetworkTransferMode _transferMode = NetworkTransferMode.existingPayee;

  /// The saved payee picked on the Transfer hub's payee strip, for 19.
  TransferPayee? _transferPayee;

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

  /// A bottom sheet on phones, the side panel elsewhere — see
  /// [PersonalizeLauncher].
  void _openPersonalize() {
    PersonalizeLauncher.open(
      context,
      scaffold: _scaffoldKey.currentState,
      userSegment: _userSegment,
      registry: _registry,
      onClosed: () {
        if (mounted) DashboardArrange.panelClosed(ref);
      },
    );
  }

  /// Preferences → Personalize Dashboard, its only entry point: Home first,
  /// so the customer sees the widgets they are arranging.
  void _personalizeFromPreferences() {
    SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
    setState(() => _selectedBottomNavIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openPersonalize();
    });
  }

  /// `userProfile.lastLoginTime` from the `me` response, when sent.
  DateTime? _lastLoginFromTrace() {
    final profileResponse = widget.args.loginTrace?['profileResponse'];
    if (profileResponse is! Map) return null;
    final body = profileResponse['body'];
    final userProfile = body is Map ? body['userProfile'] : null;
    if (userProfile is! Map) return null;
    return DateTime.tryParse(userProfile['lastLoginTime']?.toString() ?? '');
  }

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

    if (state.bodyStatus == PersonalizedBodyStatus.unavailable) {
      // No personalizable dashboard — keep the dashboard exactly as it was
      // before personalization existed.
      return _buildOriginalLayout(accountsState, isWide);
    }

    final area = _buildPersonalizedArea(state);
    if (isWide) return area;

    // Phone: the original home's rounded panel, drawn 16 px up over the
    // hero, with its 20 px margins — see [HomeContent] — so a personalized
    // dashboard looks like the fixed one. Personalize opens from My
    // Preferences only.
    return Transform.translate(
      offset: const Offset(0, -16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomeColors.bg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              area,
            ],
          ),
        ),
      ),
    );
  }

  /// The personalized widgets, or the state standing in for them — the
  /// same decision the Corporate dashboard makes, see
  /// [PersonalizationState.bodyStatus].
  Widget _buildPersonalizedArea(
    PersonalizationState state, {
    bool includeAccounts = true,
  }) {
    switch (state.bodyStatus) {
      case PersonalizedBodyStatus.loading:
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        );
      case PersonalizedBodyStatus.unavailable:
        // Handled by [_buildWidgetArea], which shows the original layout.
        return const SizedBox.shrink();
      case PersonalizedBodyStatus.loadFailed:
        return _withStaticWidgets(
          state,
          includeAccounts: includeAccounts,
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
          includeAccounts: includeAccounts,
          status: _buildBodyMessage(
            icon: Icons.lock_outline_rounded,
            title: "Couldn't load your widgets",
            message: state.authorizationError ??
                'Your widget permissions could not be checked.',
            onRetry: () => ref.read(personalizationProvider.notifier).retry(),
          ),
        );
      case PersonalizedBodyStatus.empty:
        return _withStaticWidgets(
          state,
          includeAccounts: includeAccounts,
          status: _buildNoWidgetsSelected(),
        );
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
        ? _withStaticWidgets(
            state,
            includeAccounts: includeAccounts,
            status: _buildNoWidgetsSelected(),
          )
        : _withStaticWidgets(
            state,
            includeAccounts: includeAccounts,
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
  /// The two widgets this dashboard always shows keep the slots they have
  /// on the fixed home: the accounts carousel top left, My Spendings top
  /// right. Neither can be dragged. The user's widgets follow them, or a
  /// full-width [status] card when there are none to show.
  Widget _withStaticWidgets(
    PersonalizationState state, {
    List<DashboardTile> tiles = const [],
    Widget? status,
    void Function(String dragged, String target)? onMove,
    bool includeAccounts = true,
  }) {
    // Draws its own card, like on the fixed home.
    const accounts = DashboardTile(
      span: 6,
      framed: false,
      child: RetailAccountsWidget(),
    );
    final spendings = _registry.tileFor(
      const DashboardLayoutItem(
        componentName: 'spend-summary',
        module: 'personal-finance-management',
      ),
      breakpoint: state.breakpoint,
      catalog: state.catalog,
    );

    return DashboardTileGrid(
      layout: DashboardGridLayout.twoColumns,
      collapseBelow: 920,
      tileDecoration: RetailWidgetRegistry.tileDecoration,
      onMove: onMove,
      tiles: [
        if (includeAccounts) accounts,
        spendings,
        if (status != null)
          DashboardTile(span: 12, child: Center(child: status)),
        ...tiles,
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
  Widget _buildOriginalLayout(
    CasaAccountsState accountsState,
    bool isWide, {
    bool showAccountCard = true,
  }) {
    return HomeContent(
      showAccountCard: showAccountCard,
      onSpendingsTap: () => setState(() => _selectedBottomNavIndex = 1),
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
      onDepositTap: _openTermDepositDetails,
      onViewAllDeposits: () =>
          _openAccountsDestination(WebAccountsDestination.termDeposits),
      onOpenDeposit: () =>
          Navigator.of(context).pushNamed(RoutesConst.tdOpenScreen),
      isWide: isWide,
      displayName: _displayNameFromTrace(),
      onTransferTap: () => setState(() => _selectedBottomNavIndex = 2),
      onBillsTap: _openSection,
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

    // Keep Home's data alive while the dashboard is open, on every tab.
    // Both providers are autoDispose: on phones nothing else watches them
    // once another tab is showing, so leaving Home threw away the loaded
    // dashboard layout and recent transactions, and coming back fetched
    // them all again. Watching one small field each keeps them alive
    // without rebuilding the dashboard on every change; they are still
    // dropped when the dashboard closes (logout).
    ref.watch(personalizationProvider.select((s) => s.isUnavailable));
    ref.watch(recentTransactionsWidgetProvider.select((s) => s.category));

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
      // Phones use the bottom sheet (see [PersonalizeLauncher]); no side
      // panel, so an edge swipe cannot pull one in.
      endDrawer: PersonalizeLauncher.usesSheet(context)
          ? null
          : _buildPersonalizeDrawer(),
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

  void _openTermDepositsList() {
    Navigator.of(context).pushNamed(RoutesConst.termDepositsListScreen);
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

      case WebAccountsDestination.termDeposits:
        // Same as Loans: embedded at index 18 beside the sidebar on wide
        // screens, its own pushed screen on phones.
        if (Responsive.of(context).useWideHome) {
          setState(() {
            _selectedAccountsDestination =
                WebAccountsDestination.termDeposits;
            _selectedPayeeDestination = null;
            _selectedCasaAccountId = null;
            _selectedLoanAccount = null;
            _selectedTermDeposit = null;
            _selectedBottomNavIndex = 18;
          });
        } else {
          _selectedAccountsDestination = WebAccountsDestination.termDeposits;
          _selectedPayeeDestination = null;
          _openTermDepositsList();
        }
    }
  }

  /// A term deposit tapped on Home — embeds at index 18 on wide screens,
  /// otherwise pushes its details screen.
  void _openTermDepositDetails(TermDeposit deposit) {
    if (Responsive.of(context).useWideHome) {
      setState(() {
        _selectedAccountsDestination = WebAccountsDestination.termDeposits;
        _selectedTermDeposit = deposit;
        _selectedPayeeDestination = null;
        _selectedCasaAccountId = null;
        _selectedLoanAccount = null;
        _selectedBottomNavIndex = 18;
      });
    } else {
      Navigator.of(context).pushNamed(
        RoutesConst.termDepositDetailsScreen,
        arguments: TermDepositDetailsArgs(deposit: deposit),
      );
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
      case WebAccountsDestination.termDeposits:
        return RetailNav.accountsTermDeposits;
      case null:
        break;
    }
    final index = _selectedBottomNavIndex;
    // A module page and everything opened from it keep its entry lit.
    if (_billPaymentsScreens.contains(index)) return RetailNav.billPayments;
    if (_creditCardsScreens.contains(index)) return RetailNav.creditCards;
    if (index == _mailboxIndex) return RetailNav.mailbox;
    if (index == _serviceRequestsIndex) {
      return _srTab == SrTab.raise ? RetailNav.serviceRequestsRaise : RetailNav.serviceRequestsTrack;
    }
    // Every screen started from the Transfer hub keeps Transfer lit, so the
    // menu always shows where you are.
    if (_transferScreens.contains(index)) return RetailNav.transfer;
    // Other tabs past the first five are screens opened from within one
    // (payees), which the menu has no entry for.
    return index < RetailNav.tabIds.length ? RetailNav.tabIds[index] : null;
  }

  /// The hub (2) and what opens from it: Between My Accounts (11), the
  /// Transfers list (12), Payees (14), the old chooser and its steps (13,
  /// 15–17), a payee transfer (19), Other Transfers (20), Multiple
  /// Transfers (21) and Repeat transfers (22).
  static const _transferScreens = {2, 11, 12, 13, 14, 15, 16, 17, 19, 20, 21, 22};

  void _onNavSelected(String id) {
    switch (id) {
      case RetailNav.accountsCasa:
        _openAccountsDestination(WebAccountsDestination.casa);
        return;
      case RetailNav.accountsLoans:
        _openAccountsDestination(WebAccountsDestination.loans);
        return;
      case RetailNav.accountsTermDeposits:
        _openAccountsDestination(WebAccountsDestination.termDeposits);
        return;
      case RetailNav.billPayments:
        SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
        _openSection(index: _billPaymentsHubIndex);
        return;
      case RetailNav.creditCards:
        SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
        _openSection(index: _creditCardsHubIndex);
        return;
      case RetailNav.mailbox:
        SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
        _openSection(index: _mailboxIndex);
        return;
      case RetailNav.serviceRequestsTrack:
      case RetailNav.serviceRequestsRaise:
        _openServiceRequests(id == RetailNav.serviceRequestsRaise ? SrTab.raise : SrTab.track);
        return;
    }
    final index = RetailNav.tabIds.indexOf(id);
    if (index < 0) return;
    // A menu choice replaces whatever was opened on top.
    SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
    setState(() {
      _transferPayee = null;
      _selectedBottomNavIndex = index;
      _selectedPayeeDestination = null;
      _selectedAccountsDestination = null;
      _selectedCasaAccountId = null;
      _selectedLoanAccount = null;
      _selectedTermDeposit = null;
    });
  }

  /// The shared top bar — the same one Corporate shows.
  Widget _buildTopBar() {
    return WebDashboardHeaderBar(
      displayName: _displayNameFromTrace(),
      userId: _signedInUserName(),
      onLogout: _logout,
      onMenuTap: Responsive.of(context).isDesktop ? null : _openMenu,
      onNotificationsTap: _openMailbox,
      onProfileTap: _openPreferences,
      unreadNotificationCount: ref.watch(mailboxCountsProvider).valueOrNull?.total ?? 0,
    );
  }

  /// Bill Payments → Billers (OBDX `manage-bill-payments`), reached from
  /// the side menu and the Home "Bill" quick action.
  static const _billersIndex = 23;

  /// Bill Payments → Bill Payment History (OBDX `payment-history`).
  static const _billHistoryIndex = 24;

  /// Credit Cards (OBDX `credit-card-listing`) and their Transactions.
  static const _creditCardsIndex = 25;
  static const _cardTransactionsIndex = 26;

  // 27 was My Limits; it is now Preferences → Limits & Controls.

  /// The module pages the side menu opens (like the Payments hub), and Add
  /// Billers started from the Bill Payments page.
  static const _creditCardsHubIndex = 28;
  static const _billPaymentsHubIndex = 29;
  static const _addBillerIndex = 30;

  /// Mailbox (OBDX Mails / Alerts / Notifications): side menu, the bell and
  /// the Menu tab.
  static const _mailboxIndex = 31;

  /// Account Settings → Preferences (OBDX `side-menu`), opened from the
  /// initials in the dashboard header, as OBDX's header profile does.
  static const _preferencesIndex = 32;

  /// Service Requests (OBDX Track Requests / Raise a New Request): the side
  /// menu and More → Services.
  static const _serviceRequestsIndex = 33;

  /// Which half the side menu opened Service Requests on.
  SrTab _srTab = SrTab.track;

  void _openServiceRequests(SrTab tab, {int back = 0}) {
    SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
    _srTab = tab;
    _openSection(index: _serviceRequestsIndex, back: back);
  }

  /// The header initials: opens Preferences; Back returns to the screen it
  /// was tapped on.
  void _openPreferences() {
    if (_selectedBottomNavIndex == _preferencesIndex) return;
    SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
    _openSection(index: _preferencesIndex, back: _selectedBottomNavIndex);
  }

  /// The bell: opens Mailbox; Back returns to the screen it was tapped on.
  void _openMailbox() {
    if (_selectedBottomNavIndex == _mailboxIndex) return;
    SidebarContentNavigator.closeOpenedScreens(_contentNavigatorKey);
    _openSection(index: _mailboxIndex, back: _selectedBottomNavIndex);
  }

  static const _creditCardsScreens = {_creditCardsHubIndex, _creditCardsIndex, _cardTransactionsIndex};
  static const _billPaymentsScreens = {_billPaymentsHubIndex, _billersIndex, _billHistoryIndex, _addBillerIndex};

  /// Where Back on an opened section goes: the module page it came from,
  /// the Menu tab for My Limits, else Home.
  int _sectionBackIndex = 0;

  void _closeSection() => setState(() => _selectedBottomNavIndex = _sectionBackIndex);

  void _openSection({int index = _billersIndex, int back = 0}) => setState(() {
        _sectionBackIndex = back;
        _transferPayee = null;
        _selectedPayeeDestination = null;
        _selectedAccountsDestination = null;
        _selectedCasaAccountId = null;
        _selectedLoanAccount = null;
        _selectedTermDeposit = null;
        _selectedBottomNavIndex = index;
      });

  Widget _buildCurrentBody(CasaAccountsState accountsState) {
    switch (_selectedBottomNavIndex) {
      case _creditCardsHubIndex:
        return CreditCardsHubScreen(
          onCreditCardsTap: () => _openSection(index: _creditCardsIndex, back: _creditCardsHubIndex),
          onTransactionsTap: () => _openSection(index: _cardTransactionsIndex, back: _creditCardsHubIndex),
        );
      case _billPaymentsHubIndex:
        return BillPaymentsHubScreen(
          onBillersTap: () => _openSection(index: _billersIndex, back: _billPaymentsHubIndex),
          onAddBillerTap: () => _openSection(index: _addBillerIndex, back: _billPaymentsHubIndex),
          onHistoryTap: () => _openSection(index: _billHistoryIndex, back: _billPaymentsHubIndex),
        );
      case _addBillerIndex:
        return AddBillerScreen(
          onExit: _closeSection,
          // "Back to Billers" on the Done step: the list, with the new one.
          onAdded: (_) {
            ref.invalidate(registeredBillersProvider);
            _openSection(index: _billersIndex, back: _billPaymentsHubIndex);
          },
        );
      case _billersIndex:
        return BillersScreen(embedded: true, onBack: _closeSection);
      case _billHistoryIndex:
        return BillPaymentHistoryScreen(embedded: true, onBack: _closeSection);
      case _creditCardsIndex:
        return CreditCardsScreen(embedded: true, onBack: _closeSection);
      case _cardTransactionsIndex:
        return CreditCardTransactionsScreen(embedded: true, onBack: _closeSection);
      case _mailboxIndex:
        return MailboxScreen(userName: _signedInUserName(), embedded: true, onBack: _closeSection);
      case _serviceRequestsIndex:
        return ServiceRequestsScreen(initialTab: _srTab, embedded: true, onBack: _closeSection);
      case _preferencesIndex:
        return PreferencesScreen(
          userName: _signedInUserName(),
          displayName: _displayNameFromTrace(),
          lastLogin: _lastLoginFromTrace(),
          onLogout: _logout,
          // Only when the customer has a personalisable OBDX dashboard.
          onPersonalize: ref.watch(personalizationProvider).isUnavailable ? null : _personalizeFromPreferences,
          embedded: true,
          onBack: _closeSection,
        );
      case 1:
        return const InsightsTabScreen();
      case 2:
        return TransferTabScreen(
          // Every way to pay opens embedded: a payee transfer (19, by mode,
          // with the payee picked on the hub's strip), Between My Accounts
          // (11), Payees (14) and Multiple Transfers (21).
          onTransferTap: (mode, payee) => setState(() {
            _transferMode = mode;
            _transferPayee = payee;
            _selectedBottomNavIndex = 19;
          }),
          // OBDX's Other Transfers (My Accounts, Demand Draft, Peer To
          // Peer); My Accounts there opens Own Account Transfer (11).
          onOtherTransfersTap: () =>
              setState(() => _selectedBottomNavIndex = 20),
          onPayeeHubTap: () => setState(() => _selectedBottomNavIndex = 14),
          onMultipleTransfersTap: () =>
              setState(() => _selectedBottomNavIndex = 21),
          onRepeatTransfersTap: () =>
              setState(() => _selectedBottomNavIndex = 22),
        );
      case 3:
        return const RewardsTabScreen();
      case 4:
        return MoreTabScreen(
          displayName: _displayNameFromTrace(),
          onRewardsTap: () => setState(() => _selectedBottomNavIndex = 3),
          onMailboxTap: () => _openSection(index: _mailboxIndex, back: 4),
          onServiceRequestsTap: () => _openServiceRequests(SrTab.track, back: 4),
          onProfileTap: _openPreferences,
        );
      case 5:
        return PayeesScreen(
          embedded: true,
          // "Pay" on an account payee starts the transfer to them.
          onPayTap: (payee) => setState(() {
            _transferMode = NetworkTransferMode.existingPayee;
            _transferPayee = payee;
            _selectedBottomNavIndex = 19;
          }),
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
          // Its seven items open embedded too: a payee transfer (19, by
          // mode), Other Transfers (20) and Multiple Transfers (21).
          onTransferTap: (mode) => setState(() {
            _transferMode = mode;
            _transferPayee = null;
            _selectedBottomNavIndex = 19;
          }),
          onOtherTransfersTap: () =>
              setState(() => _selectedBottomNavIndex = 20),
          onMultipleTransfersTap: () =>
              setState(() => _selectedBottomNavIndex = 21),
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
        return NetworkTransferScreen(
          mode: NetworkTransferMode.existingPayee,
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 13),
        );
      case 16:
        // "Adhoc Payee" transfer, reached from Transfer Money (13) — same
        // reasoning as case 15.
        return NetworkTransferScreen(
          mode: NetworkTransferMode.adhocPayee,
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 13),
        );
      case 17:
        // "International Low Value Payment", reached from the Transfers
        // module (12) directly (not via Transfer Money) — same reasoning
        // as case 15/16.
        return NetworkTransferScreen(
          mode: NetworkTransferMode.internationalLowValue,
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 12),
        );
      case 19:
        // A payee transfer chosen on the Transfer hub, the menu or the
        // Transfers list — keyed by its mode and payee so each choice
        // starts a fresh form. Back returns to the hub.
        return NetworkTransferScreen(
          key: ValueKey((_transferMode, _transferPayee?.id)),
          mode: _transferMode,
          initialPayee: _transferPayee,
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 2),
        );
      case 20:
        return OtherTransfersScreen(
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 2),
          onOwnAccountTap: () => setState(() => _selectedBottomNavIndex = 11),
        );
      case 22:
        // Repeat transfers (standing instructions): "New" starts the
        // Repeat Transfers - Existing Payee flow (19); back returns to the hub.
        return RepeatTransfersScreen(
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 2),
          onNewTap: () => setState(() {
            _transferMode = NetworkTransferMode.repeatExistingPayee;
            _transferPayee = null;
            _selectedBottomNavIndex = 19;
          }),
        );
      case 21:
        return MultipleTransfersScreen(
          embedded: true,
          onBack: () => setState(() => _selectedBottomNavIndex = 2),
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
          // "Pay" on a payee starts the transfer to them, as on the hub.
          onPayTap: (payee) => setState(() {
            _transferMode = NetworkTransferMode.existingPayee;
            _transferPayee = payee;
            _selectedBottomNavIndex = 19;
          }),
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

  /// Phone Home (designer mock, Demobank variant): a white top panel with
  /// the header and the account card, then on a light page either the
  /// customer's OBDX personalised widgets (with Customize, as before) or
  /// the fixed set: Quick Actions, Loan Tracker, My Spendings, Recent
  /// Transactions, Info Corner.
  Widget _buildHomeBody(CasaAccountsState accountsState) {
    // Light page (designer mock): a soft brand tint over the normal
    // background, white cards on it.
    final page = Color.alphaBlend(
      HomeColors.brandLight(context).withValues(alpha: 0.10),
      HomeColors.bg(context),
    );
    return ColoredBox(
      color: page,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildMobileTopPanel(accountsState)),
          SliverToBoxAdapter(child: _buildPhoneWidgets(accountsState)),
        ],
      ),
    );
  }

  /// Below the top panel. Security notices always come first.
  Widget _buildPhoneWidgets(CasaAccountsState accountsState) {
    final state = ref.watch(personalizationProvider);
    final notice = _buildSecurityNotice();
    if (state.bodyStatus == PersonalizedBodyStatus.unavailable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: notice,
          ),
          _buildOriginalLayout(accountsState, false, showAccountCard: false),
        ],
      );
    }
    // Personalised dashboard: Quick Actions, then the customer's widgets
    // (the account card is in the top panel already).
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          notice,
          QuickActionsStrip(
            onTransfer: () => setState(() => _selectedBottomNavIndex = 2),
            onBill: _openSection,
          ),
          const SizedBox(height: 20),
          // Customisation lives in the Menu (profile icon, top right).
          _buildPersonalizedArea(state, includeAccounts: false),
        ],
      ),
    );
  }

  Widget _buildMobileTopPanel(CasaAccountsState accountsState) {
    final l10n = AppLocalizations.of(context);
    final accounts = accountsState.summary?.accounts ?? const <CasaAccount>[];
    final Widget card;
    if (accountsState.isLoading && accounts.isEmpty) {
      card = const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (accountsState.errorMessage != null && accounts.isEmpty) {
      card = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              accountsState.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: HomeColors.textSecondary(context)),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(casaAccountsProvider.notifier).refresh(),
              child: Text(l10n.accountsRetry),
            ),
          ],
        ),
      );
    } else {
      card = AccountsTabCard(
        framed: false,
        accounts: accounts,
        revealedAccountIds: _revealedAccountIds,
        onToggleAccountVisibility: _toggleAccountVisibility,
        displayName: _displayNameFromTrace(),
        onViewAllAccountsTap: () =>
            _openAccountsDestination(WebAccountsDestination.casa),
        onViewAllLoans: () =>
            _openAccountsDestination(WebAccountsDestination.loans),
        onLoanTap: _openLoanAccountDetails,
        onCreditCardsTap: () => _openSection(index: _creditCardsIndex),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DemobankHomeHeader(
                onMenuTap: _openMenu,
                displayName: _displayNameFromTrace(),
                // Initials → Preferences (OBDX's header profile).
                onProfileTap: _openPreferences,
              ),
              const SizedBox(height: 12),
              card,
            ],
          ),
        ),
      ),
    );
  }

  /// Device-security warning (rooted / modified device, emulator), shown
  /// for the whole session — it cannot be dismissed or customised away.
  Widget _buildSecurityNotice() {
    final threat = ref.watch(deviceSecurityNoticeProvider);
    if (threat == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final message = threat == DeviceThreatType.emulator
        ? l10n.deviceSecurityWarnEmulator
        : l10n.deviceSecurityWarnCompromised;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: HomeColors.warning(context), width: 4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gpp_maybe_rounded, color: HomeColors.warning(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeSecurityNotice,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: HomeColors.textSecondary(context),
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

      case 18:
        if (_selectedTermDeposit != null) {
          return SafeArea(
            child: TermDepositDetailsScreen(
              args: TermDepositDetailsArgs(deposit: _selectedTermDeposit!),
              embedded: true,
              onBack: () => setState(() => _selectedTermDeposit = null),
            ),
          );
        }
        return SafeArea(
          child: TermDepositsListScreen(
            embedded: true,
            onDepositSelected: (deposit) =>
                setState(() => _selectedTermDeposit = deposit),
            onBack: () => setState(() {
              _selectedAccountsDestination = null;
              _selectedTermDeposit = null;
              _selectedPayeeDestination = null;
              _selectedBottomNavIndex = 0;
            }),
          ),
        );

      default:
        return SafeArea(
          child: _buildCurrentBody(accountsState),
        );
    }
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
