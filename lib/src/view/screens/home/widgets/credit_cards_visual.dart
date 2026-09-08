import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';

/// Two-card VISA visual — a black card and a blue card.
///
/// Side by side (with a consistent gap) on wide/web layouts; stacked one
/// below the other on narrow/mobile layouts, where squeezing two cards
/// side by side would make them too cramped to read.
///
/// Used both by the dashboard's "Cards" tab and by the Overview tab's
/// "Credit Card" inner tab, so both surfaces stay in sync.
class CreditCardsVisual extends StatelessWidget {
  const CreditCardsVisual({super.key});

  static const _demoCurrency = 'GBP';

  // Natural/max card width, and the gap between cards (or between rows
  // when stacked). Height is no longer fixed — the card sizes itself to
  // its content, which is what keeps the gap above "Available balance"
  // tight instead of stretching to fill a hard-coded height.
  static const double _maxCardWidth = 280.0;
  static const double _gap = 8.0;

  // Below this available width, cards stack vertically (full width) rather
  // than squeezing two narrow cards side by side.
  static const double _stackBreakpoint = 460.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget card({
      required Color c1,
      required Color c2,
      required String amount,
      required String tail,
      required String badge,
      required String expiry,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c1, c2],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -25,
              left: -15,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.04),
                ),
              ),
            ),

            Positioned(
              bottom: -40,
              right: -30,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.03),
                ),
              ),
            ),

            // mainAxisSize.min: the card sizes itself to fit its content,
            // instead of stretching to a hard-coded height. This is what
            // keeps the gap between the chip row and "Available balance"
            // tight and consistent, regardless of platform/font metrics.
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'VISA',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white24,
                        ),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6B446),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Icon(
                      Icons.contactless,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ],
                ),

                // Fixed gap instead of an Expanded flexible spacer — this
                // is the space you circled; it no longer grows to fill a
                // tall fixed card height.
                const SizedBox(height: 18),

                const Text(
                  'Available balance',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '•••• $tail',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'J. SMITH',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Exp $expiry',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Color(0xFF39D98A),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    final amounts = [
      MoneyFormat.format(4210.90, currencyCode: _demoCurrency),
      MoneyFormat.format(9060.20, currencyCode: _demoCurrency),
    ];

    final blackCard = card(
      c1: const Color(0xFF232833),
      c2: const Color(0xFF12161D),
      amount: amounts[0],
      tail: '2935',
      badge: 'DEBIT',
      expiry: '09/28',
    );
    final blueCard = card(
      c1: const Color(0xFF214D8D),
      c2: const Color(0xFF163765),
      amount: amounts[1],
      tail: '7341',
      badge: 'CREDIT',
      expiry: '03/27',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;

        // Narrow/mobile: stack full-width cards one below the other
        // instead of squeezing two side by side.
        if (available < _stackBreakpoint) {
          final cardWidth =
              available <= 0 ? _maxCardWidth : available.clamp(0.0, double.infinity);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: cardWidth, child: blackCard),
              const SizedBox(height: _gap),
              SizedBox(width: cardWidth, child: blueCard),
            ],
          );
        }

        // Wide/web: both cards at their natural width, side by side with
        // a consistent gap.
        final twoCardsWidth = (_maxCardWidth * 2) + _gap;
        final cardWidth = available >= twoCardsWidth
            ? _maxCardWidth
            : (available - _gap) / 2;

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: cardWidth, child: blackCard),
            const SizedBox(width: _gap),
            SizedBox(width: cardWidth, child: blueCard),
          ],
        );
      },
    );
  }
}