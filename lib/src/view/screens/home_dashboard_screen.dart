import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/casa_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/casa_accounts_panel.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';

import 'home/home_colors.dart';
import 'home/tabs/insights_tab_screen.dart';
import 'home/tabs/more_tab_screen.dart';
import 'home/tabs/rewards_tab_screen.dart';
import 'home/tabs/transfer_tab_screen.dart';
import 'home/widgets/app_nav_content.dart';
import 'home/widgets/bottom_nav.dart';
import 'home/widgets/dashboard_header_bar.dart';
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
  WebAccountsDestination? _selectedAccountsDestination;

  String? _selectedCasaAccountId;
  LoanAccount? _selectedLoanAccount;

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
    await ref.read(recentTransactionsWidgetProvider.notifier).refresh();
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
                    selectedAccountsDestination: _selectedAccountsDestination,
                    onSelected: (index) => setState(() {
                      _selectedBottomNavIndex = index;
                      _selectedPayeeDestination = null;
                      _selectedAccountsDestination = null;
                      _selectedCasaAccountId = null;
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
                    onAccountsSelected: _openAccountsDestination,
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

  /// "Accounts" ▸ CASA / Loans from the side panel / nav drawer. On the
  /// wide/desktop shell both destinations embed next to the persistent
  /// sidebar (CASA at index 9, Loans at index 10 — see
  /// [_buildWideDestination]); on phones, Loans still pushes its own full
  /// screen since there's no sidebar to keep around.
  void _openAccountsDestination(WebAccountsDestination destination) {
  switch (destination) {
    case WebAccountsDestination.casa:
      setState(() {
        _selectedAccountsDestination = WebAccountsDestination.casa;
        _selectedPayeeDestination = null;
        _selectedCasaAccountId = null;
        _selectedLoanAccount = null;
        _selectedBottomNavIndex = 9;
      });

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
          selectedAccountsDestination: _selectedAccountsDestination,
          onSelected: (index) {
            Navigator.of(context).pop();
            setState(() {
              _selectedBottomNavIndex = index;
              _selectedPayeeDestination = null;
              _selectedAccountsDestination = null;
              _selectedCasaAccountId = null;
              _selectedLoanAccount = null;
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
          onAccountsSelected: (destination) {
            Navigator.of(context).pop();
            _openAccountsDestination(destination);
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
            onViewAllLoans: () =>
                _openAccountsDestination(WebAccountsDestination.loans),
            displayName: displayName,
            onTransferTap: () => setState(() => _selectedBottomNavIndex = 2),
          ),
        ),
      ],
    );
  }

  Widget _buildWebDashboard(CasaAccountsState accountsState) {
    final l10n = AppLocalizations.of(context);
    final summary = accountsState.summary;
    final balanceText = _heroBalanceText(summary) ?? '—';
    final accounts = summary?.accounts ?? const <CasaAccount>[];
    final displayName = _displayNameFromTrace();

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
                  WebDashboardHeaderBar(
                    onMenuTap:
                        Responsive.of(context).isDesktop ? null : _openMenu,
                  ),
                  const SizedBox(height: 20),
                  // if (stackHero) ...[
                  //   _buildWebBalanceCard(
                  //     l10n: l10n,
                  //     summary: summary,
                  //     balanceText: balanceText,
                  //   ),
                  //   const SizedBox(height: 16),
                  //   _buildWebAccountsPreview(
                  //     accountsState: accountsState,
                  //     accounts: accounts,
                  //   ),
                  // ] else
                  //   Row(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Expanded(
                  //         flex: 6,
                  //         child: _buildWebBalanceCard(
                  //           l10n: l10n,
                  //           summary: summary,
                  //           balanceText: balanceText,
                  //         ),
                  //       ),
                  //       const SizedBox(width: 18),
                  //       Expanded(
                  //         flex: 5,
                  //         child: _buildWebAccountsPreview(
                  //           accountsState: accountsState,
                  //           accounts: accounts,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // const SizedBox(height: 20),
                  const SizedBox(height: 12),
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
                    onViewAllLoans: () =>
                        _openAccountsDestination(WebAccountsDestination.loans),
                    isWide: true,
                    displayName: displayName,
                    onTransferTap: () =>
                        setState(() => _selectedBottomNavIndex = 2),
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
