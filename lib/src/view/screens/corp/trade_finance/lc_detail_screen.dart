import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_view_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_initiate_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// Tabs of the View Letter of Credit screen, in design order.
enum LcViewTab {
  details('LC Details'),
  goods('Goods & Shipment'),
  documents('Documents'),
  instructions('Instructions'),
  amendments('Amendments'),
  bills('Bills'),
  charges('Charges'),
  banks('Banks');

  const LcViewTab(this.label);
  final String label;
}

/// View Letter of Credit: a summary card, then tabs.
///
/// APIs (`view_LC_details.har`, H4):
/// - Open: detail `GET letterofcredits/{id}` (#18), plus lookups such as
///   country, confirmation instruction and product (#24, #25, #27) and
///   branches (#26).
/// - Amendments: #49.
/// - Bills: bills #51 and shipping guarantees #53.
/// - Charges: #56, falling back to the charges inside the detail.
/// - Banks: `tradeBicCodes` (#35) and confirmation party (#34).
///
/// Each tab loads its data the first time it is opened.
class LcDetailScreen extends ConsumerStatefulWidget {
  const LcDetailScreen({super.key, required this.args});

  final LcDetailArgs args;

  @override
  ConsumerState<LcDetailScreen> createState() => _LcDetailScreenState();
}

class _LcDetailScreenState extends ConsumerState<LcDetailScreen> {
  LcViewTab _tab = LcViewTab.details;

  @override
  void initState() {
    super.initState();
    // Country names, confirmation labels and products for the tabs.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(corpLcLookupsProvider.notifier).ensureLoaded(),
    );
  }

  Future<void> _refresh(CorpLetterOfCredit? lc) async {
    if (lc != null) refreshLcViewTabs(ref, lc.id, widget.args.lcType);
    await ref.read(corpLcDetailProvider(widget.args.lcId).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final state = ref.watch(corpLcDetailProvider(args.lcId));
    final permissions = ref.watch(lcPermissionsProvider);
    final lc = state.lc;

    Widget body;
    if (state.isLoading && lc == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (lc == null) {
      body = LcEmptyState(
        icon: Icons.error_outline,
        title: 'Letter of credit unavailable',
        message: state.errorMessage,
        action: LcSecondaryButton(
          label: 'Try again',
          icon: Icons.refresh,
          onPressed: () => _refresh(null),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => _refresh(lc),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (state.errorMessage != null)
              LcMessageBanner(message: state.errorMessage!),
            _SummaryCard(lc: lc, lcType: args.lcType),
            const SizedBox(height: 8),
            _TabStrip(
              selected: _tab,
              onSelected: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                LcViewTab.details => _DetailsTab(lc: lc, lcType: args.lcType),
                LcViewTab.goods => _GoodsTab(lc: lc),
                LcViewTab.documents => _DocumentsTab(lc: lc),
                LcViewTab.instructions => _InstructionsTab(lc: lc),
                LcViewTab.amendments => _AmendmentsTab(lc: lc),
                LcViewTab.bills => _BillsTab(lc: lc, lcType: args.lcType),
                LcViewTab.charges => _ChargesTab(lc: lc),
                LcViewTab.banks => _BanksTab(lc: lc),
              },
            ),
          ],
        ),
      );
    }

    final isImport = args.lcType == LcType.importLc;
    final canAmend = lc != null &&
        isImport &&
        lc.isActive &&
        !lc.isExpired &&
        permissions.amend;
    final canCopy = lc != null && isImport && permissions.initiate;

    return LcScreenScaffold(
      title: lc?.id ?? args.lcId,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: state.isLoading ? null : () => _refresh(lc),
        ),
      ],
      body: body,
      // As on the OBDX "View Import Letter Of Credit" screen: Copy &
      // Initiate and Back. (Amend LC has its own menu entry.)
      bottomBar: LayoutBuilder(
        builder: (context, constraints) {
          final copy = canCopy
              ? LcPrimaryButton(
                  label: 'Copy & Initiate',
                  onPressed: () => Navigator.of(context).pushNamed(
                    CorpRoutesConst.lcInitiateScreen,
                    arguments: LcInitiateArgs(seed: lc),
                  ),
                )
              : null;
          final back = LcSecondaryButton(
            label: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          );
          // A phone: Copy & Initiate takes the room Back leaves, so the
          // main action is the big target. Wider: both at their natural
          // size, from the left, as on the web.
          final phone = constraints.maxWidth < 600;
          return Row(
            children: [
              if (copy != null) ...[
                phone ? Expanded(child: copy) : copy,
                const SizedBox(width: 12),
              ],
              back,
            ],
          );
        },
      ),
    );
  }
}

