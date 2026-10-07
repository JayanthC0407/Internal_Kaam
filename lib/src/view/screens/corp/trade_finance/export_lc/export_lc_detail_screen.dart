import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_details.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_export_bill_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_export_lc_view_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/export_bill_list_page.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// View Export Letter of Credit — one LC (manual ch. 11.1–11.11).
///
/// Tabs, from `GET …/letterofcredits/{id}`: LC Details, Goods & Shipment,
/// Documents, Instructions, Charges and Banks; Amendments from the export
/// amendments list; Bills from the export bills list. The manual's SWIFT
/// Messages, Advices and Attached Documents tabs are not here yet: no
/// capture shows the calls behind them.
class ExportLcDetailScreen extends ConsumerStatefulWidget {
  const ExportLcDetailScreen({super.key, required this.args});

  final LcDetailArgs args;

  static const tabs = [
    'LC Details',
    'Goods & Shipment',
    'Documents',
    'Instructions',
    'Amendments',
    'Bills',
    'Charges',
    'Banks',
  ];

  @override
  ConsumerState<ExportLcDetailScreen> createState() =>
      _ExportLcDetailScreenState();
}

class _ExportLcDetailScreenState extends ConsumerState<ExportLcDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Country names for the addresses.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(corpLcLookupsProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lcId = widget.args.lcId;
    final state = ref.watch(corpLcDetailProvider(lcId));
    final permissions = ref.watch(lcPermissionsProvider);
    final lc = state.lc;
    void refresh() => ref.read(corpLcDetailProvider(lcId).notifier).refresh();

    final Widget body;
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
          onPressed: refresh,
        ),
      );
    } else {
      body = DefaultTabController(
        length: ExportLcDetailScreen.tabs.length,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.errorMessage != null)
                      LcMessageBanner(message: state.errorMessage!),
                    _HeaderStrip(lc: lc),
                  ],
                ),
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
                  // Each tab at its natural width: all seven side by side on
                  // a desktop, scrolling sideways on a phone — never squeezed
                  // until a label is cut off.
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
                      for (final t in ExportLcDetailScreen.tabs) Tab(text: t),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _TabList(children: [_DetailsTab(lc: lc)]),
              _TabList(children: [_GoodsShipmentTab(lc: lc)]),
              _TabList(children: [_DocumentsTab(lc: lc)]),
              _TabList(children: [_InstructionsTab(lc: lc)]),
              _TabList(children: [_AmendmentsTab(lc: lc)]),
              _TabList(children: [_BillsTab(lc: lc)]),
              _TabList(
                children: [
                  LcSectionCard(
                    title: 'Charges, commission & taxes',
                    children: [LcChargesList(charges: lc.charges)],
                  ),
                ],
              ),
              _TabList(children: [_BanksTab(lc: lc)]),
            ],
          ),
        ),
      );
    }

    final canTransfer = lc != null &&
        lc.transferable &&
        lc.isActive &&
        !lc.isExpired &&
        permissions.initiateTransfer;
    // As on the OBDX view screen: only an import LC can be copied into a
    // new LC application.
    final canCopy =
        lc != null && lc.lcType == LcType.importLc && permissions.initiate;

    // The OBDX page title, by the LC's own type; shortened where a phone's
    // app bar would cut it off.
    final kind = lc?.lcType == LcType.importLc ? 'Import' : 'Export';
    final phone = MediaQuery.sizeOf(context).width < 600;
    final party = lc == null
        ? ''
        : [lc.partyName, lc.partyId.displayValue]
            .whereType<String>()
            .join(' | ');

    return LcScreenScaffold(
      title: phone ? '$kind Letter of Credit' : 'View $kind Letter Of Credit',
      subtitle: party.isEmpty ? null : party,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: refresh,
        ),
        if (canTransfer)
          PopupMenuButton<void>(
            tooltip: 'More actions',
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => Navigator.of(context).pushNamed(
                  CorpRoutesConst.lcTransferScreen,
                  arguments: LcTransferArgs(lcId: lc.id),
                ),
                child: const Text('Transfer LC'),
              ),
            ],
          ),
      ],
      body: body,
      bottomBar: lc == null
          ? null
          : _BottomButtons(
              onCopy: canCopy
                  ? () => Navigator.of(context).pushNamed(
                        CorpRoutesConst.lcInitiateScreen,
                        arguments: LcInitiateArgs.copyOf(lc),
                      )
                  : null,
            ),
    );
  }
}

