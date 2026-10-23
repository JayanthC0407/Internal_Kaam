import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:ubci_bank/src/view/providers/common/credit_card_providers.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/credit_card_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/widgets/credit_card_face.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Credit Cards — OBDX `credit-card-listing`: each card with Available
/// Credit Limit, Current Outstanding and, when something is billed, Total
/// Due / Minimum Due / Due On and Pay — else "No Dues". Transactions opens
/// in place. Card Payment and the other card actions are Access Denied in
/// UAT and not built. Evidence: docs/obdx/features/credit-cards.md §3.
class CreditCardsScreen extends ConsumerStatefulWidget {
  const CreditCardsScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<CreditCardsScreen> createState() => _CreditCardsScreenState();
}

class _CreditCardsScreenState extends ConsumerState<CreditCardsScreen> {
  /// Transactions shown in place of the list.
  CreditCard? _transactionsFor;

  @override
  Widget build(BuildContext context) {
    final open = _transactionsFor;
    if (open != null) {
      return CreditCardTransactionsScreen(
        embedded: true,
        initialCardId: open.id,
        onBack: () => setState(() => _transactionsFor = null),
      );
    }

    final l10n = AppLocalizations.of(context);
    final cards = ref.watch(creditCardsProvider);
    return PayMenuPage(
      title: l10n.ccTitle,
      subtitle: l10n.ccSubtitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) => cards.when(
        loading: () => const PayCard(
          child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        ),
        error: (error, _) => PayErrorRetry(
          message: error is CardsLoadError && error.message != null ? error.message! : l10n.ccLoadFailed,
          onRetry: () => ref.invalidate(creditCardsProvider),
        ),
        data: (list) {
          if (list.isEmpty) return PayCard(child: PayMuted(l10n.ccEmpty));
          final tiles = [
            for (final (i, card) in list.indexed)
              _CardPanel(
                card: card,
                index: i,
                onTransactions: card.canViewTransactions ? () => setState(() => _transactionsFor = card) : null,
              ),
          ];
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 16), child: t),
              ],
            );
          }
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final t in tiles) SizedBox(width: 440, child: t)],
          );
        },
      ),
    );
  }
}

class _CardPanel extends StatelessWidget {
  const _CardPanel({required this.card, required this.index, this.onTransactions});

  final CreditCard card;
  final int index;
  final VoidCallback? onTransactions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final rows = <(String, String)>[
      (l10n.ccCurrentOutstanding, cardMoney(card.currentOutstanding)),
      if (card.hasDues) ...[
        (l10n.ccTotalDue, cardMoney(card.totalDue)),
        (l10n.ccMinimumDue, cardMoney(card.minimumDue)),
        if (card.dueDate != null) (l10n.ccDueOn, loc.formatMediumDate(card.dueDate!)),
      ],
    ].where((r) => r.$2.isNotEmpty).toList();

    void comingSoon(String feature) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature · ${l10n.featureComingSoon}')));

    return PayCard(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CreditCardFace(card: card, index: index, onTap: onTransactions),
          const SizedBox(height: 12),
          for (final (i, (label, value)) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              decoration: BoxDecoration(
                border: i == rows.length - 1 ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)))),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context))),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (card.hasDues)
                Expanded(child: PayPrimaryButton(label: l10n.ccPay, onPressed: () => comingSoon(l10n.ccCardPayment)))
              else
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: HomeColors.success(context).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.ccNoDues,
                      style: TextStyle(fontWeight: FontWeight.w700, color: HomeColors.success(context)),
                    ),
                  ),
                ),
              if (onTransactions != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: PaySecondaryButton(
                    label: l10n.ccTransactions,
                    icon: Icons.receipt_long_rounded,
                    onPressed: onTransactions,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
