import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/cards/debit_card_models.dart';
import 'package:ubci_bank/src/view/providers/common/credit_card_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Debit Cards — OBDX `demand-deposits/debit-card-list`, in the designer's
/// layout (UI designs 2, 2026-10-27): the first card as a card image, then
/// search and Filter (the design's, on the device — OBDX has neither) and
/// a row per card with OBDX's tile fields: card type, number, holder,
/// expiry, status and the linked Account Number. OBDX sends no balance,
/// so the mock's balances are not shown. The ⋮ menu and the
/// "Block/Unblock Card" button follow OBDX's status rule; every action is
/// a write flow, not built yet. Evidence: docs/obdx/features/debit-cards.md.
class DebitCardsScreen extends ConsumerStatefulWidget {
  const DebitCardsScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<DebitCardsScreen> createState() => _DebitCardsScreenState();
}

String debitCardActionLabel(AppLocalizations l10n, DebitCardAction a) => switch (a) {
      DebitCardAction.limits => l10n.dcLimits,
      DebitCardAction.blockUnblock => l10n.ccBlockUnblock,
      DebitCardAction.requestPin => l10n.ccRequestPin,
      DebitCardAction.upgradeCard => l10n.dcUpgradeCard,
      DebitCardAction.resetPin => l10n.ccResetPin,
      DebitCardAction.reissueCard => l10n.dcReissueCard,
    };

String debitCardStatusLabel(AppLocalizations l10n, DebitCardStatus s) => switch (s) {
      DebitCardStatus.active => l10n.dcStatusActive,
      DebitCardStatus.blocked => l10n.dcStatusBlocked,
      DebitCardStatus.cancelled => l10n.dcStatusCancelled,
    };

class _DebitCardsScreenState extends ConsumerState<DebitCardsScreen> {
  DebitCardFilter _filter = const DebitCardFilter();

  void _comingSoon(DebitCardAction a) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${debitCardActionLabel(l10n, a)} · ${l10n.featureComingSoon}')));
  }

  /// The design's Filter: Status and Account Number, applied as they change.
  Future<void> _openFilter(List<DebitCard> cards) async {
    final l10n = AppLocalizations.of(context);
    final accounts = <String, String>{
      for (final c in cards)
        if (c.accountId != null) c.accountId!: c.accountDisplay ?? c.accountId!,
    };
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          void update(DebitCardFilter f) {
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
                  PayFieldLabel(l10n.dcStatus),
                  PayChoiceChips<DebitCardStatus?>(
                    options: [
                      (null, l10n.casaFilterAll),
                      for (final s in DebitCardStatus.values) (s, debitCardStatusLabel(l10n, s)),
                    ],
                    selected: f.status,
                    onChanged: (v) => update(f.copyWith(status: () => v)),
                  ),
                  if (accounts.length > 1) ...[
                    const SizedBox(height: 16),
                    PayBoxedPicker(
                      label: l10n.dcAccountNumber,
                      value: f.accountId == null ? l10n.dcAllAccounts : accounts[f.accountId],
                      onTap: () async {
                        // '' = all accounts.
                        final picked = await showPayPicker<String>(
                          sheet,
                          title: l10n.dcAccountNumber,
                          selected: f.accountId ?? '',
                          options: [
                            PayOption(value: '', title: l10n.dcAllAccounts),
                            for (final e in accounts.entries) PayOption(value: e.key, title: e.value),
                          ],
                        );
                        if (picked == null) return;
                        update(f.copyWith(accountId: () => picked.isEmpty ? null : picked));
                      },
                    ),
                  ],
                  if (f.isActive) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => update(DebitCardFilter(query: f.query)),
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
    final l10n = AppLocalizations.of(context);
    final cards = ref.watch(debitCardsProvider);
    return PayMenuPage(
      title: l10n.dcTitle,
      subtitle: l10n.dcSubtitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) => cards.when(
        loading: () => const PayCard(
          child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        ),
        error: (error, _) => PayErrorRetry(
          message: error is CardsLoadError && error.message != null ? error.message! : l10n.dcLoadFailed,
          onRetry: () => ref.invalidate(debitCardsProvider),
        ),
        data: (list) {
          if (list.isEmpty) return PayCard(child: PayMuted(l10n.dcEmpty));
          final shown = list.where(_filter.matches).toList();
          final title = Text(
            '${l10n.dcTitle} (${shown.length})',
            style: TextStyle(fontSize: wide ? 24 : 20, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
          );
          final search = TextField(
            onChanged: (v) => setState(() => _filter = _filter.copyWith(query: v)),
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
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _CardImage(card: list.first),
                ),
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
                PayCard(child: PayMuted(l10n.dcNoMatch))
              else
                for (final (i, card) in shown.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _CardRow(
                    card: card,
                    wide: wide,
                    onAction: _comingSoon,
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: card.displayNumber));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text(l10n.ccNumberCopied)));
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

/// The design's card image, for the first card: holder, card type and the
/// masked number. No balance (OBDX sends none for debit cards).
class _CardImage extends StatelessWidget {
  const _CardImage({required this.card});

  final DebitCard card;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return AspectRatio(
      aspectRatio: 1.7,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [brand, Color.lerp(brand, Colors.black, 0.3)!],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.holderName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
                const Icon(Icons.contactless_rounded, color: Colors.white70),
              ],
            ),
            if (card.cardType != null)
              Text(
                card.cardType!,
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white.withValues(alpha: 0.85)),
              ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '****  ****  ****  ${card.lastDigits}',
                style: const TextStyle(fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
            if (card.expiryLabel != null) ...[
              const SizedBox(height: 6),
              Text(card.expiryLabel!, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
            ],
          ],
        ),
      ),
    );
  }
}

