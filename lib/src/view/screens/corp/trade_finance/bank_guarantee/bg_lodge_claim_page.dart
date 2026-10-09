import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_search.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_bank_guarantee_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_filter_panel.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_list_page.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/tf_filter_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Initiate Lodge Claim / Initiate Lodge Claim-Islamic
/// (`lodge-claims[-islamic]`, BG #68 / #77).
///
/// Search form first, results after Search — the web form does not load
/// anything until searched, and every field is optional, so Search with an
/// empty form lists every guarantee the user can claim under
/// (`isClaimable=true`, BG #76). Picking one opens the claim form.
///
/// Date limits come from the bank's business date (BG #75), falling back
/// to today: issue dates up to it, expiry dates from it.
class BgLodgeClaimPage extends ConsumerStatefulWidget {
  const BgLodgeClaimPage({super.key, required this.category});

  final BgCategory category;

  static const double tableFrom = 900;

  @override
  ConsumerState<BgLodgeClaimPage> createState() => _BgLodgeClaimPageState();
}

class _BgLodgeClaimPageState extends ConsumerState<BgLodgeClaimPage> {
  BgListKey get _key =>
      (category: widget.category, mode: BgListMode.claimable);

  BgSearchNotifier get _notifier =>
      ref.read(corpBgSearchProvider(_key).notifier);

  // Form — seeded from the last search, so it survives opening a claim.
  late final BgSearch _initial = ref.read(corpBgSearchProvider(_key)).criteria;
  late String _number = _initial.guaranteeNumber ?? '';
  late String _applicant = _initial.applicantName ?? '';
  late String? _partyId = _initial.partyIds.firstOrNull;
  late String _currency = _initial.currency ?? '';
  late String _from = bgAmountText(_initial.fromAmount);
  late String _to = bgAmountText(_initial.toAmount);
  late DateTime? _issueFrom = _initial.issueFrom;
  late DateTime? _issueTo = _initial.issueTo;
  late DateTime? _expiryFrom = _initial.expiryFrom;
  late DateTime? _expiryTo = _initial.expiryTo;
  late BgUndertakingForm? _form = _initial.form;

  int _generation = 0;
  String? _formError;

  void _search() {
    final from = double.tryParse(_from.trim());
    final to = double.tryParse(_to.trim());
    final error = bgRangeError(
      from: from,
      to: to,
      issueFrom: _issueFrom,
      issueTo: _issueTo,
      expiryFrom: _expiryFrom,
      expiryTo: _expiryTo,
    );
    setState(() => _formError = error);
    if (error != null) return;
    FocusScope.of(context).unfocus();
    _notifier.search(
      BgSearch(
        guaranteeNumber: _number,
        applicantName: _applicant,
        currency: _currency,
        fromAmount: from,
        toAmount: to,
        issueFrom: _issueFrom,
        issueTo: _issueTo,
        expiryFrom: _expiryFrom,
        expiryTo: _expiryTo,
        form: _form,
        partyIds: _partyId == null ? const [] : [_partyId!],
      ),
    );
  }

  void _reset() {
    setState(() {
      _number = '';
      _applicant = '';
      _partyId = null;
      _currency = '';
      _from = '';
      _to = '';
      _issueFrom = null;
      _issueTo = null;
      _expiryFrom = null;
      _expiryTo = null;
      _form = null;
      _formError = null;
      _generation++;
    });
    _notifier.reset();
  }

