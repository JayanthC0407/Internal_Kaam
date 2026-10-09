import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_bank_guarantee_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_filter_panel.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// View Bank Guarantee/Stand By LC and View Bank Kafalah/Stand By LC
/// (`inward-guarantee-list[-islamic]`, BG #37 / #46): guarantees issued in
/// the user's favour.
///
/// Party selector, quick search, filter panel, PDF/CSV download and the
/// total equivalent outstanding, as the web screen has them. Results are a
/// table where there is room and cards on a phone.
class BgListPage extends ConsumerStatefulWidget {
  const BgListPage({super.key, required this.category});

  final BgCategory category;

  static const double tableFrom = 860;

  @override
  ConsumerState<BgListPage> createState() => _BgListPageState();
}

class _BgListPageState extends ConsumerState<BgListPage> {
  String _query = '';

  BgListKey get _key => (category: widget.category, mode: BgListMode.view);

  BgSearchNotifier get _notifier => ref.read(corpBgSearchProvider(_key).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.ensureLoaded();
    });
  }

  Future<void> _openFilters(BgSearch current, BgLookups lookups) async {
    final picked = await BgFilterPanel.show(
      context,
      initial: current,
      category: widget.category,
      currencies: lookups.currencies,
    );
    if (picked != null && mounted) _notifier.search(picked);
  }

  void _open(CorpBankGuarantee bg) {
    Navigator.of(context).pushNamed(
      CorpRoutesConst.bgDetailScreen,
      arguments: BgDetailArgs(seed: bg),
    );
  }

  List<CorpBankGuarantee> _visible(List<CorpBankGuarantee> items) {
    final q = _query.toLowerCase();
    if (q.isEmpty) return items;
    return [
      for (final bg in items)
        if ([bg.id, bg.applicantName, bg.statusLabel, bg.issuingBank]
            .any((v) => v?.toLowerCase().contains(q) ?? false))
          bg,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpBgSearchProvider(_key));
    final lookups =
        ref.watch(bgLookupsProvider(false)).valueOrNull ?? BgLookups.empty;
    final criteria = state.criteria;
    final noun = widget.category.lowerNoun;
    final items = _visible(state.items);
    final count = criteria.filterCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorpCardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpCardHeader(
                title: state.loaded
                    ? '${state.items.length} inward $noun'
                        '${state.items.length == 1 ? '' : 's'}'
                    : 'Recently issued inward ${noun}s',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      backgroundColor: CorpColors.brand(context),
                      child: IconButton(
                        tooltip: 'Filter',
                        icon: const Icon(Icons.tune_rounded),
                        color: CorpColors.textSecondary(context),
                        onPressed: () => _openFilters(criteria, lookups),
                      ),
                    ),
                    BgDownloadButton(
                      enabled: state.items.isNotEmpty,
                      download: _notifier.download,
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded),
                      color: CorpColors.textSecondary(context),
                      onPressed: _notifier.refresh,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SearchRow(
                lookups: lookups,
                partyId: criteria.partyIds.firstOrNull,
                onParty: (id) => _notifier.search(
                  criteria.copyWith(partyIds: id == null ? const [] : [id]),
                ),
                onQuery: (q) => setState(() => _query = q),
                noun: noun,
              ),
              if (count > 0) ...[
                const SizedBox(height: 4),
                BgActiveFilters(
                  criteria: criteria,
                  category: widget.category,
                  onRemove: (f) => _notifier.search(criteria.without(f)),
                  onClearAll: () => _notifier.search(
                    BgSearch(partyIds: criteria.partyIds),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (state.errorMessage != null)
                LcMessageBanner(message: state.errorMessage!),
              if (state.isLoading && state.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty && state.errorMessage == null)
                LcEmptyState(
                  icon: Icons.verified_user_outlined,
                  title: _query.isNotEmpty
                      ? 'No results for "$_query"'
                      : count > 0
                          ? 'No ${noun}s match these filters'
                          : 'No inward ${noun}s yet',
                  message: _query.isNotEmpty || count > 0
                      ? null
                      : '${widget.category.noun}s and standby LCs issued in '
                          'your favour appear here.',
                )
              else if (items.isNotEmpty) ...[
                if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
                LayoutBuilder(
                  builder: (context, c) => c.maxWidth >= BgListPage.tableFrom
                      ? _Table(items: items, onOpen: _open)
                      : _Cards(items: items, onOpen: _open),
                ),
                BgTotals(
                  label: 'Total equivalent outstanding',
                  amounts: [
                    for (final bg in items) bg.equivalentOutstandingAmount,
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (state.loaded) const BgInfoNote(BgInfoNote.authorizedOnly),
        const BgInfoNote(BgInfoNote.indicative),
      ],
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.lookups,
    required this.partyId,
    required this.onParty,
    required this.onQuery,
    required this.noun,
  });

  final BgLookups lookups;
  final String? partyId;
  final ValueChanged<String?> onParty;
  final ValueChanged<String> onQuery;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final search = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BgQuickSearch(
        hint: 'Search by $noun number, applicant or status',
        onChanged: onQuery,
      ),
    );
    if (!lookups.hasRelatedParties) return search;
    final party = BgPartyField(
      parties: lookups.parties,
      selectedId: partyId,
      onChanged: onParty,
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 600
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: party),
                const SizedBox(width: 12),
                Expanded(child: search),
              ],
            )
          : Column(children: [party, search]),
    );
  }
}