/// One card: who (card type, status, number, holder • expiry), OBDX's
/// Account Number, the "Block/Unblock Card" button where OBDX offers it,
/// and OBDX's ⋮ menu. Stacked on a phone.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.card, required this.wide, required this.onAction, required this.onCopy});

  final DebitCard card;
  final bool wide;
  final ValueChanged<DebitCardAction> onAction;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = HomeColors.textPrimary(context);
    final secondary = HomeColors.textSecondary(context);
    final brand = HomeColors.brand(context);
    final actions = debitCardMenu(card);
    final active = card.status == DebitCardStatus.active;
    final statusColor = active ? HomeColors.success(context) : HomeColors.error(context);

    final menu = PopupMenuButton<DebitCardAction>(
      tooltip: l10n.ccMoreActions,
      icon: Icon(Icons.more_vert_rounded, color: brand),
      onSelected: onAction,
      itemBuilder: (_) => [
        for (final a in actions) PopupMenuItem(value: a, child: Text(debitCardActionLabel(l10n, a))),
      ],
    );

    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                card.cardType ?? l10n.dcTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
              child: Text(
                debitCardStatusLabel(l10n, card.status),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
              ),
            ),
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
          [card.holderName, card.expiryLabel].whereType<String>().join('  •  '),
          style: TextStyle(fontSize: 14, color: secondary),
        ),
      ],
    );

    final account = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.dcAccountNumber, style: TextStyle(fontSize: 12.5, color: secondary)),
        const SizedBox(height: 4),
        Text(card.accountDisplay ?? '—', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary)),
      ],
    );

    // OBDX offers Block/Unblock Card for ACTIVE and BLOCKED cards.
    final blockButton = actions.contains(DebitCardAction.blockUnblock)
        ? FilledButton(
            onPressed: () => onAction(DebitCardAction.blockUnblock),
            style: FilledButton.styleFrom(
              backgroundColor: HomeColors.error(context),
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.ccBlockUnblock),
          )
        : null;

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
                Expanded(flex: 4, child: account),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: blockButton ?? const SizedBox.shrink()),
                Align(alignment: Alignment.topCenter, child: menu),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: who), menu]),
                const SizedBox(height: 14),
                Padding(padding: const EdgeInsets.only(right: 14), child: account),
                if (blockButton != null) ...[
                  const SizedBox(height: 14),
                  Padding(padding: const EdgeInsets.only(right: 14), child: blockButton),
                ],
              ],
            ),
    );
  }
}
