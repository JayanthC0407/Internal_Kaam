import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_search.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/widgets/simple_option_picker_sheet.dart';

/// Building blocks shared by the Bank Guarantee screens. Colours come from
/// [CorpColors], spacing and shapes from the LC widgets, so guarantees
/// read as part of the same Trade Finance module.

/// A guarantee's status — the web list's badge colours (active green, on
/// hold amber, reversed red, closed / cancelled neutral).
class BgStatusChip extends StatelessWidget {
  const BgStatusChip({super.key, required this.guarantee});

  final CorpBankGuarantee guarantee;

  @override
  Widget build(BuildContext context) {
    final colors = CorpColors.of(context);
    final expired = guarantee.isExpired && guarantee.isActive;
    final tone = expired
        ? colors.error
        : switch (guarantee.status) {
            BgStatus.active => colors.success,
            BgStatus.hold || BgStatus.liquidated => colors.warning,
            BgStatus.reversed => colors.error,
            _ => colors.textSecondary,
          };
    return BgChip(label: expired ? 'Expired' : guarantee.statusLabel, tone: tone);
  }
}

/// A small tinted pill.
class BgChip extends StatelessWidget {
  const BgChip({super.key, required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
  }
}

/// "Amendment" / "Cancellation" — a cancellation is the weightier answer,
/// so it carries the error tone.
class BgAmendmentKindChip extends StatelessWidget {
  const BgAmendmentKindChip({super.key, required this.amendment});

  final CorpBgAmendment amendment;

  @override
  Widget build(BuildContext context) {
    final colors = CorpColors.of(context);
    return BgChip(
      label: amendment.kindLabel,
      tone: amendment.isCancellation ? colors.error : colors.info,
    );
  }
}

/// The one-line notes the web screens close with.
class BgInfoNote extends StatelessWidget {
  const BgInfoNote(this.text, {super.key});

  final String text;

  /// The web's wording, shown under every list with equivalent amounts.
  static const indicative =
      'Local currency equivalents are indicative; the actual amount may differ.';

  static const authorizedOnly =
      'Authorized and on-hold transactions are listed here. Others appear '
      'once approved — contact the bank for details.';

  @override
  Widget build(BuildContext context) {
    final muted = CorpColors.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// "All parties" or one party — shown only when the user has related
/// parties; otherwise their own party is the only choice and the selector
/// would add nothing.
class BgPartyField extends StatelessWidget {
  const BgPartyField({
    super.key,
    required this.parties,
    required this.selectedId,
    required this.onChanged,
    this.label = 'Party',
    this.allLabel = 'All parties',
  });

  final List<BgParty> parties;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String label;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final options = <_PartyOption>[
      const _PartyOption(null),
      for (final p in parties) _PartyOption(p),
    ];
    var current = options.first;
    for (final o in options) {
      if (o.party != null && o.party!.id.value == selectedId) current = o;
    }
    String labelOf(_PartyOption o) => o.party?.name ?? allLabel;
    return LcTapField(
      label: label,
      value: labelOf(current),
      onTap: () async {
        final picked = await SimpleOptionPickerSheet.show<_PartyOption>(
          context,
          title: label,
          options: options,
          labelBuilder: labelOf,
          subtitleBuilder: (o) => o.party?.id.displayValue ?? '',
          selected: current,
        );
        if (picked != null) onChanged(picked.party?.id.value);
      },
    );
  }
}

/// Wraps "all parties" (null) so the picker can return it.
class _PartyOption {
  const _PartyOption(this.party);

  final BgParty? party;

  @override
  bool operator ==(Object other) =>
      other is _PartyOption && other.party?.id.value == party?.id.value;

  @override
  int get hashCode => party?.id.value.hashCode ?? 0;
}

/// Client-side quick search over the loaded rows.
class BgQuickSearch extends StatelessWidget {
  const BgQuickSearch({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: (v) => onChanged(v.trim()),
      style: TextStyle(fontSize: 14, color: CorpColors.textPrimary(context)),
      decoration: lcInputDecoration(
        context,
        label: hint,
        suffix: const Icon(Icons.search_rounded),
      ),
    );
  }
}

/// Sums of [amounts] per currency — "Total equivalent outstanding".
class BgTotals extends StatelessWidget {
  const BgTotals({super.key, required this.label, required this.amounts});

  final String label;
  final Iterable<MoneyAmount?> amounts;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final m in amounts) {
      if (m == null) continue;
      final code = m.currency ?? '';
      totals[code] = (totals[code] ?? 0) + m.amount;
    }
    if (totals.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CorpColors.brand(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: CorpColors.textSecondary(context),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final e in totals.entries)
                Text(
                  lcAmount(e.value, e.key.isEmpty ? null : e.key),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// PDF / CSV download menu for a guarantee list.
class BgDownloadButton extends StatefulWidget {
  const BgDownloadButton({
    super.key,
    required this.enabled,
    required this.download,
  });

  final bool enabled;
  final Future<({List<int>? bytes, String fileName, String? error})> Function(
    TfListFormat format,
  ) download;

  @override
  State<BgDownloadButton> createState() => _BgDownloadButtonState();
}

class _BgDownloadButtonState extends State<BgDownloadButton> {
  bool _busy = false;

  Future<void> _run(TfListFormat format) async {
    setState(() => _busy = true);
    final result = await widget.download(format);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.bytes != null) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        await StatementFileSaver.saveStatement(
          bytes: result.bytes!,
          fileName: result.fileName,
          mimeType: format.media,
          sharePositionOrigin: box != null && box.hasSize
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Downloaded ${result.fileName}')),
        );
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not save the file.')),
        );
      }
    } else {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TfListFormat>(
      tooltip: 'Download list',
      enabled: !_busy && widget.enabled,
      onSelected: _run,
      itemBuilder: (_) => [
        for (final f in TfListFormat.values)
          PopupMenuItem(value: f, child: Text('Download as ${f.label}')),
      ],
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.download_rounded,
              color: CorpColors.textSecondary(context),
            ),
    );
  }
}

/// Header cell / body cell styles for the guarantee tables.
TextStyle bgHeadStyle(BuildContext context) => TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: CorpColors.textSecondary(context),
    );

TextStyle bgCellStyle(BuildContext context) =>
    TextStyle(fontSize: 13, color: CorpColors.textPrimary(context));

/// Turns a raw field name into a label: `beneContractReferenceNo` →
/// "Bene contract reference no".
String bgHumanize(String key) {
  final spaced = key
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .trim();
  if (spaced.isEmpty) return key;
  final lower = spaced.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}