/// The filters in force, each removable.
class BgActiveFilters extends StatelessWidget {
  const BgActiveFilters({
    super.key,
    required this.criteria,
    required this.category,
    required this.onRemove,
    required this.onClearAll,
  });

  final BgSearch criteria;
  final BgCategory category;
  final ValueChanged<BgFilter> onRemove;
  final VoidCallback onClearAll;

  String _label(BgFilter f) {
    String range(String name, Object? from, Object? to, [String? unit]) {
      String show(Object? v) => v is DateTime
          ? TfDate.display(v)
          : v is double
              ? bgAmountText(v)
              : '$v';
      final prefix = unit == null || unit.isEmpty ? name : '$name ($unit)';
      if (from != null && to != null) return '$prefix ${show(from)}–${show(to)}';
      if (from != null) return '$prefix from ${show(from)}';
      if (to != null) return '$prefix up to ${show(to)}';
      return prefix;
    }

    return switch (f) {
      BgFilter.guaranteeNumber => 'No. ${criteria.guaranteeNumber!.trim()}',
      BgFilter.applicant => 'Applicant: ${criteria.applicantName!.trim()}',
      BgFilter.issuingBank => 'Bank: ${criteria.issuingBank!.trim()}',
      BgFilter.issuingBankRefNo => 'Bank ref: ${criteria.issuingBankRefNo!.trim()}',
      BgFilter.status => 'Status: ${criteria.status!.label}',
      BgFilter.amount => range(
          'Amount',
          criteria.fromAmount,
          criteria.toAmount,
          criteria.currency?.trim().toUpperCase(),
        ),
      BgFilter.issueDate =>
        range('Issued', criteria.issueFrom, criteria.issueTo),
      BgFilter.expiryDate =>
        range('Expiry', criteria.expiryFrom, criteria.expiryTo),
      BgFilter.form => criteria.form!.label(category),
      BgFilter.parties => 'Party',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final f in criteria.activeFilters)
          if (f != BgFilter.parties)
            InputChip(
              label: Text(_label(f), style: const TextStyle(fontSize: 12)),
              onDeleted: () => onRemove(f),
              deleteButtonTooltipMessage: 'Remove filter',
              visualDensity: VisualDensity.compact,
            ),
        TextButton(onPressed: onClearAll, child: const Text('Clear all')),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.items, required this.onOpen});

  final List<CorpBankGuarantee> items;
  final ValueChanged<CorpBankGuarantee> onOpen;

  static const _columns = <(String, double, Alignment)>[
    ('Number', 1.4, Alignment.centerLeft),
    ('Applicant', 1.4, Alignment.centerLeft),
    ('Issuing bank', 1.3, Alignment.centerLeft),
    ('Issue date', 1.0, Alignment.centerLeft),
    ('Date of expiry', 1.0, Alignment.centerLeft),
    ('Status', 0.9, Alignment.center),
    ('Undertaking', 1.3, Alignment.centerRight),
    ('Outstanding', 1.3, Alignment.centerRight),
    ('Type', 0.9, Alignment.centerLeft),
  ];

  @override
  Widget build(BuildContext context) {
    final head = bgHeadStyle(context);
    final cell = bgCellStyle(context);
    final divider = BoxDecoration(
      border: Border(bottom: BorderSide(color: CorpColors.divider(context))),
    );
    Widget pad(Widget child, int i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Align(alignment: _columns[i].$3, child: child),
        );
    Widget tap(CorpBankGuarantee bg, Widget child) =>
        TableRowInkWell(onTap: () => onOpen(bg), child: child);

    return Table(
      columnWidths: {
        for (var i = 0; i < _columns.length; i++)
          i: FlexColumnWidth(_columns[i].$2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: divider,
          children: [
            for (var i = 0; i < _columns.length; i++)
              pad(Text(_columns[i].$1, style: head), i),
          ],
        ),
        for (final bg in items)
          TableRow(
            decoration: divider,
            children: [
              tap(
                bg,
                pad(
                  Text(
                    bg.id,
                    style: cell.copyWith(
                      fontWeight: FontWeight.w700,
                      color: CorpColors.brand(context),
                    ),
                  ),
                  0,
                ),
              ),
              tap(bg, pad(Text(lcOrDash(bg.applicantName), style: cell), 1)),
              tap(bg, pad(Text(lcOrDash(bg.issuingBank), style: cell), 2)),
              tap(bg, pad(Text(TfDate.display(bg.issueDate), style: cell), 3)),
              tap(bg, pad(Text(TfDate.display(bg.expiryDate), style: cell), 4)),
              tap(bg, pad(BgStatusChip(guarantee: bg), 5)),
              tap(bg, pad(Text(lcMoney(bg.undertakingAmount), style: cell), 6)),
              tap(bg, pad(Text(lcMoney(bg.outstandingAmount), style: cell), 7)),
              tap(bg, pad(Text(bg.formLabel, style: cell), 8)),
            ],
          ),
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.items, required this.onOpen});

  final List<CorpBankGuarantee> items;
  final ValueChanged<CorpBankGuarantee> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (final bg in items) BgGuaranteeCard(bg: bg, onTap: () => onOpen(bg))],
    );
  }
}

/// One guarantee as a list row on a phone — shared with Lodge Claim.
class BgGuaranteeCard extends StatelessWidget {
  const BgGuaranteeCard({
    super.key,
    required this.bg,
    required this.onTap,
    this.showClaims = false,
  });

  final CorpBankGuarantee bg;
  final VoidCallback onTap;
  final bool showClaims;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 12,
      color: CorpColors.textSecondary(context),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: CorpColors.divider(context)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bg.id,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CorpColors.brand(context),
                    ),
                  ),
                ),
                BgStatusChip(guarantee: bg),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Applicant: ${lcOrDash(bg.applicantName)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
            if (bg.issuingBank != null)
              Text(
                'Issued by ${bg.issuingBank}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LcInfoItem(
                    label: 'Undertaking',
                    value: lcMoney(bg.undertakingAmount),
                  ),
                ),
                Expanded(
                  child: LcInfoItem(
                    label: showClaims ? 'Claimed' : 'Outstanding',
                    value: lcMoney(
                      showClaims ? bg.claimedAmount : bg.outstandingAmount,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${bg.formLabel} · Issued ${TfDate.display(bg.issueDate)} · '
              'Expires ${TfDate.display(bg.expiryDate)}',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}
