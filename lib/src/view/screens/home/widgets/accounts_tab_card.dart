import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import '../home_colors.dart';

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
class AccountsTabCard extends StatefulWidget {
  const AccountsTabCard({
    super.key,
    required this.accounts,
    required this.revealedAccountIds,
    required this.onToggleAccountVisibility,
    this.displayName = '',
    this.onViewAllAccountsTap,
  });

  final List<CasaAccount> accounts;
  final Set<String> revealedAccountIds;
  final ValueChanged<String> onToggleAccountVisibility;

  /// Resolved account-holder name, shown on the account card.
  final String displayName;

  /// Invoked when "View all accounts" is tapped.
  final VoidCallback? onViewAllAccountsTap;

  @override
  State<AccountsTabCard> createState() => _AccountsTabCardState();
}

enum _HeroTab { accounts, creditCard, loans, insurance }

class _AccountsTabCardState extends State<AccountsTabCard> {
  _HeroTab _tab = _HeroTab.accounts;
  final PageController _pageController = PageController();
  int _page = 0;
  String _accountTypeFilter = _AccountTypeDropdown.savingAccount;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _accountKey(CasaAccount account) =>
      account.id.isNotEmpty ? account.id : account.displayNumber;

  @override
  Widget build(BuildContext context) {
    // TODO(l10n): wire through AppLocalizations once translated keys land
    // for the Credit Card / Loans / Insurance tab labels.
    const tabs = ['Accounts', 'Credit Card', 'Loans', 'Insurance'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
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
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    switch (_tab) {
      case _HeroTab.accounts:
        return _buildAccountsTab(context);
      case _HeroTab.creditCard:
        return const _ComingSoonPlaceholder(
          icon: Icons.credit_card_outlined,
          // TODO(l10n): wire through AppLocalizations once a translated
          // key is added for all locales.
          title: 'Credit Card',
        );
      case _HeroTab.loans:
        return const _ComingSoonPlaceholder(
          icon: Icons.request_quote_outlined,
          title: 'Loans',
        );
      case _HeroTab.insurance:
        return const _ComingSoonPlaceholder(
          icon: Icons.shield_outlined,
          title: 'Insurance',
        );
    }
  }

  Widget _buildAccountsTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts = widget.accounts;

    if (accounts.isEmpty) {
      return _ComingSoonPlaceholder(
        icon: Icons.account_balance_outlined,
        title: l10n.accountsEmpty,
        isMessageOnly: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 168,
          child: accounts.length == 1
              ? _HeroAccountCard(
                  accountHolderName: widget.displayName,
                  account: accounts.first,
                  revealed: widget.revealedAccountIds
                      .contains(_accountKey(accounts.first)),
                  onToggleVisibility: () => widget
                      .onToggleAccountVisibility(_accountKey(accounts.first)),
                )
              : PageView.builder(
                  controller: _pageController,
                  itemCount: accounts.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _HeroAccountCard(
                      accountHolderName: widget.displayName,
                      account: accounts[index],
                      revealed: widget.revealedAccountIds
                          .contains(_accountKey(accounts[index])),
                      onToggleVisibility: () => widget.onToggleAccountVisibility(
                          _accountKey(accounts[index])),
                    ),
                  ),
                ),
        ),
        if (accounts.length > 1) ...[
          const SizedBox(height: 10),
          _CarouselDots(count: accounts.length, active: _page),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
           
               _AccountTypeDropdown(
                value: _accountTypeFilter,
                onChanged: (value) =>
                    setState(() => _accountTypeFilter = value),
              ),
            
            const SizedBox(width: 10),
            InkWell(
              onTap: widget.onViewAllAccountsTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  // TODO(l10n): wire through AppLocalizations once a
                  // translated key is added for all locales.
                  'View all accounts',
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _AccountTypeDropdown extends StatelessWidget {
  const _AccountTypeDropdown({required this.value, required this.onChanged});

  static const savingAccount = 'Saving Account';
  static const regularAccount = 'Regular Account';
  static const _options = [savingAccount, regularAccount];

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        isExpanded: false,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: HomeColors.textSecondary(context),
        ),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: HomeColors.textPrimary(context),
        ),
        dropdownColor: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        items: _options
            .map((option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ))
            .toList(),
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
  String _groupedMaskedNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s+'), '');
    if (digits.isEmpty) return '';
    final visibleLength = digits.length >= 4 ? 4 : digits.length;
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
    final numberText = _groupedMaskedNumber(account.displayNumber);

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
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            // TODO(l10n): wire through AppLocalizations once
                            // a translated key is added for all locales.
                            'Primary Account',
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