/// Copy & Initiate and Back, as at the foot of the OBDX view screen.
class _BottomButtons extends StatelessWidget {
  const _BottomButtons({required this.onCopy});

  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = onCopy == null
            ? null
            : LcPrimaryButton(label: 'Copy & Initiate', onPressed: onCopy);
        final back = LcSecondaryButton(
          label: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        );
        // A phone: Copy & Initiate takes the room Back leaves, so the main
        // action is the big target. Wider: both at their natural size,
        // from the left, as on the web.
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
  const _TabList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Builder(
        builder: (context) => CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildListDelegate(children)),
            ),
          ],
        ),
      );
}

// ── Shared bits ─────────────────────────────────────────────────────────

String _text(String? v) => lcOrDash(v == null || v.trim().isEmpty ? null : v);

String _yesNo(bool v) => v ? 'Yes' : 'No';

String _address(LcAddress a, String Function(String?) countryName) {
  if (a.isEmpty) return '—';
  return [
    ...a.lines,
    if (a.country != null) countryName(a.country),
  ].join(', ');
}

/// "Credit available by" labels for the manual's options; anything else
/// is shown tidied rather than hidden.
String _availableBy(String? code) {
  final c = code?.trim().toUpperCase();
  if (c == null || c.isEmpty) return '—';
  return switch (c) {
    'SIGHTPAYMENT' => 'Sight payment',
    'ACCEPTANCE' => 'Acceptance',
    'DEFPAYMENT' || 'DEFERREDPAYMENT' => 'Deferred payment',
    'MIXEDPAYMENT' => 'Mixed payment',
    'NEGOTIATION' => 'Negotiation',
    _ => c[0] + c.substring(1).toLowerCase(),
  };
}

String _confirmation(String? code) => switch (code) {
      'CONFIRM' => 'Confirm',
      'MAY_ADD' => 'May add',
      'WITHOUT' => 'Without',
      _ => _text(code),
    };

String _borneBy(String? code) {
  for (final v in LcChargesBorneBy.values) {
    if (v.code == code) return v.label;
  }
  return _text(code);
}

/// The manual's "More information / Hide information" toggle.
class _MoreInformation extends StatefulWidget {
  const _MoreInformation({required this.items});

  final List<(String, String)> items;

  @override
  State<_MoreInformation> createState() => _MoreInformationState();
}

class _MoreInformationState extends State<_MoreInformation> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
              _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            label: Text(_open ? 'Hide information' : 'More information'),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LcInfoGrid(items: widget.items),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────

