import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// CASA account list with per-account balance reveal and navigation to details.
class CasaAccountsPanel extends StatelessWidget {
  const CasaAccountsPanel({
    super.key,
    required this.accounts,
    required this.revealedAccountIds,
    required this.onToggleAccountVisibility,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
  });

  final List<CasaAccount> accounts;
  final Set<String> revealedAccountIds;
  final ValueChanged<String> onToggleAccountVisibility;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (isLoading && accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null && accounts.isEmpty) {
      return _MessageCard(
        message: errorMessage!,
        actionLabel: l10n.accountsRetry,
        onAction: onRetry,
      );
    }

    if (accounts.isEmpty) {
      return _MessageCard(message: l10n.accountsEmpty);
    }

    return Column(
      children: [
        for (var i = 0; i < accounts.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _AccountTile(
            account: accounts[i],
            revealed: revealedAccountIds.contains(_accountKey(accounts[i])),
            onToggleVisibility: () =>
                onToggleAccountVisibility(_accountKey(accounts[i])),
          ),
        ],
      ],
    );
  }
}

String _accountKey(CasaAccount account) {
  if (account.id.isNotEmpty) return account.id;
  return account.displayNumber;
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.revealed,
    required this.onToggleVisibility,
  });

  final CasaAccount account;
  final bool revealed;
  final VoidCallback onToggleVisibility;

  void _openDetails(BuildContext context) {
    if (account.id.isEmpty) return;
    Navigator.of(context).pushNamed(
      RoutesConst.casaAccountDetailsScreen,
      arguments: CasaAccountDetailsArgs(accountId: account.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final balance = account.displayBalance;
    final currency = balance?.currency ?? account.currencyCode;
    final amountText = balance == null
        ? '—'
        : MoneyFormat.format(
            balance.amount,
            currencyCode: currency,
            hidden: !revealed,
          );
    final statusLabel = account.isDormant
        ? l10n.accountStatusDormant
        : l10n.accountStatusActive;
    final numberText =
        revealed ? account.displayNumber : account.maskedNumber;

    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetails(context),
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
                  Icons.account_balance_outlined,
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
                      account.title,
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
                      numberText,
                      style: TextStyle(
                        fontSize: 12,
                        color: HomeColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
color: account.isDormant
    ? AppColors.warningColor
    : AppColors.successColor,
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
                    l10n.availableBalanceLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: HomeColors.textSecondary(context),
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
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
