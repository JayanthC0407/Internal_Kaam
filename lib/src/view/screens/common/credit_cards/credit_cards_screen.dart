import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/view/providers/common/credit_card_providers.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/credit_card_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/widgets/credit_card_face.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Credit Cards — OBDX `credit-card-listing`, in the designer's layout
/// (UI designs 2026-10-27): summary tiles, search and Filter (the design's,
/// on the device — OBDX has neither), then a row per card with OBDX's
/// fields: Available Credit Limit, Current Outstanding and, when something
/// is billed, Total Due / Minimum Due / Due On and Pay — else "No Dues".
/// The ⋮ menu is OBDX's, built from ownership and status; only Transactions
/// is built (it opens in place), the rest are Access Denied in UAT.
/// Evidence: docs/obdx/features/credit-cards.md §3, §7.
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
  CreditCardFilter _filter = const CreditCardFilter();

  /// The tiles' eye: amounts masked.
  bool _hidden = false;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  String _actionLabel(AppLocalizations l10n, CreditCardAction a) => switch (a) {
        CreditCardAction.details => l10n.ccCardDetails,
        CreditCardAction.transactions => l10n.ccTransactions,
        CreditCardAction.cardPayment => l10n.ccCardPayment,
        CreditCardAction.requestPin => l10n.ccRequestPin,
        CreditCardAction.resetPin => l10n.ccResetPin,
        CreditCardAction.blockCard => l10n.ccBlockCard,
        CreditCardAction.unblockCard => l10n.ccUnblockCard,
        CreditCardAction.cancelCard => l10n.ccCancelCard,
        CreditCardAction.autoPay => l10n.ccAutoPay,
        CreditCardAction.addOnCard => l10n.ccAddOn,
      };

  void _onAction(CreditCard card, CreditCardAction action) {
    final l10n = AppLocalizations.of(context);
    if (action == CreditCardAction.transactions) {
      setState(() => _transactionsFor = card);
      return;
    }
    _snack('${_actionLabel(l10n, action)} · ${l10n.featureComingSoon}');
  }

  /// The design's Filter: Ownership and Card Number, applied as they change.
  Future<void> _openFilter(List<CreditCard> cards) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          void update(CreditCardFilter f) {
            setState(() => _filter = f);
            setSheet(() {});
          }

          final f = _filter;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.filter, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  PayFieldLabel(l10n.ccOwnership),
                  PayChoiceChips<bool?>(
                    options: [(null, l10n.casaFilterAll), (true, l10n.ccPrimary), (false, l10n.ccAddOn)],
                    selected: f.primary,
                    onChanged: (v) => update(CreditCardFilter(query: f.query, primary: v, cardId: f.cardId)),
                  ),
                  const SizedBox(height: 16),
                  PayBoxedPicker(
                    label: l10n.ccCardNumber,
                    value: f.cardId == null
                        ? l10n.ccAllCards
                        : cards.where((c) => c.id == f.cardId).firstOrNull?.displayNumber,
                    onTap: () async {
                      // '' = all cards.
                      final picked = await showPayPicker<String>(
                        sheet,
                        title: l10n.ccCardNumber,
                        selected: f.cardId ?? '',
                        options: [
                          PayOption(value: '', title: l10n.ccAllCards),
                          for (final c in {for (final c in cards) c.id: c}.values)
                            PayOption(value: c.id, title: c.displayNumber, subtitle: c.ownerName),
                        ],
                      );
                      if (picked == null) return;
                      update(CreditCardFilter(query: f.query, primary: f.primary, cardId: picked.isEmpty ? null : picked));
                    },
                  ),
                  if (f.isActive) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => update(CreditCardFilter(query: f.query)),
                        child: Text(l10n.ccClearFilters),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
      subtitle: l10n.ccListSubtitle,
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
          final shown = list.where(_filter.matches).toList();
          final title = Text(
            '${l10n.ccTitle} (${shown.length})',
            style: TextStyle(fontSize: wide ? 24 : 20, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
          );
          final search = TextField(
            onChanged: (v) => setState(
              () => _filter = CreditCardFilter(query: v, primary: _filter.primary, cardId: _filter.cardId),
            ),
            decoration: payInputDecoration(
              context,
              hint: l10n.ccSearchHint,
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                child: Icon(Icons.search_rounded, size: 20, color: HomeColors.textSecondary(context)),
              ),
            ),
          );
          final filterButton = Badge(
            isLabelVisible: _filter.isActive,
            smallSize: 9,
            child: OutlinedButton.icon(
              onPressed: () => _openFilter(list),
              icon: const Icon(Icons.filter_list_rounded),
              label: Text(l10n.filter),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryTiles(
                totals: CreditCardTotals.fromCards(list),
                wide: wide,
                hidden: _hidden,
                onToggle: () => setState(() => _hidden = !_hidden),
              ),
              const SizedBox(height: 22),
              if (wide)
                Row(
                  children: [
                    Expanded(flex: 4, child: title),
                    Expanded(flex: 4, child: search),
                    const SizedBox(width: 14),
                    filterButton,
                  ],
                )
              else ...[
                title,
                const SizedBox(height: 10),
                Row(children: [Expanded(child: search), const SizedBox(width: 10), filterButton]),
              ],
              const SizedBox(height: 14),
              if (shown.isEmpty)
                PayCard(child: PayMuted(l10n.ccNoMatch))
              else
                for (final (i, card) in shown.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _CardRow(
                    card: card,
                    wide: wide,
                    actions: [
                      for (final a in creditCardMenu(card)) (a, _actionLabel(l10n, a)),
                    ],
                    onAction: (a) => _onAction(card, a),
                    onPay: () => _onAction(card, CreditCardAction.cardPayment),
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: card.displayNumber));
                      _snack(l10n.ccNumberCopied);
                    },
                  ),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// Total Credit Limit / Current Outstanding / Total Due. One line per