// ── Summary card ────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.lc, required this.lcType});

  final CorpLetterOfCredit lc;
  final LcType lcType;

  @override
  Widget build(BuildContext context) {
    final isImport = lcType == LcType.importLc;
    return LcSectionCard(
      title: lcType.label,
      trailing: Wrap(
        spacing: 6,
        children: [
          LcStatusChip(label: lc.statusLabel.toUpperCase()),
          if (lc.isExpired) const LcStatusChip(label: 'EXPIRED'),
        ],
      ),
      children: [
        Text(
          lcMoney(lc.amount),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: CorpColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          lcOrDash(lc.productName ?? lc.productId),
          style: TextStyle(
            fontSize: 14,
            color: CorpColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 16),
        LcInfoGrid(items: [
          ('Outstanding', lcMoney(lc.outstandingAmount)),
          ('Utilised', lcMoney(lc.utilisedAmount)),
          ('Date of expiry', TfDate.display(lc.expiryDate)),
          (isImport ? 'Beneficiary' : 'Applicant', lcOrDash(lc.counterPartyName)),
        ]),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Tab strip ───────────────────────────────────────────────────────────

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected, required this.onSelected});

  final LcViewTab selected;
  final ValueChanged<LcViewTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: CorpColors.divider(context))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in LcViewTab.values)
              InkWell(
                onTap: () => onSelected(tab),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tab == selected ? brand : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: tab == selected
                          ? brand
                          : CorpColors.textPrimary(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────

String _label(Iterable<TradeCode> codes, String? code) {
  if (code == null || code.isEmpty) return '—';
  for (final c in codes) {
    if (c.code == code) return c.label;
  }
  return code;
}

String _number(double? v) {
  if (v == null) return '—';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

String _text(dynamic value) => lcOrDash(TfJson.str(value));

MoneyAmount? _money(dynamic json) {
  final map = TfJson.map(json);
  if (map.isEmpty || map['amount'] == null) return null;
  return MoneyAmount.fromJson(map);
}

String _address(LcAddress address, LcLookups lookups) {
  final parts = [
    ...address.lines,
    if (address.country != null) lookups.countryName(address.country),
  ];
  return parts.isEmpty ? '—' : parts.join(', ');
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: CorpColors.textSecondary(context),
        ),
      ),
    );
  }
}

/// Loading / error / data for a tab provider.
class _AsyncBlock<T> extends StatelessWidget {
  const _AsyncBlock({
    required this.value,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LcMessageBanner(message: error.toString()),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LcSecondaryButton(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            ),
          ),
        ],
      ),
      data: builder,
    );
  }
}

// ── LC Details ──────────────────────────────────────────────────────────

class _DetailsTab extends ConsumerWidget {
  const _DetailsTab({required this.lc, required this.lcType});

