import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';

/// OBDX status label for a card (nls credit-card-listing.js:28-32).
String creditCardStatusLabel(AppLocalizations l10n, CreditCard card) => switch (card.status) {
      CreditCardStatus.active => l10n.ccStatusActive,
      CreditCardStatus.inactive => l10n.ccStatusInactive,
      CreditCardStatus.hotlisted => l10n.ccStatusHotlisted,
      CreditCardStatus.cancelled => l10n.ccStatusCancelled,
      CreditCardStatus.blocked => l10n.ccStatusBlocked,
      CreditCardStatus.unknown => card.rawStatus ?? '',
    };

/// `MoneyFormat` for an optional amount; empty when absent.
String cardMoney(MoneyAmount? amount) {
  if (amount == null) return '';
  return MoneyFormat.format(amount.amount, currencyCode: amount.currency ?? '');
}

/// The gradient card shown on Credit Cards and on Home: masked number,
/// owner, expiry, OBDX status and Primary / Add-On, plus the Available
/// Credit Limit. Only real fields from `cards/credit` — nothing invented.
///
/// The eye in its corner hides every card detail — number (last 4
/// included), limit, expiry and name — like the account cards' eye.
class CreditCardFace extends StatefulWidget {
  const CreditCardFace({super.key, required this.card, this.index = 0, this.onTap, this.initiallyHidden = false});

  final CreditCard card;

  /// Picks one of the gradients so neighbouring cards differ.
  final int index;
  final VoidCallback? onTap;

  /// Home starts with the details hidden, as its account cards do.
  final bool initiallyHidden;

  @override
  State<CreditCardFace> createState() => _CreditCardFaceState();
}

class _CreditCardFaceState extends State<CreditCardFace> {
  late bool _hidden = widget.initiallyHidden;

  CreditCard get card => widget.card;
  int get index => widget.index;
  VoidCallback? get onTap => widget.onTap;

  /// Every letter and digit as a dot; spaces kept so it still reads as a
  /// card number.
  static String _dots(String text) => text.replaceAll(RegExp(r'[^\s]'), '•');

  static const _gradients = [
    [Color(0xFF111827), Color(0xFF374151)],
    [Color(0xFF0B4F8A), Color(0xFF1E88C7)],
    [Color(0xFF4A148C), Color(0xFF7B1FA2)],
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = _gradients[index % _gradients.length];
    final money = card.availableCredit;
    final available = _hidden && money != null
        ? '${(money.currency ?? '').isEmpty ? '' : '${money.currency} '}••••'
        : cardMoney(money);
    final white70 = Colors.white.withValues(alpha: 0.72);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.credit_card_rounded, color: white70, size: 22),
                  const SizedBox(width: 8),
                  // Shrinks first on a narrow card, leaving room for the eye.
                  Flexible(
                    child: Text(
                      card.isPrimary ? l10n.ccPrimary : l10n.ccAddOn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _hidden ? l10n.ccShowDetails : l10n.ccHideDetails,
                    // As tall as the status chip beside it, so the card
                    // keeps its height in the phone carousel.
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 22),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  ),
                  const SizedBox(width: 4),
                  if (creditCardStatusLabel(l10n, card).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        creditCardStatusLabel(l10n, card),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _hidden ? _dots(card.displayNumber) : card.displayNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 17, letterSpacing: 1.6, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.ccAvailableCreditLimit, style: TextStyle(color: white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          available.isEmpty ? '—' : available,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (card.expiryLabel != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(l10n.ccExpiryDate, style: TextStyle(color: white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(_hidden ? '••/••' : card.expiryLabel!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
              if ((card.ownerName ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _hidden ? _dots(card.ownerName!) : card.ownerName!.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: white70, fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
