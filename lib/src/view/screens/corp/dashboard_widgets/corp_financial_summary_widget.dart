import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// OBDX `account-financial-summary` — the corporate portfolio roll-up.
///
/// Distinct from the per-account Account Summary grid: this shows the
/// host's own `summary.items[]` totals for each product group (CASA /
/// Deposits / Loans) with the account count behind each, already converted
/// to the bank's calculation currency. The figures are the ones OBDX
/// itself computed, not a client-side sum — see
/// [CorpAccountGroupSummary.headlineTotal].
///
/// Takes no constructor arguments and reads its own providers, so the
/// dashboard widget registry can build it from a `componentName` alone.
class CorpFinancialSummaryWidget extends ConsumerWidget {
  const CorpFinancialSummaryWidget({super.key});

  /// Product groups in the order the corporate dashboard presents them.
  static const _groups = <CorpAccountGroup>[
    CorpAccountGroup.casa,
    CorpAccountGroup.deposit,
    CorpAccountGroup.loan,
  ];

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

  static IconData _iconFor(CorpAccountGroup group) {
    switch (group) {
      case CorpAccountGroup.casa:
        return Icons.account_balance_wallet_outlined;
      case CorpAccountGroup.deposit:
        return Icons.savings_outlined;
      case CorpAccountGroup.loan:
        return Icons.request_quote_outlined;
      case CorpAccountGroup.other:
        return Icons.account_balance_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(corpAccountsProvider);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CorpCardHeader(title: 'Financial Summary'),
          const SizedBox(height: 16),
          if (state.isLoading && state.summary.groupSummaries.isEmpty)
            const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.summary.groupSummaries.isEmpty)
            SizedBox(
              height: 96,
              child: Center(
                child: Text(
                  state.errorMessage ?? 'No portfolio summary available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // Three tiles across when there's room, stacked on a phone.
                final stacked = constraints.maxWidth < 420;
                final tiles = [
                  for (final group in _groups)
                    _GroupTile(
                      group: group,
                      label: _labelFor(group),
                      icon: _iconFor(group),
                      summary: state.summary.summaryFor(group),
                    ),
                ];

                if (stacked) {
                  return Column(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        tiles[i],
                      ],
                    ],
                  );
                }
                // IntrinsicHeight, because `CrossAxisAlignment.stretch` on a
                // Row inside this unbounded-height Column would resolve to an
                // infinite height constraint. It bounds the row to the
                // tallest tile so all three still match.
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: tiles[i]),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.label,
    required this.icon,
    required this.summary,
  });

  final CorpAccountGroup group;
  final String label;
  final IconData icon;
  final CorpAccountGroupSummary? summary;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    final total = summary?.headlineTotal;
    final count = summary?.count ?? 0;

    // A loan total is money owed, so it reads as a negative position even
    // though the host reports it as a positive outstanding balance.
    final isLiability = group == CorpAccountGroup.loan && (total?.amount ?? 0) > 0;
    final amountColor = isLiability
        ? CorpColors.negativeBalance(context)
        : CorpColors.textPrimary(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: CorpColors.tile(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CorpColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: brand),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CorpMoneyFormat.formatAmount(total, placeholder: '—'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == 1 ? '1 account' : '$count accounts',
            style: TextStyle(
              fontSize: 11.5,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
