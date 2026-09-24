import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/accounts_tab_card.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/casa_accounts_panel.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/credit_cards_visual.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/info_corner_card.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/loan_accounts_inline_panel.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/loan_tracker_card.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/quick_actions_grid.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/recent_transactions_card.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/spendings_donut_card.dart';

/// Zero-argument wrappers around the Retail dashboard's existing widgets,
/// so [RetailWidgetRegistry] can build each from a `componentName` alone.
///
/// Most of the underlying widgets already take no required arguments and
/// read their own providers; only the accounts carousel needed adapting,
/// because the fixed Retail layout passes it state the dashboard owns.

/// OBDX `financial-summary` (module `accounts`) — the CASA accounts
/// carousel.
///
/// Owns the reveal state the fixed Retail layout used to hold, so the
/// widget is self-contained when the registry builds it. Each personalized
/// instance keeps its own reveal state, which is correct: hiding a balance
/// is a per-view gesture, not saved configuration.
class RetailAccountsWidget extends ConsumerStatefulWidget {
  const RetailAccountsWidget({super.key});

  @override
  ConsumerState<RetailAccountsWidget> createState() =>
      _RetailAccountsWidgetState();
}

class _RetailAccountsWidgetState extends ConsumerState<RetailAccountsWidget> {
  final Set<String> _revealed = <String>{};

  void _toggle(String accountKey) {
    setState(() {
      if (!_revealed.remove(accountKey)) _revealed.add(accountKey);
    });
  }

  @override
  void initState() {
    super.initState();
    // Post-frame: ensureLoaded mutates a provider, which Riverpod forbids
    // during the widget life-cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(casaAccountsProvider);
    final accounts = state.summary?.accounts ?? const <CasaAccount>[];

    return AccountsTabCard(
      accounts: accounts,
      revealedAccountIds: _revealed,
      onToggleAccountVisibility: _toggle,
      onViewAllAccountsTap: () => Navigator.of(context)
          .pushNamed(RoutesConst.casaAccountsListScreen),
      onViewAllLoans: () => Navigator.of(context)
          .pushNamed(RoutesConst.loanAccountsListScreen),
    );
  }
}

/// OBDX `recent-account-transactions` (module `accounts`).
class RetailRecentTransactionsWidget extends StatelessWidget {
  const RetailRecentTransactionsWidget({super.key});

  @override
  Widget build(BuildContext context) => const RecentTransactionsCard();
}

/// OBDX `spend-summary` (module `personal-finance-management`).
class RetailSpendSummaryWidget extends StatelessWidget {
  const RetailSpendSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) => const SpendingsDonutCard();
}

/// OBDX `loan-summary` (module `loans`, segment `common`).
class RetailLoanSummaryWidget extends StatelessWidget {
  const RetailLoanSummaryWidget({super.key});

  @override
  Widget build(BuildContext context) => LoanTrackerCard(
        onViewAll: () => Navigator.of(context)
            .pushNamed(RoutesConst.loanAccountsListScreen),
      );
}

/// OBDX `quick-links` (module `dashboard`).
class RetailQuickLinksWidget extends StatelessWidget {
  const RetailQuickLinksWidget({super.key});

  @override
  Widget build(BuildContext context) => const QuickActionsGrid();
}

/// OBDX `offers` (module `dashboard`) — the dashboard's info corner.
class RetailOffersWidget extends StatelessWidget {
  const RetailOffersWidget({super.key});

  @override
  Widget build(BuildContext context) => const InfoCornerCard();
}

/// OBDX `casa-account-card` — the CASA accounts list panel.
class RetailCasaAccountsWidget extends ConsumerStatefulWidget {
  const RetailCasaAccountsWidget({super.key});

  @override
  ConsumerState<RetailCasaAccountsWidget> createState() =>
      _RetailCasaAccountsWidgetState();
}

class _RetailCasaAccountsWidgetState
    extends ConsumerState<RetailCasaAccountsWidget> {
  final Set<String> _revealed = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(casaAccountsProvider);
    return CasaAccountsPanel(
      accounts: state.summary?.accounts ?? const <CasaAccount>[],
      revealedAccountIds: _revealed,
      onToggleAccountVisibility: (key) => setState(() {
        if (!_revealed.remove(key)) _revealed.add(key);
      }),
      isLoading: state.isLoading,
      errorMessage: state.errorMessage,
      onRetry: () => ref.read(casaAccountsProvider.notifier).refresh(),
    );
  }
}

/// OBDX `loans-account-card` — the loan accounts list panel.
class RetailLoanAccountsWidget extends StatelessWidget {
  const RetailLoanAccountsWidget({super.key});

  @override
  Widget build(BuildContext context) => LoanAccountsInlinePanel(
        onLoanTap: (loan) => Navigator.of(context).pushNamed(
          RoutesConst.loanAccountDetailsScreen,
          arguments: LoanAccountDetailsArgs(loan: loan),
        ),
      );
}

/// OBDX `credit-card` visual, kept available for mapping.
class RetailCreditCardsWidget extends StatelessWidget {
  const RetailCreditCardsWidget({super.key});

  @override
  Widget build(BuildContext context) => const CreditCardsVisual();
}