/// The OBDX header: the LC reference with its status and the expiry date
/// under it, then the back-to-back LC, product and amount.
class _HeaderStrip extends StatelessWidget {
  const _HeaderStrip({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    final backToBack = lc.backToBackLcNumbers;
    final reference = _HeaderItem(
      label: 'LC Reference No.',
      value: lc.id,
      badges: [
        LcStatusChip(label: lc.statusLabel),
        if (lc.isExpired) const LcStatusChip(label: 'EXPIRED'),
      ],
    );
    final expiry = _HeaderItem(
      label: 'Date of Expiry',
      value: TfDate.display(lc.expiryDate),
    );
    final others = [
      if (backToBack.isNotEmpty)
        _HeaderItem(label: 'Back to Back LC No.', value: backToBack.join(', ')),
      _HeaderItem(label: 'Product', value: _text(lc.productName)),
      _HeaderItem(label: 'LC Amount', value: lcMoney(lc.amount)),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CorpColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                if (w >= 600) {
                  // Wide: one row, the reference and expiry stacked first.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A little wider, so the status badge stays
                      // beside the reference, as on OBDX.
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            reference,
                            const SizedBox(height: 12),
                            expiry,
                          ],
                        ),
                      ),
                      for (final item in others) ...[
                        const SizedBox(width: 20),
                        Expanded(flex: 3, child: item),
                      ],
                    ],
                  );
                }
                // A phone: the reference on its own line, the rest two-up.
                const gap = 16.0;
                final half = (w - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: 14,
                  children: [
                    SizedBox(width: w, child: reference),
                    for (final item in [...others, expiry])
                      SizedBox(width: half, child: item),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderItem extends StatelessWidget {
  const _HeaderItem({
    required this.label,
    required this.value,
    this.badges = const [],
  });

  final String label;
  final String value;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: CorpColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CorpColors.textPrimary(context),
              ),
            ),
            ...badges,
          ],
        ),
      ],
    );
  }
}

// ── 11.1 LC Details ─────────────────────────────────────────────────────

class _DetailsTab extends ConsumerWidget {
  const _DetailsTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countries = ref.watch(corpLcLookupsProvider).lookups;
    final party = [
      if (lc.partyName != null) lc.partyName!,
      if (lc.partyId.displayValue != null) lc.partyId.displayValue!,
    ].join(' · ');
    final creditType = [
      lc.transferable ? 'Transferable' : 'Non transferable',
      lc.revolving ? 'Revolving' : 'Non revolving',
    ].join(' / ');

