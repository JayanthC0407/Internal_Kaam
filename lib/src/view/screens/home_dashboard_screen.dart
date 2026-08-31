import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/casa_accounts_panel.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

import 'home/home_colors.dart';
import 'home/tabs/insights_tab_screen.dart';
import 'home/tabs/more_tab_screen.dart';
import 'home/tabs/rewards_tab_screen.dart';
import 'home/tabs/transfer_tab_screen.dart';
import 'home/widgets/app_nav_content.dart';
import 'home/widgets/bottom_nav.dart';
import 'home/widgets/home_content.dart';
import 'home/widgets/top_hero_section.dart';
import 'home/widgets/web_navigation_sidebar.dart';
import 'payees/add_bank_account_payee_screen.dart';
import 'payees/add_demand_draft_payee_screen.dart';
import 'payees/add_peer_to_peer_payee_screen.dart';
import 'payees/payees_screen.dart';

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

  int _heroSlideIndex = 0;
  int _selectedTopTabIndex = 0;
  late int _selectedBottomNavIndex;
  WebPayeeDestination? _selectedPayeeDestination;
  bool _addPayeeOpenedFromManage = false;
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
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
      ref.read(loanAccountsProvider.notifier).ensureLoaded();
    });
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
    await ref.read(homeRecentTransactionsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final bg = HomeColors.bg(context);
    final accountsState = ref.watch(casaAccountsProvider);

    if (responsive.useWideHome) {
      final content = _selectedBottomNavIndex == 0
          ? RefreshIndicator(
              onRefresh: _refreshHomeData,
              child: _buildWebDashboard(accountsState),
            )
          : _buildWideDestination(accountsState);
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: bg,
        drawer: responsive.isDesktop ? null : _buildNavDrawer(),
        body: responsive.isDesktop
            ? Row(
                children: [
                  WebNavigationSidebar(
                    selectedIndex: _selectedBottomNavIndex,
                    selectedPayeeDestination: _selectedPayeeDestination,
                    onSelected: (index) => setState(() {
                      _selectedBottomNavIndex = index;
                      _selectedPayeeDestination = null;
                    }),
                    onPayeeSelected: (destination) => setState(() {
                      _selectedPayeeDestination = destination;

                      if (destination != WebPayeeDestination.manage) {
                        // Any "Add ..." destination opened directly from the
                        // sidebar (not via Manage Payee).
                        _addPayeeOpenedFromManage = false;
                      }

                      _selectedBottomNavIndex =
                          _navIndexForPayeeDestination(destination);
                    }),
                  ),
                  Expanded(child: content),
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

  void _openLoanAccountsList() {
    Navigator.of(context).pushNamed(RoutesConst.loanAccountsListScreen);
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

  /// Hamburger drawer content — mobile/tablet only. Selecting a destination
  /// closes the drawer first, then updates the same [_selectedBottomNavIndex]
  /// / [_selectedPayeeDestination] state the bottom nav and desktop sidebar
  /// both drive, so all three stay in sync without separate index schemes.
  Widget _buildNavDrawer() {
    return Drawer(
      child: SafeArea(
        child: AppNavContent(
          selectedIndex: _selectedBottomNavIndex,
          onSelected: (index) {
            Navigator.of(context).pop();
            setState(() {
              _selectedBottomNavIndex = index;
              _selectedPayeeDestination = null;
            });
          },
          selectedPayeeDestination: _selectedPayeeDestination,
          onPayeeSelected: (destination) {
            Navigator.of(context).pop();
            setState(() {
              _selectedPayeeDestination = destination;

              if (destination != WebPayeeDestination.manage) {
                // Any "Add ..." destination opened directly from the
                // navigation drawer (not via Manage Payee).
                _addPayeeOpenedFromManage = false;
              }

              _selectedBottomNavIndex =
                  _navIndexForPayeeDestination(destination);
            });
          },
        ),
      ),
    );
  }

  Widget _buildCurrentBody(CasaAccountsState accountsState) {
    switch (_selectedBottomNavIndex) {
      case 1:
        return const InsightsTabScreen();
      case 2:
        return const TransferTabScreen();
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
            _selectedBottomNavIndex = 0;
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
      case 0:
      default:
        return _buildHomeBody(accountsState);
    }
  }

  /// Shared back/complete handler for the three "Add Payee" screens
  /// (Bank Account / Demand Draft / Peer To Peer): returns to Manage Payee
  /// when opened from there, otherwise back to the Dashboard.
  void _returnFromAddPayee() {
    if (_addPayeeOpenedFromManage) {
      _selectedPayeeDestination = WebPayeeDestination.manage;
      _selectedBottomNavIndex = 5;
    } else {
      _selectedPayeeDestination = null;
      _selectedBottomNavIndex = 0;
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
          child: HomeContent(
            selectedTopTabIndex: _selectedTopTabIndex,
            onTopTabSelected: (index) =>
                setState(() => _selectedTopTabIndex = index),
            revealedAccountIds: _revealedAccountIds,
            onToggleAccountVisibility: _toggleAccountVisibility,
            accounts: summary?.accounts ?? const [],
            accountsLoading: accountsState.isLoading,
            accountsError: accountsState.errorMessage,
            onRetryAccounts: () =>
                ref.read(casaAccountsProvider.notifier).refresh(),
            onViewAllLoans: _openLoanAccountsList,
          ),
        ),
      ],
    );
  }

  Widget _buildWebDashboard(CasaAccountsState accountsState) {
    final l10n = AppLocalizations.of(context);
    final displayName = _displayNameFromTrace();
    final summary = accountsState.summary;
    final balanceText = _heroBalanceText(summary) ?? '—';
    final accounts = summary?.accounts ?? const <CasaAccount>[];

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final stackHero = width < 980;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              width < 900 ? 20 : 30,
              22,
              width < 900 ? 20 : 30,
              32,
            ),
            child: ResponsiveBody(
              maxWidth: 1400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (!Responsive.of(context).isDesktop) ...[
                        _TopIconButton(
                          icon: Icons.menu_rounded,
                          onTap: _openMenu,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.goodMorningComma,
                              style: TextStyle(
                                fontSize: 13,
                                color: HomeColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: width < 1000 ? 29 : 34,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: HomeColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          decoration: BoxDecoration(
                            color: HomeColors.card(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: HomeColors.divider(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 19,
                                color: HomeColors.navInactive(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.searchPlaceholder,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: HomeColors.navInactive(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ProfileHeaderButton(
                        onTap: () =>
                            setState(() => _selectedBottomNavIndex = 4),
                      ),
                      const SizedBox(width: 8),
                      const _TopIconButton(icon: Icons.notifications_none),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            setState(() => _selectedBottomNavIndex = 2),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          l10n.newTransfer,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (stackHero) ...[
                    _buildWebBalanceCard(
                      l10n: l10n,
                      summary: summary,
                      balanceText: balanceText,
                    ),
                    const SizedBox(height: 16),
                    _buildWebAccountsPreview(
                      accountsState: accountsState,
                      accounts: accounts,
                    ),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _buildWebBalanceCard(
                            l10n: l10n,
                            summary: summary,
                            balanceText: balanceText,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 5,
                          child: _buildWebAccountsPreview(
                            accountsState: accountsState,
                            accounts: accounts,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  HomeContent(
                    selectedTopTabIndex: _selectedTopTabIndex,
                    onTopTabSelected: (index) =>
                        setState(() => _selectedTopTabIndex = index),
                    revealedAccountIds: _revealedAccountIds,
                    onToggleAccountVisibility: _toggleAccountVisibility,
                    accounts: accounts,
                    accountsLoading: accountsState.isLoading,
                    accountsError: accountsState.errorMessage,
                    onRetryAccounts: () =>
                        ref.read(casaAccountsProvider.notifier).refresh(),
                    onViewAllLoans: _openLoanAccountsList,
                    isWide: true,
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
    return SafeArea(
      child: _buildCurrentBody(accountsState),
    );
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

class _ProfileHeaderButton extends StatelessWidget {
  const _ProfileHeaderButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.moreTitle,
      child: Material(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HomeColors.divider(context)),
            ),
            alignment: Alignment.center,
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.neutral100,
              child: Icon(
                Icons.person,
                size: 18,
                color: AppColors.neutral600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Icon(icon, size: 20, color: HomeColors.navInactive(context)),
        ),
      ),
    );
  }
}
