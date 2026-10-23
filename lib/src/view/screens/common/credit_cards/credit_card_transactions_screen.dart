import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:ubci_bank/src/view/providers/common/credit_card_providers.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/widgets/credit_card_face.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Credit card Transactions — OBDX `creditcard-transactions` (the shared
/// account-transactions with type CREDIT): Unbilled Transactions (default)
/// or Billed Transactions for a Month taken from the 12 months before the
/// last statement. Evidence: docs/obdx/features/credit-cards.md §4.
///
/// Differs from OBDX in one place: Billed pre-selects the latest month
/// instead of waiting for a pick (same request, one tap less).
class CreditCardTransactionsScreen extends ConsumerStatefulWidget {
  const CreditCardTransactionsScreen({super.key, this.embedded = false, this.onBack, this.initialCardId});

  final bool embedded;
  final VoidCallback? onBack;
  final String? initialCardId;

  @override
  ConsumerState<CreditCardTransactionsScreen> createState() => _CreditCardTransactionsScreenState();
}

class _CreditCardTransactionsScreenState extends ConsumerState<CreditCardTransactionsScreen> {
  late String? _cardId = widget.initialCardId;
  CardStatementType _type = CardStatementType.unbilled;
  CardStatementMonth? _month;

  String _monthLabel(BuildContext context, CardStatementMonth m) =>
      MaterialLocalizations.of(context).formatMonthYear(DateTime(m.year, m.month));

  Future<void> _pickCard(List<CreditCard> cards) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPayPicker<String>(
      context,
      title: l10n.ccCardNumber,
      selected: _cardId,
      options: [
        for (final c in cards)
          PayOption(value: c.id, title: c.displayNumber, subtitle: c.ownerName, icon: Icons.credit_card_rounded),
      ],
    );
    if (picked != null && mounted) {
      setState(() {
        _cardId = picked;
        _month = null;
      });
    }
  }

  Future<void> _pickMonth(List<CardStatementMonth> months) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPayPicker<CardStatementMonth>(
      context,
      title: l10n.ccMonth,
      selected: _month,
      options: [for (final m in months) PayOption(value: m, title: _monthLabel(context, m))],
    );
    if (picked != null && mounted) setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cards = ref.watch(creditCardsProvider);

    return PayMenuPage(
      title: l10n.ccTransactions,
      subtitle: l10n.ccTitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) => cards.when(
        loading: () => const PayCard(
          child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        ),
        error: (error, _) => PayErrorRetry(
          message: error is CardsLoadError && error.message != null ? error.message! : l10n.ccLoadFailed,
          onRetry: () => ref.invalidate(creditCardsProvider),
        ),
        data: (all) {
          final eligible = all.where((c) => c.canViewTransactions).toList();
          if (eligible.isEmpty) return PayCard(child: PayMuted(l10n.ccEmpty));
          final card = eligible.firstWhere((c) => c.id == _cardId, orElse: () => eligible.first);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaySection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PayFieldLabel(l10n.ccCardNumber),
                    PayPickerField(
                      placeholder: card.displayNumber,
                      title: card.displayNumber,
                      subtitle: card.ownerName,
                      icon: Icons.credit_card_rounded,
                      onTap: eligible.length > 1 ? () => _pickCard(eligible) : null,
                    ),
                    const SizedBox(height: 14),
                    PayChoiceChips<CardStatementType>(
                      options: [
                        (CardStatementType.unbilled, l10n.ccUnbilled),
                        (CardStatementType.billed, l10n.ccBilled),
                      ],
                      selected: _type,
                      onChanged: (t) => setState(() {
                        _type = t;
                        _month = null;
                      }),
                    ),
                    if (_type == CardStatementType.billed) ...[
                      const SizedBox(height: 14),
                      _BilledMonth(
                        cardId: card.id,
                        month: _month,
                        label: (m) => _monthLabel(context, m),
                        onDefault: (m) => WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _month == null) setState(() => _month = m);
                        }),
                        onPick: _pickMonth,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_type == CardStatementType.unbilled || _month != null)
                _TransactionList(
                  query: CardTransactionsQuery(
                    cardId: card.id,
                    type: _type,
                    month: _type == CardStatementType.billed ? _month : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Billed: asks OBDX for the latest statement (no month) to learn its
/// date, then offers the 12 months before it (hooks.js:145-157, 725-748).
class _BilledMonth extends ConsumerWidget {
  const _BilledMonth({
    required this.cardId,
    required this.month,
    required this.label,
    required this.onDefault,
    required this.onPick,
  });

  final String cardId;
  final CardStatementMonth? month;
  final String Function(CardStatementMonth) label;
  final ValueChanged<CardStatementMonth> onDefault;
  final ValueChanged<List<CardStatementMonth>> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final probe = ref.watch(cardTransactionsProvider(
      CardTransactionsQuery(cardId: cardId, type: CardStatementType.billed),
    ));
    return probe.when(
      loading: () => PayPickerField(placeholder: l10n.addBillerSelect, onTap: null, loading: true),
      error: (error, _) => PayErrorRetry(
        message: error is CardsLoadError && error.message != null ? error.message! : l10n.ccTxLoadFailed,
        onRetry: () => ref.invalidate(cardTransactionsProvider(
          CardTransactionsQuery(cardId: cardId, type: CardStatementType.billed),
        )),
      ),
      data: (result) {
        final date = result.statementDate;
        if (date == null) return PayMuted(l10n.casaTransactionsEmpty);
        final months = billedMonths(date);
        if (month == null) onDefault(months.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PayFieldLabel(l10n.ccMonth),
            PayPickerField(
              placeholder: l10n.addBillerSelect,
              title: month == null ? null : label(month!),
              icon: Icons.calendar_month_rounded,
              onTap: () => onPick(months),
            ),
          ],
        );
      },
    );
  }
}

class _TransactionList extends ConsumerWidget {
  const _TransactionList({required this.query});

  final CardTransactionsQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final result = ref.watch(cardTransactionsProvider(query));
    return result.when(
      loading: () => const PayCard(
        child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      ),
      error: (error, _) => PayErrorRetry(
        message: error is CardsLoadError && error.message != null ? error.message! : l10n.ccTxLoadFailed,
        onRetry: () => ref.invalidate(cardTransactionsProvider(query)),
      ),
      data: (data) {
        if (data.transactions.isEmpty) return PayCard(child: PayMuted(l10n.casaTransactionsEmpty));
        return PaySection(
          child: Column(
            children: [
              for (final (i, t) in data.transactions.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: i == data.transactions.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: HomeColors.divider(context))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                            ),
                            if (t.date != null) ...[
                              const SizedBox(height: 2),
                              Text(loc.formatMediumDate(t.date!), style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${t.isCredit ? '+' : '-'} ${cardMoney(t.amount)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.isCredit ? HomeColors.success(context) : HomeColors.error(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
