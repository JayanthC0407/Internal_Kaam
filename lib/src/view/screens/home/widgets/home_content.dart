import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/casa_accounts_panel.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/recent_transactions_card.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/loan_accounts_inline_panel.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/loan_tracker_card.dart';
import '../home_colors.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.selectedTopTabIndex,
    required this.onTopTabSelected,
    required this.revealedAccountIds,
    required this.onToggleAccountVisibility,
    required this.accounts,
    required this.accountsLoading,
    this.accountsError,
    this.onRetryAccounts,
    this.onViewAllLoans,
    this.isWide = false,
  });

  final int selectedTopTabIndex;
  final ValueChanged<int> onTopTabSelected;
  final Set<String> revealedAccountIds;
  final ValueChanged<String> onToggleAccountVisibility;
  final List<CasaAccount> accounts;
  final bool accountsLoading;
  final String? accountsError;
  final VoidCallback? onRetryAccounts;
  final VoidCallback? onViewAllLoans;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HomeColors.bg(context),
        borderRadius: isWide
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isWide ? 0 : 20,
          isWide ? 0 : 20,
          isWide ? 0 : 20,
          28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MainTabs(
              selectedIndex: selectedTopTabIndex,
              onSelected: onTopTabSelected,
              tabLabels: (
                l10n.overview,
                l10n.accounts,
                l10n.cards,
                l10n.deposit,
              ),
              isWide: isWide,
            ),
            SizedBox(height: isWide ? 22 : 16),
            _buildSelectedContent(context, l10n),
          ],
        ),
      ),
    );

    if (isWide) return content;
    return Transform.translate(
      offset: const Offset(0, -16),
      child: content,
    );
  }

  Widget _buildSelectedContent(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    switch (selectedTopTabIndex) {
      case 1:
        return _AccountsSectionContent(
          accounts: accounts,
          revealedAccountIds: revealedAccountIds,
          onToggleAccountVisibility: onToggleAccountVisibility,
          accountsLoading: accountsLoading,
          accountsError: accountsError,
          onRetryAccounts: onRetryAccounts,
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(title: l10n.myCards),
            const SizedBox(height: 12),
            const _CardsStrip(),
          ],
        );
      case 3:
        return _FeaturePlaceholder(
          icon: Icons.savings_outlined,
          title: l10n.deposit,
          message: l10n.featureComingSoon,
        );
      case 0:
      default:
        return _OverviewContent(isWide: isWide, onViewAllLoans: onViewAllLoans);
    }
  }
}

enum _AccountCategory { casa, termDeposit, recurringDeposit, loan }

/// Accounts tab content: a category filter (Current & Savings / Term
/// Deposits / Recurring Deposit / Loan & Finance) above the matching
/// account list. Defaults to Current & Savings — same list this tab always
/// showed — so existing behaviour is unchanged unless the user switches
/// the filter.
class _AccountsSectionContent extends StatefulWidget {
  const _AccountsSectionContent({
    required this.accounts,
    required this.revealedAccountIds,
    required this.onToggleAccountVisibility,
    required this.accountsLoading,
    this.accountsError,
    this.onRetryAccounts,
  });

  final List<CasaAccount> accounts;
  final Set<String> revealedAccountIds;
  final ValueChanged<String> onToggleAccountVisibility;
  final bool accountsLoading;
  final String? accountsError;
  final VoidCallback? onRetryAccounts;

  @override
  State<_AccountsSectionContent> createState() =>
      _AccountsSectionContentState();
}

