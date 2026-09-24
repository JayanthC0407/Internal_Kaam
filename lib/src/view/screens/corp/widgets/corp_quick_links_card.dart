import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/models/corp/corp_quick_link.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// "Quick Links" panel — the corporate dashboard's shortcut grid.
///
/// The three payment shortcuts point at the payment flows this app already
/// has wired end-to-end against the same OBDX host (they are generic
/// payment journeys, not retail-specific screens). The bulk-file and
/// loan-request destinations are corporate-only modules that do not exist
/// in this app yet, so their tiles report themselves as unavailable instead
/// of dead-ending — replace their `routeName` here as each one lands.
class CorpQuickLinksCard extends StatelessWidget {
  const CorpQuickLinksCard({super.key, this.onUnavailable});

  /// Called with the tile label when a not-yet-built destination is tapped.
  final ValueChanged<String>? onUnavailable;

  static const List<CorpQuickLink> links = [
    CorpQuickLink(
      id: CorpQuickLinkId.adhocPayment,
      label: 'Adhoc\nPayment',
      routeName: RoutesConst.adhocPayeeTransferScreen,
    ),
    CorpQuickLink(
      id: CorpQuickLinkId.fundTransfer,
      label: 'Fund\nTransfer',
      routeName: RoutesConst.transferMoneyScreen,
    ),
    CorpQuickLink(
      id: CorpQuickLinkId.selfTransfer,
      label: 'Self\nTransfer',
      routeName: RoutesConst.ownAccountTransferScreen,
    ),
    CorpQuickLink(
      id: CorpQuickLinkId.fileUpload,
      label: 'File\nUpload',
    ),
    CorpQuickLink(
      id: CorpQuickLinkId.issueDraft,
      label: 'Issue\nDraft',
    ),
    CorpQuickLink(
      id: CorpQuickLinkId.uploadedFileInquiry,
      label: 'Uploaded\nFile Inquiry',
    ),
    CorpQuickLink(
      id: CorpQuickLinkId.loanRequest,
      label: 'Loan\nRequest',
    ),
  ];

  static IconData _iconFor(CorpQuickLinkId id) {
    switch (id) {
      case CorpQuickLinkId.adhocPayment:
        return Icons.credit_score_outlined;
      case CorpQuickLinkId.fundTransfer:
        return Icons.swap_horiz_rounded;
      case CorpQuickLinkId.selfTransfer:
        return Icons.account_balance_wallet_outlined;
      case CorpQuickLinkId.fileUpload:
        return Icons.upload_file_outlined;
      case CorpQuickLinkId.issueDraft:
        return Icons.edit_document;
      case CorpQuickLinkId.uploadedFileInquiry:
        return Icons.find_in_page_outlined;
      case CorpQuickLinkId.loanRequest:
        return Icons.request_quote_outlined;
    }
  }

  void _open(BuildContext context, CorpQuickLink link) {
    if (link.isAvailable) {
      Navigator.of(context).pushNamed(link.routeName!);
      return;
    }

    final label = link.label.replaceAll('\n', ' ');
    final handler = onUnavailable;
    if (handler != null) {
      handler(label);
      return;
    }
    // Self-sufficient fallback: the widget registry builds this card with
    // no arguments, so it has to be able to explain itself unaided.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is not available yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CorpCardHeader(title: 'Quick Links'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              // Four tiles per row on the design's width; two on a phone.
              final perRow = constraints.maxWidth >= 420 ? 4 : 2;
              const spacing = 12.0;
              final tileWidth =
                  (constraints.maxWidth - spacing * (perRow - 1)) / perRow;

              return Wrap(
                spacing: spacing,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  for (final link in links)
                    SizedBox(
                      width: tileWidth,
                      child: _QuickLinkTile(
                        icon: _iconFor(link.id),
                        label: link.label,
                        enabled: link.isAvailable,
                        onTap: () => _open(context, link),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One shortcut: an outlined icon square with the label beneath it, exactly
/// as the design lays them out (the label sits outside the box, not in it).
class _QuickLinkTile extends StatefulWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// `false` for a module that is not built yet — the tile stays tappable
  /// (so it can explain itself) but renders muted.
  final bool enabled;

  final VoidCallback onTap;

  @override
  State<_QuickLinkTile> createState() => _QuickLinkTileState();
}

class _QuickLinkTileState extends State<_QuickLinkTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    final iconColor = widget.enabled
        ? brand
        : CorpColors.navInactive(context);
    final borderColor = _hovered && widget.enabled
        ? brand
        : CorpColors.cardBorder(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 46,
                decoration: BoxDecoration(
                  color: CorpColors.tile(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  boxShadow: _hovered && widget.enabled
                      ? [
                          BoxShadow(
                            color: brand.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : const [],
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, size: 20, color: iconColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: widget.enabled
                  ? CorpColors.textPrimary(context)
                  : CorpColors.navInactive(context),
            ),
          ),
        ],
      ),
    );
  }
}