  final CorpLetterOfCredit lc;
  final LcType lcType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final branches =
        ref.watch(corpLcBranchNamesProvider).valueOrNull ?? const {};
    final raw = lc.raw;
    final isImport = lcType == LcType.importLc;
    final branch = lc.branchId == null
        ? '—'
        : (branches[lc.branchId] == null
            ? lc.branchId!
            : '${branches[lc.branchId]} (${lc.branchId})');
    final party = [
      if (lc.partyName != null) lc.partyName!,
      if (lc.partyId.displayValue != null) lc.partyId.displayValue!,
    ].join(' • ');
    final parents = [
      for (final p in (raw['parentReferenceLCs'] is List
          ? raw['parentReferenceLCs'] as List
          : const []))
        if (TfJson.str(p) case final id?) id,
    ];
    final drafts = [
      for (final d in TfJson.maps(raw['billingDrafts'])) LcBillingDraft.fromJson(d),
    ].where((d) => d.tenor != null || d.amount != null || d.draweeBankCode != null).toList();
    final r = LcRevolvingDetails.fromJson(raw['revolvingDetails']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'LC details',
          children: [
            LcInfoGrid(items: [
              ('Party name and ID', party.isEmpty ? '—' : party),
              ('LC reference no.', lc.id),
              ('Product', lcOrDash(lc.productName ?? lc.productId)),
              ('LC amount', lcMoney(lc.amount)),
              ('Outstanding amount', lcMoney(lc.outstandingAmount)),
              ('Date of application', TfDate.display(lc.applicationDate)),
              ('Date of expiry', TfDate.display(lc.expiryDate)),
              ('Place of expiry', lcOrDash(lc.expiryPlace)),
              ('Customer reference no.', lcOrDash(lc.customerReferenceNo)),
              ('Branch', branch),
              (
                'Tolerance under / above',
                '${_number(lc.toleranceUnder ?? 0)}% / ${_number(lc.toleranceAbove ?? 0)}%',
              ),
              ('Total exposure', lcMoney(_money(raw['exposure']))),
              (
                'Documentary credit',
                lc.transferable ? 'Transferable' : 'Non Transferable',
              ),
              ('Irrevocable', lc.irrevocable ? 'Yes' : 'No'),
              ('Revolving', lc.revolving ? 'Yes' : 'No'),
              ('Credit available by', _label(LcAvailableBy.values, lc.transferableType)),
              ('Status', lc.statusLabel),
              if (lc.authStatus != null)
                ('Authorisation', lc.authStatus!.replaceAll('_', ' ')),
              if (lc.versionNo != null) ('Version', lc.versionNo!),
              if (TfJson.str(raw['additionalAmountCovered']) != null)
                ('Additional amount covered (39C)', _text(raw['additionalAmountCovered'])),
              if (TfJson.str(raw['paymentDetails']) != null)
                ('Negotiation / deferred payment (42P)', _text(raw['paymentDetails'])),
              if (parents.isNotEmpty) ('Linked LCs', parents.join(', ')),
            ]),
            const SizedBox(height: 4),
          ],
        ),
        LcSectionCard(
          title: isImport ? 'Beneficiary details' : 'Applicant details',
          children: [
            LcInfoGrid(items: [
              ('Name', lcOrDash(lc.counterPartyName)),
              ('Address', _address(lc.counterPartyAddress, lookups)),
            ]),
            const SizedBox(height: 4),
          ],
        ),
        if (lc.revolving)
          LcSectionCard(
            title: 'Revolving details',
            children: [
              LcInfoGrid(items: [
                ('Revolving type', r.type == 'TIME' ? 'Time' : 'Value'),
                (
                  'Repeat frequency',
                  '${r.frequency ?? 0} ${r.frequencyUnit == 'DAYS' ? 'days' : 'months'}',
                ),
                ('Auto-reinstatement', r.autoReinstatement ? 'Yes' : 'No'),
                ('Cumulative', r.cumulative ? 'Yes' : 'No'),
              ]),
              const SizedBox(height: 4),
            ],
          ),
        if (drafts.isNotEmpty)
          LcSectionCard(
            title: 'Drafts (42C)',
            children: [
              LcGridTable(
                columns: const [
                  LcGridColumn('Serial Number', flex: 2),
                  LcGridColumn('Tenor', flex: 2),
                  LcGridColumn('Credit Days From', flex: 3),
                  LcGridColumn('Drawee Bank', flex: 3),
                  LcGridColumn('Draft Amount', flex: 3),
                ],
                rows: [
                  for (var i = 0; i < drafts.length; i++)
                    [
                      LcCell('${i + 1}'),
                      LcCell(drafts[i].tenor?.toString() ?? '—'),
                      LcCell([
                        if (drafts[i].creditDays != null) '${drafts[i].creditDays}',
                        if (drafts[i].creditDaysType != null) drafts[i].creditDaysType!,
                      ].join(' · ')),
                      LcCell(drafts[i].draweeLabel),
                      LcCell(lcAmount(drafts[i].amount, lc.amount?.currency)),
                    ],
                ],
              ),
            ],
          ),
      ],
    );
  }
}

// ── Goods & Shipment ────────────────────────────────────────────────────

