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
/// Laid out as the designer's page (UI designs 2026-10-27): the choices
/// inline above a table on web; a choice reloads at once (no Apply, user
/// decision). OBDX's Amount field is left out: for cards it is never sent
/// nor applied (account-transactions/hooks.js:1218-1232; user decision).
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

  Future<void> _pickType() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPayPicker<CardStatementType>(
      context,
      title: l10n.casaFilterViewOptions,
      selected: _type,
      options: [
        PayOption(value: CardStatementType.unbilled, title: l10n.ccUnbilled),
        PayOption(value: CardStatementType.billed, title: l10n.ccBilled),
      ],
    );
    if (picked != null && picked != _type && mounted) {
      setState(() {
        _type = picked;
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
          final cardField = PayBoxedPicker(
            label: l10n.ccCardNumber,
            value: card.displayNumber,
            onTap: eligible.length > 1 ? () => _pickCard(eligible) : null,
          );
          final typeField = PayBoxedPicker(
            label: l10n.casaFilterViewOptions,
            value: _type == CardStatementType.unbilled ? l10n.ccUnbilled : l10n.ccBilled,
            onTap: _pickType,
          );
          final monthField = _type == CardStatementType.billed
              ? _BilledMonth(
                  cardId: card.id,
                  month: _month,
                  label: (m) => _monthLabel(context, m),
                  onDefault: (m) => WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _month == null) setState(() => _month = m);
                  }),
                  onPick: _pickMonth,
                )
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PayCard(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cardField),
                          const SizedBox(width: 16),
                          Expanded(child: typeField),
                          const SizedBox(width: 16),
                          Expanded(child: monthField ?? const SizedBox.shrink()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          cardField,
                          const SizedBox(height: 12),
                          typeField,
                          if (monthField != null) ...[const SizedBox(height: 12), monthField],
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              if (_type == CardStatementType.unbilled || _month != null)
                _TransactionList(
                  wide: wide,
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
      loading: () => PayBoxedPicker(label: l10n.ccMonth, placeholder: l10n.addBillerSelect, loading: true),
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
        return PayBoxedPicker(
          label: l10n.ccMonth,
          value: month == null ? null : label(month!),
          placeholder: l10n.addBillerSelect,
          onTap: () => onPick(months),
        );
      },
    );
  }
}

class _TransactionList extends ConsumerWidget {
  const _TransactionList({required this.query, required this.wide});

  final CardTransactionsQuery query;

  /// Web: OBDX's table (Date, Description, Transaction Type, Amount).
  final bool wide;

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
        if (wide) {
          final primary = HomeColors.textPrimary(context);
          return PayCard(
            padding: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PayTableHeader(cells: [
                  (l10n.casaFilterDate, 2),
                  (l10n.casaColDescription, 6),
                  (l10n.casaColType, 2),
                  (l10n.casaColAmount, 2),
                ]),
                for (final (i, t) in data.transactions.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: i == data.transactions.length - 1
                          ? null
                          : Border(bottom: BorderSide(color: HomeColors.divider(context))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(t.date == null ? '' : loc.formatShortDate(t.date!), style: TextStyle(color: primary)),
                        ),
                        Expanded(
                          flex: 6,
                          child: Text(t.description, style: TextStyle(fontWeight: FontWeight.w600, color: primary)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            t.isCredit ? l10n.casaTxnTypeCredit : l10n.casaTxnTypeDebit,
                            style: TextStyle(color: primary),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            cardMoney(t.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: t.isCredit ? HomeColors.success(context) : primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }
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