/// currency when the cards use more than one.
class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.totals, required this.wide, required this.hidden, required this.onToggle});

  final List<CreditCardTotals> totals;
  final bool wide;
  final bool hidden;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    String money(double v, String cur) => MoneyFormat.format(v, currencyCode: cur, hidden: hidden);
    String lines(double Function(CreditCardTotals) f) => totals.map((t) => money(f(t), t.currency)).join('\n');

    final active = totals.fold<int>(0, (n, t) => n + t.activeCards);
    final share = totals.length == 1 ? totals.first.outstandingShare : null;
    DateTime? next;
    for (final t in totals) {
      if (t.nextDue != null && (next == null || t.nextDue!.isBefore(next))) next = t.nextDue;
    }

    final tiles = [
      _Tile(
        title: l10n.ccTotalCreditLimit,
        value: lines((t) => t.creditLimit),
        note: l10n.ccActiveCards(active),
        brand: true,
        hidden: hidden,
        onToggle: onToggle,
      ),
      _Tile(
        title: l10n.ccCurrentOutstanding,
        value: lines((t) => t.outstanding),
        note: share == null || hidden ? null : l10n.ccShareOfLimit(share.toStringAsFixed(1)),
        accent: true,
        hidden: hidden,
        onToggle: onToggle,
      ),
      _Tile(
        title: l10n.ccTotalDue,
        value: lines((t) => t.totalDue),
        note: next == null ? null : l10n.ccNextDue(loc.formatShortDate(next)),
        hidden: hidden,
        onToggle: onToggle,
      ),
    ];
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, t) in tiles.indexed) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: t)],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tiles[0],
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: tiles[1]), const SizedBox(width: 12), Expanded(child: tiles[2])],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.value,
    required this.hidden,
    required this.onToggle,
    this.note,
    this.brand = false,
    this.accent = false,
  });

  final String title;
  final String value;
  final String? note;

  /// The first tile: brand background, light text.
  final bool brand;

  /// The amount in the brand colour (Current Outstanding).
  final bool accent;
  final bool hidden;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brandColor = HomeColors.brand(context);
    final fg = brand ? Colors.white : HomeColors.textPrimary(context);
    final sub = brand ? Colors.white.withValues(alpha: 0.85) : HomeColors.textSecondary(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 18),
      decoration: BoxDecoration(
        color: brand ? null : HomeColors.card(context),
        gradient: brand
            ? LinearGradient(colors: [brandColor, Color.lerp(brandColor, Colors.black, 0.25)!])
            : null,
        borderRadius: BorderRadius.circular(16),
        border: brand ? null : Border.all(color: brandColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg))),
              IconButton(
                tooltip: hidden ? l10n.ccShowAmounts : l10n.ccHideAmounts,
                visualDensity: VisualDensity.compact,
                onPressed: onToggle,
                icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: brand ? Colors.white : brandColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: accent ? brandColor : fg),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note!, style: TextStyle(fontSize: 12.5, fontStyle: brand ? FontStyle.italic : null, color: sub)),
          ],
        ],
      ),
    );
  }
}