class _GoodsTab extends StatelessWidget {
  const _GoodsTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    final s = lc.shipment;
    final currency = lc.amount?.currency;
    final total = lc.goods.fold<double>(0, (sum, g) => sum + (g.total ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Shipment details',
          children: [
            LcInfoGrid(items: [
              ('Partial shipment (43P)', lcYesNo(s.partialAllowed)),
              ('Trans-shipment (43T)', lcYesNo(s.transshipmentAllowed)),
              ('Place of taking in charge / dispatch (44A)', lcOrDash(s.source)),
              ('Port of loading / airport of departure', lcOrDash(s.loadingPort)),
              ('Port of discharge / airport of destination (44F)', lcOrDash(s.dischargePort)),
              ('Place of final destination', lcOrDash(s.destination)),
              ('Latest shipment date (44C)', TfDate.display(s.latestShipmentDate)),
              ('Shipment period (44D)', s.period == null ? '—' : '${s.period} days'),
              (
                'Incoterms',
                (lc.incoterm == null || lc.incoterm!.code.isEmpty)
                    ? '—'
                    : '${lc.incoterm!.code} – ${lc.incoterm!.description ?? ''}',
              ),
            ]),
            const SizedBox(height: 4),
          ],
        ),
        LcSectionCard(
          title: 'Goods list',
          children: [
            LcGridTable(
              columns: const [
                LcGridColumn('Sr.No', flex: 1),
                LcGridColumn('Goods', flex: 3),
                LcGridColumn('Description', flex: 3),
                LcGridColumn('Quantity', flex: 2),
                LcGridColumn('Cost/Unit', flex: 2),
                LcGridColumn('Gross amount', flex: 3),
              ],
              emptyText: 'No goods recorded on this LC.',
              rows: [
                for (var i = 0; i < lc.goods.length; i++)
                  [
                    LcCell('${i + 1}'),
                    LcCell(lc.goods[i].code),
                    LcCell(lc.goods[i].description ?? '—', bold: true),
                    LcCell(_number(lc.goods[i].noOfUnits)),
                    LcCell(lcAmount(lc.goods[i].pricePerUnit, currency)),
                    LcCell(lcAmount(lc.goods[i].total, currency)),
                  ],
              ],
            ),
            if (lc.goods.isNotEmpty)
              _Muted('Total goods value: ${lcAmount(total, currency)}'),
          ],
        ),
      ],
    );
  }
}

// ── Documents ───────────────────────────────────────────────────────────

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    final documents = [
      for (final d in TfJson.maps(lc.raw['document']))
        if (LcDocument.fromJson(d) case final doc?) doc,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Documents required (46A)',
          children: [
            LcGridTable(
              columns: const [
                LcGridColumn('Name of Document', flex: 4),
                LcGridColumn('Original', flex: 2),
                LcGridColumn('Number of Copies', flex: 2),
                LcGridColumn('Clauses', flex: 4),
              ],
              emptyText: 'No documents are recorded on this LC.',
              rows: [
                for (final doc in documents)
                  [
                    LcCell(doc.name.isEmpty ? doc.id : doc.name, bold: true),
                    LcCell('${doc.originals}'),
                    LcCell('${doc.copies}'),
                    LcCell(
                      doc.clauses.isEmpty
                          ? '—'
                          : doc.clauses.map((c) => c.label).join('; '),
                    ),
                  ],
              ],
            ),
          ],
        ),
        LcSectionCard(
          title: 'Additional conditions (47A)',
          children: [
            LcGridTable(
              minWidth: 480,
              columns: const [
                LcGridColumn('Condition Code', flex: 3),
                LcGridColumn('Description', flex: 5),
              ],
              emptyText: 'No additional conditions.',
              rows: [
                for (final c in lc.additionalConditions)
                  [LcCell(c.code), LcCell(c.description ?? '—', bold: true)],
              ],
            ),
          ],
        ),
        LcSectionCard(
          title: 'Presentation (48)',
          children: [
            LcInfoGrid(items: [
              (
                'Documents to be presented within',
                lc.documentPresentationDays == null
                    ? '—'
                    : '${lc.documentPresentationDays} days',
              ),
            ]),
            const SizedBox(height: 4),
          ],
        ),
      ],
    );
  }
}

// ── Instructions ────────────────────────────────────────────────────────

