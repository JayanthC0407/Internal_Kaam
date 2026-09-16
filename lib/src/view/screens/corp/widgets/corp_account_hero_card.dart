import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';

/// The gradient account card at the top-left of the corporate dashboard.
///
/// Shows the party name with a "Primary Account" tag when the host flags
/// the account as default, the balance behind an eye toggle, and the
/// account number masked down to its last four digits — matching the
/// design. Every value comes from the account itself, so a carousel of
/// these never shows a portfolio total on an individual card.
class CorpAccountHeroCard extends StatelessWidget {
  const CorpAccountHeroCard({
    super.key,
    required this.account,
    required this.revealed,
    required this.onToggleVisibility,
    this.holderName,
    this.onTap,
  });

  final CorpAccount account;

  /// Whether the balance is currently revealed by the eye toggle.
  final bool revealed;
  final VoidCallback onToggleVisibility;

  /// Falls back to the account's own party name when omitted.
  final String? holderName;

  final VoidCallback? onTap;

  static const _brandLogomarkAsset = 'assets/images/figma/brand_logomark.svg';

  /// `•••• •••• •••• 1022` — every digit masked but the trailing four,
  /// chunked in fours like a card number.
  String _groupedMaskedNumber() {
    final raw = account.displayNumber.replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return '';
    final visibleLength = raw.length >= 4 ? 4 : raw.length;
    final combined = ('•' * (raw.length - visibleLength)) +
        raw.substring(raw.length - visibleLength);

    final groups = <String>[];
    for (var i = 0; i < combined.length; i += 4) {
      final end = (i + 4).clamp(0, combined.length);
      groups.add(combined.substring(i, end));
    }
    return groups.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final balance = account.displayBalance;
    final currency = (balance?.currency ?? account.currencyCode).trim();
    final balanceText = balance == null
        ? '—'
        : revealed
            ? CorpMoneyFormat.format(balance.amount, currencyCode: currency)
            : CorpMoneyFormat.masked(currency);

    final name = (holderName?.trim().isNotEmpty ?? false)
        ? holderName!.trim()
        : account.partyLabel;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.primary(context),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative brand mark, mostly clipped bottom-right.
          Positioned(
            right: -46,
            bottom: -56,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.5,
                child: SizedBox(
                  width: 170,
                  height: 186,
                  child: SvgPicture.asset(
                    _brandLogomarkAsset,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (account.isDefault) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        // TODO(l10n): wire through AppLocalizations once a
                        // translated key exists for every locale.
                        'Primary Account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: SvgPicture.asset(
                      _brandLogomarkAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      balanceText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
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
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _groupedMaskedNumber(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
      ),
    );
  }
}