    return Column(
      children: [
        LcSectionCard(
          title: 'LC details',
          children: [
            LcInfoGrid(items: [
              ('Party name and ID', party.isEmpty ? '—' : party),
              ('LC reference no.', lc.id),
              ('Product', _text(lc.productName)),
              ('LC amount', lcMoney(lc.amount)),
              ('Outstanding amount', lcMoney(lc.outstandingAmount)),
              ('Date of application', TfDate.display(lc.applicationDate)),
              ('Date of expiry', TfDate.display(lc.expiryDate)),
              ('Place of expiry', _text(lc.expiryPlace)),
              ('Type of documentary credit', creditType),
              ('Irrevocable', _yesNo(lc.irrevocable)),
              ('Confirmed', _yesNo(lc.confirmed)),
              if (lc.revolving) ...[
                ('Revolving frequency', _text(lc.revolvingFrequency)),
                ('Auto reinstatement', _yesNo(lc.autoReinstatement)),
                ('Cumulative', _yesNo(lc.cumulative)),
              ],
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Applicant',
          children: [
            LcInfoGrid(items: [
              ('Name', _text(lc.counterPartyName)),
              (
                'Address',
                _address(lc.counterPartyAddress, countries.countryName),
              ),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Beneficiary',
          children: [
            LcInfoGrid(items: [
              ('Name', _text(lc.partyName)),
              ('Address', _address(lc.partyAddress, countries.countryName)),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Terms',
          children: [
            _MoreInformation(items: [
              (
                'LC amount tolerance',
                '+${(lc.toleranceAbove ?? 0).toStringAsFixed(0)}% / '
                    '−${(lc.toleranceUnder ?? 0).toStringAsFixed(0)}%',
              ),
              ('Total exposure', lcMoney(lc.totalExposure)),
              ('Credit available by', _availableBy(lc.transferableType)),
              ('Credit available with', _text(lc.availableWith)),
              (
                'Negotiation / deferred payment details',
                _text(lc.paymentDetails),
              ),
              ('Additional amounts covered', _text(lc.additionalAmountCovered)),
              ('Drafts required', _yesNo(lc.draftsRequired)),
            ]),
          ],
        ),
      ],
    );
  }
}

// ── 11.2 Goods and Shipment ─────────────────────────────────────────────

class _GoodsShipmentTab extends StatelessWidget {
  const _GoodsShipmentTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    final s = lc.shipment;
    return Column(
      children: [
        LcSectionCard(
          title: 'Shipment',
          children: [
            LcInfoGrid(items: [
              ('Partial shipment', lcYesNo(s.partialAllowed)),
              ('Transshipment', lcYesNo(s.transshipmentAllowed)),
              ('Place of taking in charge / dispatch from', _text(s.source)),
              ('Port of loading / airport of departure', _text(s.loadingPort)),
              (
                'Port of discharge / airport of destination',
                _text(s.dischargePort),
              ),
              ('Place of final destination', _text(s.destination)),
              ('Latest shipment date', TfDate.display(s.latestShipmentDate)),
              if (s.period != null) ('Shipment period', '${s.period} days'),
              ('Incoterm', _text(lc.incoterm?.label)),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Goods',
          children: [
            if (lc.goods.isEmpty)
              _Muted('No goods are recorded on this LC.')
            else
              for (final g in lc.goods) _GoodsRow(goods: g, lc: lc),
          ],
        ),
      ],
    );
  }
}

class _GoodsRow extends StatelessWidget {
  const _GoodsRow({required this.goods, required this.lc});

  final LcGoods goods;
  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    final currency = lc.amount?.currency;
    String n(double? v) => v == null
        ? '—'
        : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: CorpColors.divider(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goods.description ?? goods.code,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${goods.code} · ${n(goods.noOfUnits)} units × '
                  '${lcAmount(goods.pricePerUnit, currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            lcAmount(goods.total, currency),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: CorpColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 11.3 Documents ──────────────────────────────────────────────────────

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    final documents = lc.exportDocuments;
    return Column(
      children: [
        LcSectionCard(
          title: 'Documents to present',
          children: [
            if (documents.isEmpty)
              _Muted('The bank has not sent a document list for this LC.')
            else
              for (final d in documents) _DocumentRow(document: d),
          ],
        ),
        LcSectionCard(
          title: 'Conditions',
          children: [
            LcInfoGrid(items: [
              (
                'Documents to be presented within',
                lc.documentPresentationDays == null
                    ? '—'
                    : '${lc.documentPresentationDays} days after the date '
                        'of shipment, within the validity of the credit',
              ),
            ]),
            if (lc.additionalConditions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Additional conditions',
                style: TextStyle(
                  fontSize: 12,
                  color: CorpColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 4),
              for (final c in lc.additionalConditions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${c.label}',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: CorpColors.textPrimary(context),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});

  final ExportLcDocument document;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: CorpColors.divider(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.name,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: CorpColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Originals: ${_text(document.originals)} · '
            'Copies: ${_text(document.copies)}',
            style: TextStyle(
              fontSize: 12,
              color: CorpColors.textSecondary(context),
            ),
          ),
          for (final clause in document.clauses)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                clause,
                style: TextStyle(
                  fontSize: 12.5,
                  color: CorpColors.textPrimary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 11.4 Instructions ───────────────────────────────────────────────────

class _InstructionsTab extends StatelessWidget {
  const _InstructionsTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    return LcSectionCard(
      title: 'Instructions',
      children: [
        LcInfoGrid(items: [
          ('Advising bank SWIFT ID', _text(lc.advisingBankCode)),
          (
            'Special payment conditions for beneficiary',
            _text(lc.paymentConditionsBeneficiary),
          ),
          (
            'Confirmation instructions',
            _confirmation(lc.confirmationInstruction),
          ),
          (
            'Requested confirmation party',
            _text(lc.requestedConfirmationParty)
          ),
          (
            'Special payment conditions for bank only',
            _text(lc.paymentConditionsBank),
          ),
        ]),
        const SizedBox(height: 4),
        _MoreInformation(items: [
          ('Sender to receiver information', _text(lc.senderToReceiverInfo)),
          ('Charges borne by', _borneBy(lc.chargesBorneBy)),
          ('Charges from beneficiary', _text(lc.chargesFromBeneficiary)),
          ('Remarks', _text(lc.remarks)),
        ]),
      ],
    );
  }
}

// ── 11.6 Amendments ─────────────────────────────────────────────────────

class _AmendmentsTab extends ConsumerWidget {
  const _AmendmentsTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(exportLcPendingAmendmentsProvider(lc.id));
    final canRespond = ref.watch(lcPermissionsProvider).amendmentAcceptance;

    return LcSectionCard(
      title: 'Amendments awaiting your acceptance',
      trailing: IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded),
        color: CorpColors.textSecondary(context),
        onPressed: () =>
            ref.invalidate(exportLcPendingAmendmentsProvider(lc.id)),
      ),
      children: [
        value.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => LcMessageBanner(message: '$error'),
          data: (amendments) => amendments.isEmpty
              ? _Muted(
                  'No amendments to this LC are awaiting your response.',
                )
              : Column(
                  children: [
                    for (final a in amendments)
                      _AmendmentRow(
                        amendment: a,
                        onTap: canRespond
                            ? () => Navigator.of(context).pushNamed(
                                  CorpRoutesConst.lcAcceptanceScreen,
                                  arguments: LcAcceptanceArgs(amendment: a),
                                )
                            : null,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AmendmentRow extends StatelessWidget {
  const _AmendmentRow({required this.amendment, this.onTap});

  final CorpLcAmendment amendment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = amendment;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
                    'Amendment ${a.id}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CorpColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (a.amendmentDate != null)
                        'Issued ${TfDate.display(a.amendmentDate)}',
                      if (a.newExpiryDate != null)
                        'New expiry ${TfDate.display(a.newExpiryDate)}',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  lcMoney(a.newAmount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                LcStatusChip(
                  label: a.isPending
                      ? 'PENDING'
                      : (a.acceptanceStatus ?? '').toUpperCase(),
                ),
              ],
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: CorpColors.textSecondary(context),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 11.7 Bills ──────────────────────────────────────────────────────────

class _BillsTab extends ConsumerWidget {
  const _BillsTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(exportLcBillsProvider(lc.id));
    return LcSectionCard(
      title: 'Bills under this LC',
      trailing: IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded),
        color: CorpColors.textSecondary(context),
        onPressed: () => ref.invalidate(exportLcBillsProvider(lc.id)),
      ),
      children: [
        value.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => LcMessageBanner(message: '$error'),
          data: (bills) => bills.isEmpty
              ? _Muted('No bills have been presented under this LC.')
              : ExportBillCards(bills: bills),
        ),
      ],
    );
  }
}

// ── 11.11 Banks ─────────────────────────────────────────────────────────

class _BanksTab extends StatelessWidget {
  const _BanksTab({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    final banks = [
      ('Issuing bank', lc.issuingBankCode),
      ('Advising bank', lc.advisingBankCode),
      ('Advise through bank', lc.advisingThroughBankCode),
      ('Confirming bank', lc.confirmingBankCode),
      ('Reimbursing bank', lc.reimbursingBankCode),
    ];
    final present = [
      for (final (role, code) in banks)
        if (code != null && code.trim().isNotEmpty) (role, code.trim()),
    ];
    if (present.isEmpty) {
      return LcSectionCard(
        title: 'Banks',
        children: [_Muted('No other banks are named on this LC.')],
      );
    }
    return Column(
      children: [
        for (final (role, code) in present) _BankCard(role: role, code: code),
      ],
    );
  }
}

class _BankCard extends ConsumerWidget {
  const _BankCard({required this.role, required this.code});

  final String role;
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(tradeBankByCodeProvider(code));
    final countries = ref.watch(corpLcLookupsProvider).lookups;
    final b = bank.valueOrNull;
    return LcSectionCard(
      title: role,
      trailing: bank.isLoading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      children: [
        LcInfoGrid(items: [
          ('SWIFT', code),
          ('Name', _text(b?.name)),
          if (b != null && !b.address.isEmpty)
            ('Address', _address(b.address, countries.countryName)),
        ]),
      ],
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
