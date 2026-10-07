import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_bill.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_export_bill_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// View Export Bill — one bill (manual ch. 14.1–14.5): General,
/// Discrepancies, Charges, SWIFT Messages and Advices, all from
/// `GET …/bills/{billReferenceNo}`.
class ExportBillDetailScreen extends ConsumerStatefulWidget {
  const ExportBillDetailScreen({super.key, required this.args});

  final ExportBillArgs args;

  static const tabs = [
    'General',
    'Discrepancies',
    'Charges',
    'SWIFT Messages',
    'Advices',
  ];

  @override
  ConsumerState<ExportBillDetailScreen> createState() =>
      _ExportBillDetailScreenState();
}

class _ExportBillDetailScreenState
    extends ConsumerState<ExportBillDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(corpLcLookupsProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.args.billId;
    final value = ref.watch(exportBillDetailProvider(id));
    void refresh() => ref.invalidate(exportBillDetailProvider(id));

    final Widget body;
    final bill = value.valueOrNull;
    if (bill == null && value.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (bill == null) {
      body = LcEmptyState(
        icon: Icons.error_outline,
        title: 'Bill unavailable',
        message: '${value.error ?? ''}',
        action: LcSecondaryButton(
          label: 'Try again',
          icon: Icons.refresh,
          onPressed: refresh,
        ),
      );
    } else {
      body = DefaultTabController(
        length: ExportBillDetailScreen.tabs.length,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: _Summary(bill: bill),
              ),
            ),
            // Hands the pinned tab bar's height to the tabs (see
            // [_TabList]), so their content starts below it rather than
            // under it once the page has scrolled.
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarHeader(
                  color: CorpColors.bg(context),
                  // Natural widths: side by side on a desktop, scrolling on
                  // a phone.
                  tabBar: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: CorpColors.brand(context),
                    unselectedLabelColor: CorpColors.textSecondary(context),
                    indicatorColor: CorpColors.brand(context),
                    labelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: [
                      for (final t in ExportBillDetailScreen.tabs) Tab(text: t),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _TabList(child: _GeneralTab(bill: bill)),
              _TabList(child: _DiscrepanciesTab(bill: bill)),
              _TabList(
                child: LcSectionCard(
                  title: 'Charges, commission & taxes',
                  children: [LcChargesList(charges: bill.charges)],
                ),
              ),
              _TabList(
                child: _MessagesTab(
                  title: 'SWIFT messages',
                  messages: bill.swiftMessages,
                  empty: 'No SWIFT messages on this bill.',
                  swift: true,
                ),
              ),
              _TabList(
                child: _MessagesTab(
                  title: 'Advices',
                  messages: bill.advices,
                  empty: 'No advices on this bill.',
                  swift: false,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LcScreenScaffold(
      title: bill?.id ?? id,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: refresh,
        ),
      ],
      body: body,
    );
  }
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  _TabBarHeader({required this.tabBar, required this.color});

  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: color, child: tabBar);

  @override
  bool shouldRebuild(_TabBarHeader old) =>
      old.tabBar != tabBar || old.color != color;
}

class _TabList extends StatelessWidget {
  const _TabList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Builder(
        builder: (context) => CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(child: child),
            ),
          ],
        ),
      );
}

String _text(String? v) => lcOrDash(v == null || v.trim().isEmpty ? null : v);

String _address(LcAddress a, String Function(String?) countryName) {
  if (a.isEmpty) return '—';
  return [...a.lines, if (a.country != null) countryName(a.country)].join(', ');
}

class _Summary extends StatelessWidget {
  const _Summary({required this.bill});

  final CorpExportBill bill;

  @override
  Widget build(BuildContext context) {
    return LcSectionCard(
      title: 'Export bill',
      // One chip beside the title: two do not fit next to it on a phone.
      trailing: LcStatusChip(label: bill.statusLabel),
      children: [
        if (bill.isFinanced) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: LcStatusChip(label: 'FINANCED'),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          lcMoney(bill.amount),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: CorpColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _text(bill.productName),
          style: TextStyle(
            fontSize: 13,
            color: CorpColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        LcInfoGrid(items: [
          ('Outstanding amount', lcMoney(bill.outstandingAmount)),
          ('Maturity date', TfDate.display(bill.maturityDate)),
          ('Importer', _text(bill.importerName)),
          if (bill.equivalentAmount != null)
            ('Local currency equivalent', lcMoney(bill.equivalentAmount)),
        ]),
      ],
    );
  }
}

// ── 14.1 General Bill Details ───────────────────────────────────────────

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab({required this.bill});

