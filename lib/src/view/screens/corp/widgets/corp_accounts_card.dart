import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_account_hero_card.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Dashboard card with the **Accounts / Deposits / Loans** tab strip, the
/// account carousel, the account-type filter and the "View all accounts"
/// link — the top-left panel of the corporate design.
///
/// Accounts come from the aggregated `account/v1/accounts` load that the
/// dashboard already performs. Deposits (`td/v1/deposit`) and Loans
/// (`loan/v1/loan`) are fetched the first time their tab is opened, so the
/// dashboard's first paint is one request, not three.
class CorpAccountsCard extends ConsumerStatefulWidget {
  const CorpAccountsCard({
    super.key,
    this.onViewAll,
    this.onAccountTap,
  });

  /// "View all accounts" — receives the group currently being viewed.
  final ValueChanged<CorpAccountGroup>? onViewAll;

  final ValueChanged<CorpAccount>? onAccountTap;

  @override
  ConsumerState<CorpAccountsCard> createState() => _CorpAccountsCardState();
}

class _CorpAccountsCardState extends ConsumerState<CorpAccountsCard> {
  /// Tab order as laid out in the design.
  static const _tabs = <CorpAccountGroup>[
    CorpAccountGroup.casa,
    CorpAccountGroup.deposit,
    CorpAccountGroup.loan,
  ];

  static const _allTypesFilter = 'All';

  final PageController _pageController = PageController();

  CorpAccountGroup _group = CorpAccountGroup.casa;
  int _page = 0;

  /// Selected product filter per tab, so switching tabs and coming back
  /// keeps what the user had picked.
  final Map<CorpAccountGroup, String> _typeFilters = {};