class _InstructionsTab extends ConsumerWidget {
  const _InstructionsTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final parties =
        ref.watch(corpLcConfirmationPartiesProvider).valueOrNull ?? const [];
    final raw = lc.raw;
    return LcSectionCard(
      title: 'Instructions',
      children: [
        LcInfoGrid(items: [
          (
            'Confirmation instructions (49)',
            _label(lookups.confirmationOptions, lc.confirmationInstruction),
          ),
          (
            'Requested confirmation party',
            _label(parties, TfJson.str(raw['requestedConfirmationParty'])),
          ),
          ('Charges borne by', _label(LcChargesBorneBy.values, lc.chargesBorneBy)),
          ('Charges (71D)', _text(raw['chargesFromBeneficiary'])),
          ('Special payment conditions for beneficiary (49G)', _text(raw['paymentConditionsBene'])),
          ('Special payment conditions for bank only (49H)', _text(raw['paymentConditionsBank'])),
          ('Sender to receiver information (72Z)', _text(raw['senderReceiverInfo'])),
          ('Special instructions', _text(raw['instructionDescription'])),
          ('Remarks', lcOrDash(lc.remarks)),
        ]),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Amendments ──────────────────────────────────────────────────────────

class _AmendmentsTab extends ConsumerWidget {
  const _AmendmentsTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = corpLcAmendmentHistoryProvider(lc.id);
    return LcSectionCard(
      title: 'Amendments',
      children: [
        _AsyncBlock<List<CorpLcAmendment>>(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (items) => LcGridTable(
            columns: const [
              LcGridColumn('Amendment No.', flex: 2),
              LcGridColumn('Issue Date', flex: 3),
              LcGridColumn('New Expiry Date', flex: 3),
              LcGridColumn('New Amount', flex: 3),
              LcGridColumn('Status', flex: 3),
            ],
            emptyText: 'No amendments have been made to this LC.',
            rows: [
              for (final a in items)
                [
                  LcCell(a.id, bold: true),
                  LcCell(TfDate.display(
                    TfJson.date(a.raw['issueDate']) ?? a.amendmentDate,
                  )),
                  LcCell(TfDate.display(a.newExpiryDate)),
                  LcCell(lcMoney(a.newAmount)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LcStatusChip(
                      label: TfJson.str(a.raw['amendStatus']) ??
                          a.acceptanceStatus ??
                          '—',
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bills ───────────────────────────────────────────────────────────────

class _BillsTab extends ConsumerWidget {
  const _BillsTab({required this.lc, required this.lcType});

  final CorpLetterOfCredit lc;
  final LcType lcType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = corpLcBillsProvider((lc.id, lcType));
    final guarantees = corpLcShippingGuaranteesProvider(lc.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Bills',
          children: [
            _AsyncBlock<List<LcBill>>(
              value: ref.watch(bills),
              onRetry: () => ref.invalidate(bills),
              builder: (items) => LcGridTable(
                columns: const [
                  LcGridColumn('Bill Reference', flex: 3),
                  LcGridColumn('Bill Date', flex: 2),
                  LcGridColumn('Maturity Date', flex: 2),
                  LcGridColumn('Bill Amount', flex: 3),
                  LcGridColumn('Outstanding', flex: 3),
                  LcGridColumn('Status', flex: 2),
                ],
                emptyText: 'No bills have been drawn under this LC.',
                rows: [
                  for (final b in items)
                    [
                      LcCell(b.id, bold: true),
                      LcCell(TfDate.display(b.billDate)),
                      LcCell(TfDate.display(b.maturityDate)),
                      LcCell(lcMoney(b.amount)),
                      LcCell(lcMoney(b.outstandingAmount)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: LcStatusChip(label: b.status ?? '—'),
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
        LcSectionCard(
          title: 'Shipping guarantees',
          children: [
            _AsyncBlock<List<LcShippingGuarantee>>(
              value: ref.watch(guarantees),
              onRetry: () => ref.invalidate(guarantees),
              builder: (items) => LcGridTable(
                minWidth: 720,
                columns: const [
                  LcGridColumn('Guarantee No.', flex: 3),
                  LcGridColumn('Beneficiary', flex: 3),
                  LcGridColumn('Issue Date', flex: 2),
                  LcGridColumn('Expiry Date', flex: 2),
                  LcGridColumn('Amount', flex: 3),
                  LcGridColumn('Outstanding', flex: 3),
                  LcGridColumn('Status', flex: 2),
                ],
                emptyText: 'No shipping guarantees are linked to this LC.',
                rows: [
                  for (final g in items)
                    [
                      LcCell(g.id, bold: true),
                      LcCell(lcOrDash(g.counterPartyName)),
                      LcCell(TfDate.display(g.applicationDate)),
                      LcCell(TfDate.display(g.expiryDate)),
                      LcCell(lcMoney(g.amount)),
                      LcCell(lcMoney(g.outstandingAmount)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: LcStatusChip(label: g.status ?? '—'),
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Charges ─────────────────────────────────────────────────────────────

class _ChargesTab extends ConsumerWidget {
  const _ChargesTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = corpLcBookedChargesProvider(lc.id);
    final value = ref.watch(provider);

    Widget list(List<LcCharge> charges, {String? note}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note != null) _Muted(note),
            LcChargesList(charges: charges),
            const SizedBox(height: 12),
          ],
        );

    return LcSectionCard(
      title: 'Charges, commissions & taxes',
      children: [
        value.when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          // The charges endpoint failing (400 on pre-sales) still leaves
          // the charges the detail response carried.
          error: (error, _) => list(
            lc.charges,
            note: lc.charges.isEmpty
                ? error.toString()
                : 'Showing the charges recorded on the LC.',
          ),
          data: (charges) => list(charges.isEmpty ? lc.charges : charges),
        ),
      ],
    );
  }
}

// ── Banks ───────────────────────────────────────────────────────────────

class _BanksTab extends ConsumerWidget {
  const _BanksTab({required this.lc});

  final CorpLetterOfCredit lc;

  static const _roles = [
    ('Advising bank', 'advisingBankCode', 'advisingBankDetails'),
    ('Advise through bank', 'advisingThroughBankCode', 'advisingThroughBankDetails'),
    ('Confirming bank', 'confirmingBankCode', null),
    ('Reimbursing bank', 'reimbursingBankCode', null),
    ('Issuing bank', 'issuingBankCode', 'issuingBankDetails'),
    ('Credit available with', 'availableWith', null),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final parties =
        ref.watch(corpLcConfirmationPartiesProvider).valueOrNull ?? const [];
    final raw = lc.raw;
    final codes = <String>{
      for (final role in _roles)
        if (TfJson.str(raw[role.$2]) case final code?) code.toUpperCase(),
    }.toList()
      ..sort();
    final provider = corpLcBanksProvider(codes.join(','));
    final banks = codes.isEmpty
        ? const <String, TradeBank>{}
        : (ref.watch(provider).valueOrNull ?? const <String, TradeBank>{});
    final loading = codes.isNotEmpty && ref.watch(provider).isLoading;

    String describe(String code, dynamic details) {
      final bank = banks[code];
      final map = TfJson.map(details);
      final name = bank?.name ?? TfJson.str(map['name']);
      final address = bank != null && !bank.address.isEmpty
          ? bank.address
          : LcAddress.fromJson(map['branchAddress']);
      return [
        code,
        if (name != null) name,
        if (!address.isEmpty) _address(address, lookups),
      ].join('\n');
    }

    final items = <(String, String)>[
      for (final role in _roles)
        if (TfJson.str(raw[role.$2]) case final code?)
          (role.$1, describe(code.toUpperCase(), role.$3 == null ? null : raw[role.$3])),
    ];
    final confirmation = TfJson.map(raw['requestedConfirmationPartyDetails']);
    final partyCode = TfJson.str(raw['requestedConfirmationParty']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Banks',
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (items.isEmpty)
              const _Muted('No banks are recorded on this LC.')
            else
              LcInfoGrid(items: items),
            const SizedBox(height: 4),
          ],
        ),
        if (partyCode != null || TfJson.str(confirmation['name']) != null)
          LcSectionCard(
            title: 'Requested confirmation party',
            children: [
              LcInfoGrid(items: [
                ('Party', _label(parties, partyCode)),
                ('Bank', _text(confirmation['name'])),
                ('Customer no.', _text(confirmation['customerNo'])),
                (
                  'Address',
                  _address(LcAddress.fromJson(confirmation['branchAddress']), lookups),
                ),
              ]),
              const SizedBox(height: 4),
            ],
          ),
      ],
    );
  }
}
