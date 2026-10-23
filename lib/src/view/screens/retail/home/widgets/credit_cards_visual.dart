import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/providers/common/credit_card_providers.dart';
import 'package:ubci_bank/src/view/screens/common/credit_cards/widgets/credit_card_face.dart';

/// Home "Credit Card" tab: the customer's real credit cards from
/// `GET cards/credit?expand=ALL` (docs/obdx/features/credit-cards.md §3),
/// drawn with the same [CreditCardFace] as the Credit Cards screen.
/// Phones get a swipeable carousel with dots; wide layouts show the cards
/// side by side. [onOpen] (tapping a card) opens Credit Cards.
class CreditCardsVisual extends ConsumerWidget {
  const CreditCardsVisual({super.key, this.onOpen});

  final VoidCallback? onOpen;

  static const double _maxCardWidth = 360;
  static const double _gap = 16;

  // Below this width the cards become a carousel instead of a row.
  static const double _stackBreakpoint = 560;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cards = ref.watch(creditCardsProvider);
    return cards.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(child: Text(error is CardsLoadError && error.message != null ? error.message! : l10n.ccLoadFailed)),
            TextButton(onPressed: () => ref.invalidate(creditCardsProvider), child: Text(l10n.accountsRetry)),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(l10n.ccEmpty));
        }
        final faces = [
          for (final (i, card) in list.indexed) CreditCardFace(card: card, index: i, onTap: onOpen),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _stackBreakpoint) {
              return _CreditCardsCarousel(cards: faces);
            }
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [for (final f in faces) SizedBox(width: _maxCardWidth, child: f)],
            );
          },
        );
      },
    );
  }
}

/// Phone carousel of the cards: one card per page, dots below.
class _CreditCardsCarousel extends StatefulWidget {
  const _CreditCardsCarousel({required this.cards});

  final List<Widget> cards;

  @override
  State<_CreditCardsCarousel> createState() => _CreditCardsCarouselState();
}

class _CreditCardsCarouselState extends State<_CreditCardsCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Taller than the account cards: these carry more rows.
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: widget.cards[i],
            ),
          ),
        ),
        if (widget.cards.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.cards.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? brand : brand.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