/// One card, as the design's row: who (ownership, status, masked number,
/// owner • expiry), OBDX's amounts, then Due On + Pay or "No Dues", and
/// OBDX's ⋮ menu. Stacked on a phone.
class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.card,
    required this.wide,
    required this.actions,
    required this.onAction,
    required this.onPay,
    required this.onCopy,
  });

  final CreditCard card;
  final bool wide;
  final List<(CreditCardAction, String)> actions;
  final ValueChanged<CreditCardAction> onAction;
  final VoidCallback onPay;
  final VoidCallback onCopy;

  String _status(AppLocalizations l10n) => switch (card.status) {
        CreditCardStatus.active => l10n.ccStatusActive,
        CreditCardStatus.inactive => l10n.ccStatusInactive,
        CreditCardStatus.hotlisted => l10n.ccStatusHotlisted,
        CreditCardStatus.cancelled => l10n.ccStatusCancelled,
        CreditCardStatus.blocked => l10n.ccStatusBlocked,
        CreditCardStatus.unknown => card.rawStatus ?? '',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final primary = HomeColors.textPrimary(context);
    final secondary = HomeColors.textSecondary(context);
    final brand = HomeColors.brand(context);
    final status = _status(l10n);

    final menu = PopupMenuButton<CreditCardAction>(
      tooltip: l10n.ccMoreActions,
      icon: Icon(Icons.more_vert_rounded, color: brand),
      onSelected: onAction,
      itemBuilder: (_) => [for (final (a, label) in actions) PopupMenuItem(value: a, child: Text(label))],
    );

    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                card.isPrimary ? l10n.ccPrimary : l10n.ccAddOn,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
              ),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (card.status == CreditCardStatus.active ? HomeColors.success(context) : HomeColors.error(context))
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: card.status == CreditCardStatus.active ? HomeColors.success(context) : HomeColors.error(context),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Flexible(
              child: Text(
                card.displayNumber,
                style: TextStyle(fontSize: 16, letterSpacing: 2, fontWeight: FontWeight.w600, color: primary),
              ),
            ),
            IconButton(
              tooltip: l10n.ccCopyNumber,
              visualDensity: VisualDensity.compact,
              onPressed: onCopy,
              icon: Icon(Icons.copy_rounded, size: 18, color: brand),
            ),
          ],
        ),
        Text(
          [card.ownerName, card.expiryLabel].whereType<String>().join('  •  '),
          style: TextStyle(fontSize: 14, color: secondary),
        ),
      ],
    );

    Widget value(String label, String text, {bool highlight = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12.5, color: secondary)),
            const SizedBox(height: 4),
            Text(
              text.isEmpty ? '—' : text,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: highlight ? brand : primary),
            ),
          ],
        );

    final amounts = <Widget>[
      value(l10n.ccAvailableCreditLimit, cardMoney(card.availableCredit)),
      value(l10n.ccCurrentOutstanding, cardMoney(card.currentOutstanding)),
      if (card.hasDues) ...[
        value(l10n.ccTotalDue, cardMoney(card.totalDue), highlight: true),
        value(l10n.ccMinimumDue, cardMoney(card.minimumDue), highlight: true),
      ],
    ];
    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var k = 0; k < amounts.length; k += 2) ...[
          if (k > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: amounts[k]),
              const SizedBox(width: 12),
              Expanded(child: k + 1 < amounts.length ? amounts[k + 1] : const SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );

    final dueText = card.hasDues && card.dueDate != null ? '${l10n.ccDueOn}  ${loc.formatShortDate(card.dueDate!)}' : null;
    final payOrNoDues = card.hasDues
        ? PayPrimaryButton(label: l10n.ccPay, onPressed: onPay)
        : Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: HomeColors.success(context).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(l10n.ccNoDues, style: TextStyle(fontWeight: FontWeight.w700, color: HomeColors.success(context))),
          );
    final due = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dueText != null) ...[
          Text(dueText, style: TextStyle(fontSize: 15, color: secondary)),
          const SizedBox(height: 10),
        ],
        payOrNoDues,
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 6, 18),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brand.withValues(alpha: 0.35)),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 4, child: who),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: grid),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: due),
                Align(alignment: Alignment.topCenter, child: menu),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: who), menu]),
                const SizedBox(height: 16),
                Padding(padding: const EdgeInsets.only(right: 14), child: grid),
                const SizedBox(height: 16),
                Padding(padding: const EdgeInsets.only(right: 14), child: due),
              ],
            ),
    );
  }
}