class _AccountsSectionContentState extends State<_AccountsSectionContent> {
  _AccountCategory _selected = _AccountCategory.casa;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = <(_AccountCategory, String, IconData)>[
      (_AccountCategory.casa, l10n.menuCurrentSavings,
          Icons.account_balance_outlined),
      (_AccountCategory.termDeposit, l10n.menuTermDeposits,
          Icons.savings_outlined),
      (_AccountCategory.recurringDeposit, l10n.menuRecurringDeposits,
          Icons.autorenew_rounded),
      (_AccountCategory.loan, l10n.menuLoansFinances,
          Icons.request_quote_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryDropdown(
          categories: categories,
          selected: _selected,
          onChanged: (category) => setState(() => _selected = category),
        ),
        const SizedBox(height: 16),
        _buildCategoryContent(context, l10n),
      ],
    );
  }

  Widget _buildCategoryContent(BuildContext context, AppLocalizations l10n) {
    switch (_selected) {
      case _AccountCategory.casa:
        return CasaAccountsPanel(
          accounts: widget.accounts,
          revealedAccountIds: widget.revealedAccountIds,
          onToggleAccountVisibility: widget.onToggleAccountVisibility,
          isLoading: widget.accountsLoading,
          errorMessage: widget.accountsError,
          onRetry: widget.onRetryAccounts,
        );
      case _AccountCategory.loan:
        return const LoanAccountsInlinePanel();
      case _AccountCategory.termDeposit:
        return _FeaturePlaceholder(
          icon: Icons.savings_outlined,
          title: l10n.menuTermDeposits,
          message: l10n.featureComingSoon,
        );
      case _AccountCategory.recurringDeposit:
        return _FeaturePlaceholder(
          icon: Icons.autorenew_rounded,
          title: l10n.menuRecurringDeposits,
          message: l10n.featureComingSoon,
        );
    }
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<(_AccountCategory, String, IconData)> categories;
  final _AccountCategory selected;
  final ValueChanged<_AccountCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final textPrimary = HomeColors.textPrimary(context);
    final textSecondary = HomeColors.textSecondary(context);
    final divider = HomeColors.divider(context);
    final card = HomeColors.card(context);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<_AccountCategory>(
            value: selected,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            dropdownColor: card,
            icon: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: textSecondary),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            selectedItemBuilder: (context) => categories
                .map(
                  (entry) => Row(
                    children: [
                      Icon(entry.$3, size: 18, color: brand),
                      const SizedBox(width: 10),
                      Text(
                        entry.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
            items: categories
                .map(
                  (entry) => DropdownMenuItem<_AccountCategory>(
                    value: entry.$1,
                    child: Row(
                      children: [
                        Icon(entry.$3, size: 18, color: brand),
                        const SizedBox(width: 10),
                        Text(
                          entry.$2,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.isWide,
    this.onViewAllLoans,
  });

  final bool isWide;
  final VoidCallback? onViewAllLoans;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final loanTracker = LoanTrackerCard(onViewAll: onViewAllLoans);

    final cards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: l10n.myCards,
          actionLabel: l10n.viewAll,
          onAction: () {},
        ),
        const SizedBox(height: 12),
        const _CardsStrip(),
      ],
    );
    final spending = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: l10n.mySpendingsLower),
        const SizedBox(height: 12),
        const _SpendingChartCard(),
      ],
    );
    final topSpending = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: l10n.topSpending,
          actionLabel: l10n.viewAll,
          onAction: () {},
        ),
        const SizedBox(height: 12),
        const _TopSpendingsCard(),
      ],
    );
    // Show live amounts (independent of total-balance / account eye toggles).
    const transactions = RecentTransactionsCard();

    // Mobile: stack vertically (loan under cards, matching Figma flow).
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CashbackCard(),
          const SizedBox(height: 12),
          const _Dots(active: 0),
          const SizedBox(height: 20),
          cards,
          const SizedBox(height: 16),
          loanTracker,
          const SizedBox(height: 20),
          spending,
          const SizedBox(height: 20),
          topSpending,
          const SizedBox(height: 20),
          transactions,
        ],
      );
    }

    // Web (Figma 11:6815): left = Cards + Loan Tracker; right = My Spendings;
    // then bottom row Top Spending | Recent Transactions.
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 920;
        if (!useTwoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CashbackCard(),
              const SizedBox(height: 16),
              cards,
              const SizedBox(height: 16),
              loanTracker,
              const SizedBox(height: 20),
              spending,
              const SizedBox(height: 20),
              topSpending,
              const SizedBox(height: 20),
              transactions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CashbackCard(),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cards,
                      const SizedBox(height: 16),
                      loanTracker,
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: spending),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: topSpending),
                const SizedBox(width: 20),
                Expanded(child: transactions),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  const _FeaturePlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: HomeColors.brand(context).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: HomeColors.brand(context), size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: HomeColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainTabs extends StatelessWidget {
  const _MainTabs({
    required this.selectedIndex,
    required this.onSelected,
    required this.tabLabels,
    required this.isWide,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final (String, String, String, String) tabLabels;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (tabLabels.$1, Icons.grid_view_rounded),
      (tabLabels.$2, Icons.account_balance_outlined),
      (tabLabels.$3, Icons.credit_card_outlined),
      (tabLabels.$4, Icons.savings_outlined),
    ];

    if (isWide) {
      return Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HomeColors.divider(context)),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = i == selectedIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color:
                        active ? HomeColors.brand(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tabs[i].$2,
                        size: 19,
                        color: active
                            ? Colors.white
                            : HomeColors.navInactive(context),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tabs[i].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : HomeColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }

    return Row(
      children: List.generate(tabs.length, (i) {
        final active = i == selectedIndex;
        final tab = tabs[i];
        final color = active
    ? HomeColors.brand(context)
    : HomeColors.navInactive(context);
        return Expanded(
          child: InkWell(
            onTap: () => onSelected(i),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.$2, color: color, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    tab.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 3,
                    width: active ? 28 : 0,
                    decoration: BoxDecoration(
                      color: active
                          ? HomeColors.brand(context)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CashbackCard extends StatelessWidget {
  const _CashbackCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
gradient: AppGradients.primary(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cashbackPromoTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.offerPromo,
            style: const TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.activateOffer,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? HomeColors.brand(context) : AppColors.teal100,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
              height: 1.2,
            ),
          ),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: brand,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: brand,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CardsStrip extends StatelessWidget {
  const _CardsStrip();

  static const _demoCurrency = 'GBP';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget card({
      required double width,
      required Color c1,
      required Color c2,
      required String amount,
      required String tail,
      required bool isLast,
    }) {
      return Container(
        width: width,
        margin: EdgeInsets.only(right: isLast ? 0 : 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [c1, c2]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.visa,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.cardTailMasked(tail),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // Keep the leading card fully visible and peek the next card.
        const peek = 36.0;
        const maxCard = 280.0;
        final cardWidth = available <= 0
            ? 240.0
            : math
                .min(maxCard,
                    math.max(available - peek, math.min(available, 200.0)))
                .clamp(0.0, available);

        final amounts = [
          MoneyFormat.format(4210.90, currencyCode: _demoCurrency),
          MoneyFormat.format(9060.20, currencyCode: _demoCurrency),
        ];

        return SizedBox(
          height: 137,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            children: [
              card(
                width: cardWidth,
                c1: const Color(0xFF292D36),
                c2: const Color(0xFF15181E),
                amount: amounts[0],
                tail: '2935',
                isLast: false,
              ),
              card(
                width: cardWidth,
                c1: const Color(0xFF204B8A),
                c2: const Color(0xFF12325F),
                amount: amounts[1],
                tail: '7341',
                isLast: true,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpendingChartCard extends StatelessWidget {
  const _SpendingChartCard();

  static const _demoCurrency = 'GBP';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const values = [122.0, 174.0, 118.0, 105.0, 166.0, 135.0, 68.0];
    const labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
    const max = 180.0;
    const chartHeight = 180.0;
    const labelHeightBudget = 22.0; // label text + spacing
    const maxBarHeight = chartHeight - labelHeightBudget;
    final totalLabel = l10n.totalAmount(
      MoneyFormat.format(4130, currencyCode: _demoCurrency),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.julySpendingsLower,
                        style: TextStyle(
                            fontSize: 12,
                            color: HomeColors.textSecondary(context))),
                    const SizedBox(height: 2),
                    Text(totalLabel,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: HomeColors.textPrimary(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(values.length, (i) {
                final h = (values[i] / max) * maxBarHeight;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: h,
                        width: 24,
                        decoration: BoxDecoration(
                          color: i == 4
                              ? HomeColors.brand(context)
                              : AppColors.cyan300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: HomeColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSpendingsCard extends StatelessWidget {
  const _TopSpendingsCard();

  static const _demoCurrency = 'GBP';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String spent(double amount) =>
        '${MoneyFormat.format(amount, currencyCode: _demoCurrency)} spent';
    final items = [
      (l10n.categoryTechnology, spent(860), '27.2'),
      (l10n.categoryFoodDining, spent(650), '20.6'),
      (l10n.categoryHealthcare, spent(540), '17.1'),
      (l10n.categoryEntertainment, spent(410), '13.0'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: items
            .map(
              (it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.neutral100,
                      child: Icon(Icons.pie_chart_outline, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.$1,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(it.$2,
                              style: TextStyle(
                                  color: HomeColors.textSecondary(context),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyan50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${it.$3}%',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: HomeColors.textSecondary(context),
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
