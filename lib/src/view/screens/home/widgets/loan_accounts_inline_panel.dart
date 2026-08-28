import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/providers/loan_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Compact "Loan & Finance" list embedded in the Accounts tab's category
/// filter — same data source and tile design as [LoanAccountsListScreen],
/// without the standalone `Scaffold`/`AppBar` (this is embedded content,
/// not a pushed page).
class LoanAccountsInlinePanel extends ConsumerStatefulWidget {
  const LoanAccountsInlinePanel({super.key});

  @override
  ConsumerState<LoanAccountsInlinePanel> createState() =>
      _LoanAccountsInlinePanelState();
}

class _LoanAccountsInlinePanelState
    extends ConsumerState<LoanAccountsInlinePanel> {
  final Set<String> _revealedLoanIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(loanAccountsProvider.notifier).ensureLoaded();
    });
  }

  void _toggleRevealed(String key) {
    setState(() {
      if (!_revealedLoanIds.remove(key)) {
        _revealedLoanIds.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loanAccountsProvider);
    final loans = state.summary?.loans ?? const <LoanAccount>[];

    if (state.isLoading && loans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null && loans.isEmpty) {
      return _MessageCard(
        message: state.errorMessage!,
        actionLabel: l10n.accountsRetry,
        onAction: () => ref.read(loanAccountsProvider.notifier).refresh(),
      );
    }

    if (loans.isEmpty) {
      return _MessageCard(message: l10n.loansEmpty);
    }

    return Column(
      children: [
        for (var i = 0; i < loans.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _LoanTile(
            loan: loans[i],
            revealed: _revealedLoanIds.contains(_loanKey(loans[i])),
            onToggleVisibility: () => _toggleRevealed(_loanKey(loans[i])),
          ),
        ],
      ],
    );
  }
}

String _loanKey(LoanAccount loan) {
  if (loan.id.isNotEmpty) return loan.id;
  return loan.displayNumber;
}

class _LoanTile extends StatelessWidget {
  const _LoanTile({
    required this.loan,
    required this.revealed,
    required this.onToggleVisibility,
  });

  final LoanAccount loan;
  final bool revealed;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outstanding = loan.outstandingAmount;
    final currency = outstanding?.currency ?? loan.currencyCode;
    final amountText = outstanding == null
        ? '—'
        : MoneyFormat.format(
            outstanding.amount,
            currencyCode: currency,
            hidden: !revealed,
          );

    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pushNamed(
            RoutesConst.loanAccountDetailsScreen,
            arguments: LoanAccountDetailsArgs(loan: loan),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.teal50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.request_quote_outlined,
                  color: HomeColors.brand(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loan.displayNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: HomeColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        amountText,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: HomeColors.textPrimary(context),
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
                            size: 18,
                            color: HomeColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.loanOutstandingAmountLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: HomeColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HomeColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
