import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_account_details_screen.dart';
import 'credit_cards_visual.dart';
import '../home_colors.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_card_surface.dart';

/// Dashboard "Accounts / Credit Card / Loans / Insurance" hero section.
///
/// Sits at the top of the Overview tab: an inner tab strip switches between
/// four product groups. "Accounts" (the default) shows the CASA accounts as
/// a swipeable carousel of gradient cards with a masked/reveal number, an
/// account-type dropdown and a "View all accounts" link on one line, below
/// the carousel. The other tabs are placeholders until those products are
/// wired up.
///
/// Uses the same card chrome (background, radius, border, padding) as
/// [SpendingsDonutCard] so the two can later sit side by side with matching
/// height and width.
class AccountsTabCard extends ConsumerStatefulWidget {
  const AccountsTabCard({
    super.key,
    required this.accounts,
    required this.revealedAccountIds,
    required this.onToggleAccountVisibility,
    this.displayName = '',
    this.onViewAllAccountsTap,
    this.onViewAllLoans,
    this.onLoanTap,
    this.framed = true,
    this.showTotalCard = false,
    this.onDeposit,
    this.onCreditCardsTap,
  });

  /// False on the phone Home, where the card sits in the white top panel
  /// and draws no frame of its own.
  final bool framed;

  /// Phone Home (designer mock): the carousel opens on a Total Balance
  /// card before the account cards.
  final bool showTotalCard;

  /// "+ Deposit" (opens New Term Deposit) in place of "View all accounts".
  final VoidCallback? onDeposit;

  /// Credit Card tab: tapping a card opens Credit Cards.
  final VoidCallback? onCreditCardsTap;

  final List<CasaAccount> accounts;
  final Set<String> revealedAccountIds;
  final ValueChanged<String> onToggleAccountVisibility;

  /// Resolved account-holder name, shown on the account card.
  final String displayName;

  /// Invoked when "View all accounts" is tapped.
  final VoidCallback? onViewAllAccountsTap;

  /// Invoked when "View all loans" is tapped on the Loans inner tab.
  final VoidCallback? onViewAllLoans;

  /// Invoked when a loan card in the Loans inner tab is tapped. Falls back
  /// to pushing [LoanAccountDetailsScreen] directly when not supplied (e.g.
  /// if this card is ever used outside Home's tabs) — see
  /// [HomeDashboardScreen], which supplies this on wide/desktop layouts so
  /// the loan opens next to the persistent sidebar instead of covering it.
  final ValueChanged<LoanAccount>? onLoanTap;

  @override
  ConsumerState<AccountsTabCard> createState() => _AccountsTabCardState();
}

enum _HeroTab { accounts, creditCard, loans, insurance }

class _AccountsTabCardState extends ConsumerState<AccountsTabCard> {
  _HeroTab _tab = _HeroTab.accounts;
  final PageController _pageController = PageController();
  int _page = 0;
  /// Account type shown in the card carousel — every account until the
  /// customer picks Savings or Current in the dropdown under it.
  _AccountType _accountType = _AccountType.all;
  bool _totalRevealed = false;

  final PageController _loanPageController = PageController();
  int _loanPage = 0;
  final Set<String> _revealedLoanIds = {};

  @override
  void dispose() {
    _pageController.dispose();
    _loanPageController.dispose();
    super.dispose();
  }

  String _accountKey(CasaAccount account) =>
      account.id.isNotEmpty ? account.id : account.displayNumber;

  String _loanKey(LoanAccount loan) =>
      loan.id.isNotEmpty ? loan.id : loan.displayNumber;

  void _toggleLoanVisibility(LoanAccount loan) {
    final key = _loanKey(loan);
    setState(() {
      if (!_revealedLoanIds.remove(key)) _revealedLoanIds.add(key);
    });
  }