  /// Accounts whose balance the user has revealed, keyed by account id.
  final Set<String> _revealedIds = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectGroup(CorpAccountGroup group) {
    if (group == _group) return;
    setState(() {
      _group = group;
      _page = 0;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
    // Deposits / Loans load on first view.
    ref.read(corpAccountsProvider.notifier).ensureGroupLoaded(group);
  }

  void _toggleReveal(CorpAccount account) {
    final key = account.id.isNotEmpty ? account.id : account.displayNumber;
    setState(() {
      if (!_revealedIds.remove(key)) _revealedIds.add(key);
    });
  }

  bool _isRevealed(CorpAccount account) {
    final key = account.id.isNotEmpty ? account.id : account.displayNumber;
    return _revealedIds.contains(key);
  }

  void _goToPage(int page, int count) {
    if (count == 0) return;
    final next = page.clamp(0, count - 1);
    setState(() => _page = next);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  List<CorpAccount> _visibleAccounts(CorpAccountsSummary summary) {
    final accounts = summary.accountsIn(_group);
    final filter = _typeFilters[_group];
    if (filter == null || filter == _allTypesFilter) return accounts;
    return accounts
        .where((account) => account.accountTypeLabel == filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpAccountsProvider);
    final entityName = ref.watch(corpProfileProvider).entityName;
    final accounts = _visibleAccounts(state.summary);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CorpTabStrip(
            tabs: _tabs,
            selected: _group,
            onSelected: _selectGroup,
          ),
          const SizedBox(height: 18),
          _buildBody(context, state, accounts, entityName),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CorpAccountsState state,
    List<CorpAccount> accounts,
    String? entityName,
  ) {
    final isLoading = _group == CorpAccountGroup.casa
        ? state.isLoading
        : state.isGroupLoading(_group);
    final error = _group == CorpAccountGroup.casa
        ? state.errorMessage
        : state.groupError(_group);

    if (isLoading && accounts.isEmpty) {
      return const SizedBox(
        height: 208,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null && accounts.isEmpty) {
      return _CorpCardMessage(
        icon: Icons.error_outline_rounded,
        message: error,
        onRetry: () {
          final notifier = ref.read(corpAccountsProvider.notifier);
          if (_group == CorpAccountGroup.casa) {
            notifier.refresh();
          } else {
            notifier.refreshGroup(_group);
          }
        },
      );
    }

    if (accounts.isEmpty) {
      return _CorpCardMessage(
        icon: _emptyIconFor(_group),
        message: _emptyMessageFor(_group),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _pageController,
            itemCount: accounts.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (_, index) => CorpAccountHeroCard(
              account: accounts[index],
              holderName: entityName,
              revealed: _isRevealed(accounts[index]),
              onToggleVisibility: () => _toggleReveal(accounts[index]),
              onTap: widget.onAccountTap == null
                  ? null
                  : () => widget.onAccountTap!(accounts[index]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _CarouselArrows(
          page: _page,
          count: accounts.length,
          onPrevious: () => _goToPage(_page - 1, accounts.length),
          onNext: () => _goToPage(_page + 1, accounts.length),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: _AccountTypeFilter(
                options: [
                  _allTypesFilter,
                  ...ref
                      .watch(corpAccountsProvider)
                      .summary
                      .productNamesIn(_group),
                ],
                value: _typeFilters[_group] ?? _allTypesFilter,
                onChanged: (value) => setState(() {
                  _typeFilters[_group] = value;
                  _page = 0;
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(0);
                  }
                }),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: widget.onViewAll == null
                  ? null
                  : () => widget.onViewAll!(_group),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  // TODO(l10n): wire through AppLocalizations once a
                  // translated key exists for every locale.
                  _viewAllLabelFor(_group),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CorpColors.brand(context),
                    decoration: TextDecoration.underline,
                    decorationColor: CorpColors.brand(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _viewAllLabelFor(CorpAccountGroup group) {
    switch (group) {
      case CorpAccountGroup.deposit:
        return 'View all deposits';
      case CorpAccountGroup.loan:
        return 'View all loans';
      case CorpAccountGroup.casa:
      case CorpAccountGroup.other:
        return 'View all accounts';
    }
  }

  static String _emptyMessageFor(CorpAccountGroup group) {
    switch (group) {
      case CorpAccountGroup.deposit:
        return 'No deposits available for this party.';
      case CorpAccountGroup.loan:
        return 'No loans available for this party.';
      case CorpAccountGroup.casa:
      case CorpAccountGroup.other:
        return 'No accounts available for this party.';
    }
  }

  static IconData _emptyIconFor(CorpAccountGroup group) {
    switch (group) {
      case CorpAccountGroup.deposit:
        return Icons.savings_outlined;
      case CorpAccountGroup.loan:
        return Icons.request_quote_outlined;
      case CorpAccountGroup.casa:
      case CorpAccountGroup.other:
        return Icons.account_balance_outlined;
    }
  }
}

/// Underlined tab strip — "Accounts | Deposits | Loans".
class _CorpTabStrip extends StatelessWidget {
  const _CorpTabStrip({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<CorpAccountGroup> tabs;
  final CorpAccountGroup selected;
  final ValueChanged<CorpAccountGroup> onSelected;

  static String _labelFor(CorpAccountGroup group) {
    switch (group) {
      case CorpAccountGroup.casa:
        return 'Accounts';
      case CorpAccountGroup.deposit:
        return 'Deposits';
      case CorpAccountGroup.loan:
        return 'Loans';
      case CorpAccountGroup.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CorpColors.divider(context)),
        ),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Center(
                child: InkWell(
                  onTap: () => onSelected(tab),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: tab == selected
                              ? CorpColors.brand(context)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      _labelFor(tab),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: tab == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: tab == selected
                            ? CorpColors.textPrimary(context)
                            : CorpColors.textSecondary(context),
                        decoration: tab == selected
                            ? TextDecoration.underline
                            : TextDecoration.none,
                        decorationColor: CorpColors.textPrimary(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `‹  ›` carousel controls, centred under the card as in the design.
class _CarouselArrows extends StatelessWidget {
  const _CarouselArrows({
    required this.page,
    required this.count,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int count;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox(height: 8);
    final active = CorpColors.textSecondary(context);
    final disabled = CorpColors.divider(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous account',
          color: page > 0 ? active : disabled,
          onTap: page > 0 ? onPrevious : null,
        ),
        const SizedBox(width: 18),
        _ArrowButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next account',
          color: page < count - 1 ? active : disabled,
          onTap: page < count - 1 ? onNext : null,
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

/// Product filter under the carousel. Options are the distinct product
/// descriptions actually present on the loaded accounts, so this filters
/// real data rather than offering fixed labels.
class _AccountTypeFilter extends StatelessWidget {
  const _AccountTypeFilter({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Guard against a stale selection after a refresh changed the account
    // mix — fall back to the first option rather than asserting.
    final resolved = options.contains(value) ? value : options.first;

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: resolved,
        isDense: true,
        isExpanded: true,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: CorpColors.textSecondary(context),
        ),
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: CorpColors.textPrimary(context),
        ),
        dropdownColor: CorpColors.card(context),
        borderRadius: BorderRadius.circular(12),
        items: [
          for (final option in options)
            DropdownMenuItem<String>(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}

/// Empty / error state sized to roughly match the carousel so switching
/// tabs does not visibly resize the card.
class _CorpCardMessage extends StatelessWidget {
  const _CorpCardMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: CorpColors.brand(context).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: CorpColors.brand(context), size: 26),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: CorpColors.textSecondary(context),
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