  void _open(CorpBankGuarantee bg) {
    Navigator.of(context).pushNamed(
      CorpRoutesConst.bgClaimScreen,
      arguments: BgClaimArgs(guarantee: bg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpBgSearchProvider(_key));
    final lookups =
        ref.watch(bgLookupsProvider(true)).valueOrNull ?? BgLookups.empty;
    final category = widget.category;
    final businessDate = lookups.branchDate ?? _today();
    final wide = MediaQuery.sizeOf(context).width >= 600;

    Widget pair(Widget a, Widget b) => wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 16),
              Expanded(child: b),
            ],
          )
        : Column(children: [a, b]);

    Widget dateRange({
      required String label,
      required DateTime? from,
      required DateTime? to,
      required ValueChanged<DateTime?> onFrom,
      required ValueChanged<DateTime?> onTo,
      DateTime? first,
      DateTime? last,
    }) {
      Widget field(String l, DateTime? v, ValueChanged<DateTime?> on) =>
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LcDateField(
                    label: l,
                    value: v,
                    firstDate: first ?? DateTime(businessDate.year - 20),
                    lastDate: last ?? DateTime(businessDate.year + 20),
                    onChanged: on,
                  ),
                ),
                if (v != null)
                  IconButton(
                    tooltip: 'Clear $l',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => on(null),
                  ),
              ],
            ),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field('From', from, onFrom),
              const SizedBox(width: 12),
              field('To', to, onTo),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorpCardShell(
          child: KeyedSubtree(
            key: ValueKey(_generation),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CorpCardHeader(title: 'Find a ${category.lowerNoun} to claim under'),
                const SizedBox(height: 14),
                pair(
                  LcTextField(
                    label: '${category.noun} number',
                    initialValue: _number,
                    uppercase: true,
                    maxLength: 40,
                    onChanged: (v) => _number = v,
                  ),
                  lookups.hasRelatedParties
                      ? BgPartyField(
                          label: 'Beneficiary',
                          allLabel: 'All beneficiaries',
                          parties: lookups.parties,
                          selectedId: _partyId,
                          onChanged: (id) => setState(() => _partyId = id),
                        )
                      : LcTextField(
                          label: 'Applicant name',
                          initialValue: _applicant,
                          maxLength: 40,
                          onChanged: (v) => _applicant = v,
                        ),
                ),
                if (lookups.hasRelatedParties)
                  LcTextField(
                    label: 'Applicant name',
                    initialValue: _applicant,
                    maxLength: 40,
                    onChanged: (v) => _applicant = v,
                  ),
                const _FieldLabel('Undertaking amount'),
                BgAmountRange(
                  currencies: lookups.currencies,
                  currency: _currency,
                  from: _from,
                  to: _to,
                  onCurrency: (v) => setState(() => _currency = v),
                  onFrom: (v) => _from = v,
                  onTo: (v) => _to = v,
                ),
                pair(
                  dateRange(
                    label: 'Issue date range',
                    from: _issueFrom,
                    to: _issueTo,
                    onFrom: (d) => setState(() => _issueFrom = d),
                    onTo: (d) => setState(() => _issueTo = d),
                    last: businessDate,
                  ),
                  dateRange(
                    label: 'Expiry date range',
                    from: _expiryFrom,
                    to: _expiryTo,
                    onFrom: (d) => setState(() => _expiryFrom = d),
                    onTo: (d) => setState(() => _expiryTo = d),
                    first: businessDate,
                  ),
                ),
                TfChoiceGroup<BgUndertakingForm>(
                  label: 'Transaction type',
                  options: BgUndertakingForm.values,
                  labelOf: (v) => v.label(category),
                  selected: _form,
                  onChanged: (v) => setState(() => _form = v),
                ),
                if (_formError != null) LcMessageBanner(message: _formError!),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 140,
                      child: LcPrimaryButton(
                        label: 'Search',
                        icon: Icons.search_rounded,
                        loading: state.isLoading,
                        onPressed: _search,
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: LcSecondaryButton(label: 'Reset', onPressed: _reset),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (state.loaded || state.isLoading) ...[
          const SizedBox(height: 14),
          _Results(
            state: state,
            category: category,
            onOpen: _open,
            download: _notifier.download,
          ),
        ],
        const SizedBox(height: 4),
        if (state.loaded) const BgInfoNote(BgInfoNote.authorizedOnly),
        const BgInfoNote(BgInfoNote.indicative),
      ],
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: CorpColors.textSecondary(context),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.state,
    required this.category,
    required this.onOpen,
    required this.download,
  });

  final BgSearchState state;
  final BgCategory category;
  final ValueChanged<CorpBankGuarantee> onOpen;
  final Future<({List<int>? bytes, String fileName, String? error})> Function(
    TfListFormat format,
  ) download;

  @override
  Widget build(BuildContext context) {
    final noun = category.lowerNoun;
    final items = state.items;
    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpCardHeader(
            title: state.loaded
                ? '${items.length} $noun${items.length == 1 ? '' : 's'} '
                    'you can claim under'
                : 'Searching…',
            trailing: BgDownloadButton(
              enabled: items.isNotEmpty,
              download: download,
            ),
          ),
          const SizedBox(height: 8),
          if (state.errorMessage != null)
            LcMessageBanner(message: state.errorMessage!),
          if (state.isLoading && items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty && state.errorMessage == null)
            LcEmptyState(
              icon: Icons.request_quote_outlined,
              title: 'No ${noun}s to claim under',
              message: 'Only active ${noun}s issued in your favour can be '
                  'claimed. Widen the search or reset it.',
            )
          else if (items.isNotEmpty) ...[
            if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
            Text(
              'Choose the $noun to lodge a claim under.',
              style: TextStyle(
                fontSize: 12.5,
                color: CorpColors.textSecondary(context),
              ),
            ),
            LayoutBuilder(
              builder: (context, c) => c.maxWidth >= BgLodgeClaimPage.tableFrom
                  ? _ClaimTable(items: items, onOpen: onOpen)
                  : Column(
                      children: [
                        for (final bg in items)
                          BgGuaranteeCard(
                            bg: bg,
                            showClaims: true,
                            onTap: () => onOpen(bg),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimTable extends StatelessWidget {
  const _ClaimTable({required this.items, required this.onOpen});

  final List<CorpBankGuarantee> items;
  final ValueChanged<CorpBankGuarantee> onOpen;

  static const _columns = <(String, double, Alignment)>[
    ('Number', 1.4, Alignment.centerLeft),
    ('Applicant', 1.4, Alignment.centerLeft),
    ('Beneficiary', 1.3, Alignment.centerLeft),
    ('Issue date', 1.0, Alignment.centerLeft),
    ('Expiry date', 1.0, Alignment.centerLeft),
    ('Status', 0.9, Alignment.center),
    ('Undertaking', 1.3, Alignment.centerRight),
    ('Outstanding', 1.3, Alignment.centerRight),
    ('Claimed', 1.2, Alignment.centerRight),
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
              tap(bg, pad(Text(lcOrDash(bg.beneficiaryName), style: cell), 2)),
              tap(bg, pad(Text(TfDate.display(bg.issueDate), style: cell), 3)),
              tap(bg, pad(Text(TfDate.display(bg.expiryDate), style: cell), 4)),
              tap(bg, pad(BgStatusChip(guarantee: bg), 5)),
              tap(bg, pad(Text(lcMoney(bg.undertakingAmount), style: cell), 6)),
              tap(bg, pad(Text(lcMoney(bg.outstandingAmount), style: cell), 7)),
              tap(bg, pad(Text(lcMoney(bg.claimedAmount), style: cell), 8)),
              tap(bg, pad(Text(bg.formLabel, style: cell), 9)),
            ],
          ),
      ],
    );
  }
}