  final CorpExportBill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countries = ref.watch(corpLcLookupsProvider).lookups;
    final s = bill.shipment;
    return Column(
      children: [
        LcSectionCard(
          title: 'Bill details',
          children: [
            LcInfoGrid(items: [
              (
                'Party ID',
                _text(bill.partyId.displayValue ?? bill.partyId.value)
              ),
              ('Branch', _text(bill.branchId)),
              ('Bill number', bill.id),
              ('Outstanding amount', lcMoney(bill.outstandingAmount)),
              ('Maturity date', TfDate.display(bill.maturityDate)),
              if (bill.tenor != null) ('Tenor', '${bill.tenor} days'),
              if (bill.baseDateDescription != null)
                ('Base date', bill.baseDateDescription!),
            ]),
            if (bill.lcRefNo != null) ...[
              const SizedBox(height: 10),
              _LinkedLc(lcId: bill.lcRefNo!),
            ],
          ],
        ),
        LcSectionCard(
          title: 'Exporter',
          children: [
            LcInfoGrid(items: [
              ('Name', _text(bill.exporterName)),
              (
                'Address',
                _address(bill.exporterAddress, countries.countryName)
              ),
              ('Customer reference number', _text(bill.customerRefNo)),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Importer',
          children: [
            LcInfoGrid(items: [
              ('Name', _text(bill.importerName)),
              (
                'Address',
                _address(bill.importerAddress, countries.countryName)
              ),
              ('Bank reference number', _text(bill.bankRefNo)),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Product details',
          children: [
            LcInfoGrid(items: [
              ('Payment type', _text(bill.paymentType)),
              (
                'Document attached',
                bill.documentsAttached == null
                    ? '—'
                    : bill.documentsAttached!
                        ? 'Yes (documentary)'
                        : 'No (clean)',
              ),
              ('Product', _text(bill.productName)),
              ('Product operation', _text(bill.operationName)),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Bill amount details',
          children: [
            LcInfoGrid(items: [
              ('Issuing bank SWIFT code', _text(bill.issuingBankSwift)),
              ('Issuing bank name', _text(bill.issuingBankName)),
              (
                'Issuing bank address',
                _address(bill.issuingBankAddress, countries.countryName),
              ),
              ('Bill amount', lcMoney(bill.amount)),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Goods & shipment',
          children: [
            LcInfoGrid(items: [
              ('Shipment from', _text(s.source)),
              ('Shipment to', _text(s.destination)),
              ('Port of loading', _text(s.loadingPort)),
              ('Port of discharge', _text(s.dischargePort)),
            ]),
            if (bill.goods.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final g in bill.goods)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LcInfoItem(
                    label: g.code,
                    value: '${g.description ?? g.code} · '
                        '${g.noOfUnits?.toStringAsFixed(0) ?? '—'} × '
                        '${lcAmount(g.pricePerUnit, bill.amount?.currency)}',
                  ),
                ),
            ],
          ],
        ),
        LcSectionCard(
          title: 'Instructions',
          children: [
            LcInfoGrid(items: [('Remarks', _text(bill.remarks))]),
          ],
        ),
      ],
    );
  }
}

/// "Linked to LC" — opens the export LC.
class _LinkedLc extends StatelessWidget {
  const _LinkedLc({required this.lcId});

  final String lcId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).pushNamed(
        CorpRoutesConst.exportLcDetailScreen,
        arguments: LcDetailArgs(lcId: lcId, lcType: LcType.exportLc),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.link_rounded,
                size: 18, color: CorpColors.brand(context)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Linked to LC $lcId',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: CorpColors.brand(context),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: CorpColors.brand(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 14.2 Discrepancies ──────────────────────────────────────────────────

class _DiscrepanciesTab extends StatelessWidget {
  const _DiscrepanciesTab({required this.bill});

  final CorpExportBill bill;

  @override
  Widget build(BuildContext context) {
    return LcSectionCard(
      title: 'Discrepancies',
      children: [
        if (bill.lcRefNo == null)
          const _Muted('Discrepancies apply only to bills under an LC.')
        else if (bill.discrepancies.isEmpty)
          const _Muted('No discrepancies were raised on this bill.')
        else
          for (final d in bill.discrepancies)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CorpColors.divider(context)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.description,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: CorpColors.textPrimary(context),
                          ),
                        ),
                      ),
                      if (d.status != null) LcStatusChip(label: d.status!),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LcInfoGrid(items: [
                    ('Received', TfDate.display(d.receivedDate)),
                    ('Resolved', TfDate.display(d.resolvedDate)),
                    // Blank until the bank approves — manual FAQ 2.
                    ('Approved', TfDate.display(d.approvedDate)),
                  ]),
                ],
              ),
            ),
      ],
    );
  }
}

// ── 14.4 SWIFT Messages / 14.5 Advices ──────────────────────────────────

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({
    required this.title,
    required this.messages,
    required this.empty,
    required this.swift,
  });

  final String title;
  final List<ExportBillMessage> messages;
  final String empty;
  final bool swift;

  @override
  Widget build(BuildContext context) {
    return LcSectionCard(
      title: title,
      children: [
        if (messages.isEmpty)
          _Muted(empty)
        else
          for (final m in messages)
            InkWell(
              onTap: () => _showMessage(context, m),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: CorpColors.divider(context)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.id,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: CorpColors.brand(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              TfDate.display(m.date),
                              if (swift && m.messageType != null)
                                m.messageType!,
                              if (swift && m.bank != null) m.bank!,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: CorpColors.textSecondary(context),
                            ),
                          ),
                          if (m.description != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              m.description!,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: CorpColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: CorpColors.textSecondary(context),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  /// The manual's details pop-up: event date, event description, and the
  /// message itself.
  void _showMessage(BuildContext context, ExportBillMessage m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.id),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LcInfoItem(label: 'Event date', value: TfDate.display(m.date)),
              const SizedBox(height: 10),
              LcInfoItem(
                label: 'Event description',
                value: _text(m.eventDescription ?? m.description),
              ),
              const SizedBox(height: 10),
              LcInfoItem(
                label: 'Description',
                value: _text(m.content ?? m.description),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: CorpColors.textSecondary(context),
          ),
        ),
      );
}