  void _openLoanDetails(BuildContext context, LoanAccount loan) {
    HapticFeedback.selectionClick();
    if (widget.onLoanTap != null) {
      widget.onLoanTap!(loan);
      return;
    }
    Navigator.of(context).pushNamed(
      RoutesConst.loanAccountDetailsScreen,
      arguments: LoanAccountDetailsArgs(loan: loan),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TODO(l10n): wire through AppLocalizations once translated keys land
    // for the Credit Card / Loans / Insurance tab labels.
    final tabs = [
      AppLocalizations.of(context).accounts,
      'Credit Card',
      'Loans',
      'Insurance',
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InnerTabs(
          tabs: tabs,
          selectedIndex: _tab.index,
          onSelected: (i) => setState(() => _tab = _HeroTab.values[i]),
        ),
        const SizedBox(height: 18),
        _buildTabContent(context),
      ],
    );
    if (!widget.framed) return content;

    return DashboardCardSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: content,
    );
  }

  Widget _buildTabContent(BuildContext context) {
    switch (_tab) {
      case _HeroTab.accounts:
        return _buildAccountsTab(context);
      case _HeroTab.creditCard:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: CreditCardsVisual(onOpen: widget.onCreditCardsTap),
        );
      case _HeroTab.loans:
        return _buildLoansTab(context);
      case _HeroTab.insurance:
        return const _ComingSoonPlaceholder(
          icon: Icons.shield_outlined,
          title: 'Insurance',
        );
    }
  }

  Widget _buildAccountsTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final types = [
      if (widget.accounts.any((a) => a.isSaving)) _AccountType.savings,
      if (widget.accounts.any((a) => a.isCurrent)) _AccountType.current,
    ];
    final type = types.contains(_accountType) ? _accountType : _AccountType.all;
    final accounts = switch (type) {
      _AccountType.all => widget.accounts,
      _AccountType.savings => widget.accounts.where((a) => a.isSaving).toList(),
      _AccountType.current => widget.accounts.where((a) => a.isCurrent).toList(),
    };

    if (accounts.isEmpty) {
      return _ComingSoonPlaceholder(
        icon: Icons.account_balance_outlined,
        title: l10n.accountsEmpty,
        isMessageOnly: true,
      );
    }

    Widget accountCard(CasaAccount account) => _HeroAccountCard(
          accountHolderName: widget.displayName,
          account: account,
          revealed: widget.revealedAccountIds.contains(_accountKey(account)),
          onToggleVisibility: () =>
              widget.onToggleAccountVisibility(_accountKey(account)),
        );
    final pages = <Widget>[
      if (widget.showTotalCard)
        _TotalBalanceCard(
          accounts: accounts,
          revealed: _totalRevealed,
          onToggleVisibility: () =>
              setState(() => _totalRevealed = !_totalRevealed),
          onTap: widget.onViewAllAccountsTap,
        ),
      for (final account in accounts) accountCard(account),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 168,
          child: pages.length == 1
              ? pages.single
              : PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  // Even gap between pages, cards centred on the row below.
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: pages[index],
                  ),
                ),
        ),
        if (pages.length > 1) ...[
          const SizedBox(height: 10),
          _CarouselDots(count: pages.length, active: _page),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            // A choice only when both Savings and Current accounts exist.
            Flexible(
              child: types.length < 2
                  ? Text(
                      _AccountTypeDropdown.label(
                        l10n,
                        types.isEmpty ? _AccountType.all : types.single,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.textPrimary(context),
                      ),
                    )
                  : _AccountTypeDropdown(
                      value: type,
                      options: [_AccountType.all, ...types],
                      onChanged: (value) => setState(() {
                        _accountType = value;
                        _page = 0;
                        if (_pageController.hasClients) {
                          _pageController.jumpToPage(0);
                        }
                      }),
                    ),
            ),
            const SizedBox(width: 10),
            if (widget.onDeposit != null)
              TextButton.icon(
                onPressed: widget.onDeposit,
                style: TextButton.styleFrom(
                  foregroundColor: HomeColors.textPrimary(context),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: Text(
                  l10n.homeDeposit,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
            InkWell(
              onTap: widget.onViewAllAccountsTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  l10n.homeViewAllAccounts,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.brand(context),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoansTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loanAccountsProvider);
    final loans = state.summary?.loans ?? const <LoanAccount>[];

    if (state.isLoading && loans.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null && loans.isEmpty) {
      return _ComingSoonPlaceholder(
        icon: Icons.request_quote_outlined,
        title: state.errorMessage!,
        isMessageOnly: true,
      );
    }

    if (loans.isEmpty) {
      return _ComingSoonPlaceholder(
        icon: Icons.request_quote_outlined,
        title: l10n.loansEmpty,
        isMessageOnly: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 168,
          child: loans.length == 1
              ? _LoanHeroCard(
                  loan: loans.first,
                  revealed: _revealedLoanIds.contains(_loanKey(loans.first)),
                  onToggleVisibility: () =>
                      _toggleLoanVisibility(loans.first),
                  onTap: () => _openLoanDetails(context, loans.first),
                )
              : PageView.builder(
                  controller: _loanPageController,
                  itemCount: loans.length,
                  onPageChanged: (index) => setState(() => _loanPage = index),
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _LoanHeroCard(
                      loan: loans[index],
                      revealed:
                          _revealedLoanIds.contains(_loanKey(loans[index])),
                      onToggleVisibility: () =>
                          _toggleLoanVisibility(loans[index]),
                      onTap: () => _openLoanDetails(context, loans[index]),
                    ),
                  ),
                ),
        ),
        if (loans.length > 1) ...[
          const SizedBox(height: 10),
          _CarouselDots(count: loans.length, active: _loanPage),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            InkWell(
              onTap: widget.onViewAllLoans,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'View all loans',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.brand(context),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Loans-tab counterpart to [_HeroAccountCard] — same gradient chrome,
/// carousel behavior, and per-item semantics: each card shows that one
/// loan's own outstanding/sanctioned amounts (never a portfolio total), the
/// same way each account card shows only its own balance.
class _LoanHeroCard extends StatelessWidget {
  const _LoanHeroCard({
    required this.loan,
    required this.revealed,
    required this.onToggleVisibility,
    required this.onTap,
  });

  final LoanAccount loan;
  final bool revealed;
  final VoidCallback onToggleVisibility;
  final VoidCallback onTap;

  static const _brandLogomarkAsset = 'assets/images/figma/brand_logomark.svg';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outstanding = loan.outstandingAmount;
    final outstandingCurrency =
        (outstanding?.currency ?? loan.currencyCode).trim();
    final outstandingText = outstanding == null
        ? '—'
        : revealed
            ? MoneyFormat.format(
                outstanding.amount,
                currencyCode: outstandingCurrency,
              )
            : '${outstandingCurrency.isEmpty ? '' : '$outstandingCurrency '}••••';

    final sanctioned = loan.sanctionedAmount;
    final borrowingCurrency =
        (sanctioned?.currency ?? loan.currencyCode).trim();
    final borrowingText = sanctioned == null
        ? '—'
        : revealed
            ? MoneyFormat.format(
                sanctioned.amount,
                currencyCode: borrowingCurrency,
              )
            : '${borrowingCurrency.isEmpty ? '' : '$borrowingCurrency '}••••';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: AppGradients.primary(context),
            borderRadius: BorderRadius.circular(20),
            
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -46,
                bottom: -56,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.55,
                    child: SizedBox(
                      width: 170,
                      height: 186,
                      child: SvgPicture.asset(
                        _brandLogomarkAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          loan.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: SvgPicture.asset(
                          _brandLogomarkAsset,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text(
                        l10n.loanTotalOutstanding,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onToggleVisibility,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            revealed
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    outstandingText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${l10n.loanTotalBorrowing}: $borrowingText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InnerTabs extends StatelessWidget {
  const _InnerTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: HomeColors.divider(context)),
        ),
      ),
      child: Row(
  children: [
    for (var i = 0; i < tabs.length; i++)
      Expanded(
        child: Center(
          child: _TabItem(
            label: tabs[i],
            active: i == selectedIndex,
            onTap: () => onSelected(i),
          ),
        ),
      ),
  ],
),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? HomeColors.textPrimary(context)
        : HomeColors.textSecondary(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? HomeColors.brand(context) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        // One line per tab ("Credit Card" used to wrap on phones).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

enum _AccountType { all, savings, current }

/// Savings / Current filter for the card carousel. The text style carries
/// the app font explicitly — DropdownButton does not inherit it.
class _AccountTypeDropdown extends StatelessWidget {
  const _AccountTypeDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final _AccountType value;
  final List<_AccountType> options;
  final ValueChanged<_AccountType> onChanged;

  static String label(AppLocalizations l10n, _AccountType type) =>
      switch (type) {
        _AccountType.all => l10n.homeAllAccounts,
        _AccountType.savings => l10n.homeSavingsAccount,
        _AccountType.current => l10n.homeCurrentAccount,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonHideUnderline(
      child: DropdownButton<_AccountType>(
        value: value,
        isDense: true,
        isExpanded: true,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: HomeColors.textSecondary(context),
        ),
        style: DefaultTextStyle.of(context).style.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
        dropdownColor: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        items: [
          for (final option in options)
            DropdownMenuItem<_AccountType>(
              value: option,
              child: Text(
                label(l10n, option),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

/// Gradient account card matching the Figma reference: holder name +
/// "Primary Account" tag and a small brand mark on the top row, a
/// mask/reveal-able balance amount with an eye toggle, and the account
/// number below it in masked "•••• •••• •••• 1234" groups (always masked,
/// save for the last 4 digits — only the balance responds to the toggle).
class _HeroAccountCard extends StatelessWidget {
  const _HeroAccountCard({
    required this.accountHolderName,
    required this.account,
    required this.revealed,
    required this.onToggleVisibility,
  });

  final String accountHolderName;
  final CasaAccount account;
  final bool revealed;
  final VoidCallback onToggleVisibility;

  static const _brandLogomarkAsset = 'assets/images/figma/brand_logomark.svg';

  /// Groups a raw account number into "•••• •••• •••• 1234" — every digit
  /// masked except the trailing 4, chunked in fours like a card number.
  /// While the balance is hidden ([showLastFour] false) those 4 are masked
  /// too, so the eye hides the whole number.
  String _groupedMaskedNumber(String raw, {required bool showLastFour}) {
    final digits = raw.replaceAll(RegExp(r'\s+'), '');
    if (digits.isEmpty) return '';
    final visibleLength = !showLastFour ? 0 : (digits.length >= 4 ? 4 : digits.length);
    final maskedLength = digits.length - visibleLength;
    final combined =
        ('•' * maskedLength) + digits.substring(digits.length - visibleLength);

    final groups = <String>[];
    for (var i = 0; i < combined.length; i += 4) {
      final end = (i + 4).clamp(0, combined.length);
      groups.add(combined.substring(i, end));
    }
    return groups.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final balance = account.displayBalance;
    final currency = (balance?.currency ?? account.currencyCode).trim();
    final balanceText = balance == null
        ? '—'
        : revealed
            ? MoneyFormat.format(balance.amount, currencyCode: currency)
            : '${currency.isEmpty ? '' : '$currency '}\u2022\u2022\u2022\u2022';
    final numberText = _groupedMaskedNumber(account.displayNumber, showLastFour: revealed);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.primary(context),
        borderRadius: BorderRadius.circular(20),
        
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative brand-mark watermark, mostly clipped bottom-right.
          Positioned(
            right: -46,
            bottom: -56,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55,
                child: SizedBox(
                  width: 170,
                  height: 186,
                  child: SvgPicture.asset(
                    _brandLogomarkAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            accountHolderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (account.isDefault) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            AppLocalizations.of(context).homePrimaryAccount,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: SvgPicture.asset(
                      _brandLogomarkAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      balanceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onToggleVisibility,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        revealed
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                numberText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// First page of the phone Home carousel (designer mock): the total
/// available balance of the accounts shown (per the Savings / Current
/// filter), hidden until the eye is tapped. Accounts in other currencies
/// are not added in — the card names how many it counts.
class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({
    required this.accounts,
    required this.revealed,
    required this.onToggleVisibility,
    this.onTap,
  });

  final List<CasaAccount> accounts;
  final bool revealed;
  final VoidCallback onToggleVisibility;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The primary account's currency leads; others are left out of the sum.
    final primary = accounts.firstWhere(
      (a) => a.isDefault,
      orElse: () => accounts.first,
    );
    final currency =
        (primary.displayBalance?.currency ?? primary.currencyCode).trim();
    final counted = [
      for (final a in accounts)
        if ((a.displayBalance?.currency ?? a.currencyCode).trim() == currency)
          a,
    ];
    final total = counted.fold<double>(
      0,
      (sum, a) => sum + (a.displayBalance?.amount ?? 0),
    );
    final amount = revealed
        ? MoneyFormat.format(total, currencyCode: currency)
        : '${currency.isEmpty ? '' : '$currency '}\u2022\u2022\u2022\u2022';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: AppGradients.primary(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -46,
                bottom: -56,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.55,
                    child: SizedBox(
                      width: 170,
                      height: 186,
                      child: SvgPicture.asset(
                        'assets/images/figma/brand_logomark.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.homeTotalBalance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          amount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.homeTotalBalance,
                        visualDensity: VisualDensity.compact,
                        onPressed: onToggleVisibility,
                        icon: Icon(
                          revealed
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.homeAccountsCount(counted.length),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive
                ? HomeColors.brand(context)
                : HomeColors.divider(context),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

/// Empty-state used for the Credit Card / Loans / Insurance tabs (not yet
/// available) and for the Accounts tab when there are no accounts to show.
/// Sized to roughly match the accounts carousel + controls so switching
/// tabs doesn't noticeably resize the card.
class _ComingSoonPlaceholder extends StatelessWidget {
  const _ComingSoonPlaceholder({
    required this.icon,
    required this.title,
    this.isMessageOnly = false,
  });

  final IconData icon;
  final String title;

  /// When true, [title] is shown as the message itself (no heading +
  /// "coming soon" sub-line) — used for the Accounts empty state.
  final bool isMessageOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: HomeColors.brand(context).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: HomeColors.brand(context), size: 26),
            ),
            const SizedBox(height: 14),
            if (isMessageOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              )
            else ...[
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.featureComingSoon,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}