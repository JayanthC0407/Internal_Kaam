import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_menu.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Facility Details — OBDX `credit-facility/facility-details`: from the
/// menu a Choose Facility dialog comes first; from Facility Summary the
/// facility (and tab) is given. Body: the amounts, More Information with
/// the Facility Schedule, then the Collateral Groups, Covenants and
/// Transaction Summary tabs. Evidence: docs/obdx/features/credit-facility.md §5.
class FacilityDetailsPage extends ConsumerStatefulWidget {
  const FacilityDetailsPage({super.key, this.initialKey, this.initialTab, required this.onExit});

  /// `lineCode_lineSerialNumber`; null from the menu.
  final String? initialKey;
  final CfDetailTab? initialTab;

  /// Choose Facility closed without a choice: back where the user came
  /// from (OBDX switches to the dashboard).
  final VoidCallback onExit;

  @override
  ConsumerState<FacilityDetailsPage> createState() => _FacilityDetailsPageState();
}

class _FacilityDetailsPageState extends ConsumerState<FacilityDetailsPage> {
  late String? _key = widget.initialKey;
  late CfDetailTab? _tab = widget.initialTab;
  bool _more = false;
  bool _asked = false;

  @override
  void didUpdateWidget(FacilityDetailsPage old) {
    super.didUpdateWidget(old);
    if (old.initialKey != widget.initialKey || old.initialTab != widget.initialTab) {
      _key = widget.initialKey;
      _tab = widget.initialTab;
      _asked = false;
    }
  }

  Future<void> _choose(List<CfFacility> options) async {
    String? picked = options.firstOrNull?.key;
    final key = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Choose Facility'),
          content: SizedBox(
            width: 420,
            child: options.isEmpty
                ? const Text('No facilities to show.')
                : LcPickerField<String>(
                    label: 'Facility Name',
                    options: [for (final f in options) f.key],
                    labelOf: (k) => k,
                    selected: picked,
                    onSelected: (k) => setDialog(() => picked = k),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: picked == null ? null : () => Navigator.of(dialog).pop(picked),
              child: const Text('Proceed'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (key == null) return widget.onExit();
    setState(() => _key = key);
  }

  @override
  Widget build(BuildContext context) {
    final key = _key;
    final options = ref.watch(cfFacilityOptionsProvider);
    if (key == null) {
      final list = options.valueOrNull;
      if (list != null && !_asked) {
        _asked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _choose(list.all);
        });
      }
      return CorpCardShell(
        child: options.hasError
            ? _Failed(
                message: _message(options.error, 'We couldn\'t load the facilities.'),
                onRetry: () => ref.invalidate(cfFacilityOptionsProvider),
              )
            : list == null
                ? const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
                : Center(
                    child: TextButton.icon(
                      onPressed: () => _choose(list.all),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Choose Facility'),
                    ),
                  ),
      );
    }
    final perms = ref.watch(cfPermissionsProvider);
    final async = ref.watch(cfFacilityProvider(key));
    return async.when(
      loading: () => const CorpCardShell(
        child: Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => CorpCardShell(
        child: _Failed(
          message: _message(e, 'We couldn\'t load this facility.'),
          onRetry: () => ref.invalidate(cfFacilityProvider(key)),
        ),
      ),
      data: (f) {
        final tabs = [for (final t in CfDetailTab.values) if (t.allowedBy(perms)) t];
        // OBDX opens on Collateral Groups when allowed, else Covenants.
        final tab = tabs.contains(_tab) ? _tab! : tabs.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Summary(
              facility: f,
              options: options.valueOrNull?.all ?? [f],
              more: _more,
              onMore: () => setState(() => _more = !_more),
              onFacility: (k) => setState(() {
                _key = k;
                _more = false;
              }),
            ),
            const SizedBox(height: 14),
            CorpCardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<CfDetailTab>(
                      showSelectedIcon: false,
                      segments: [for (final t in tabs) ButtonSegment(value: t, label: Text(t.label))],
                      selected: {tab},
                      onSelectionChanged: (s) => setState(() => _tab = s.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  switch (tab) {
                    CfDetailTab.collateralGroups => _CollateralGroupsTab(facility: f),
                    CfDetailTab.covenants => _CovenantsTab(covenants: f.covenants),
                    CfDetailTab.transactionSummary => _UtilizationTab(facilityKey: f.key),
                  },
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _message(Object? error, String fallback) =>
    error is CfLoadError && error.message != null && error.message!.trim().isNotEmpty ? error.message! : fallback;

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcMessageBanner(message: message),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
        ),
      ],
    );
  }
}

/// The top block: Facility Name, the amounts, Amend Facility | Add Sub
/// Facility, More / Less Information and the Facility Schedule.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.facility,
    required this.options,
    required this.more,
    required this.onMore,
    required this.onFacility,
  });

  final CfFacility facility;
  final List<CfFacility> options;
  final bool more;
  final VoidCallback onMore;
  final ValueChanged<String> onFacility;

  @override
  Widget build(BuildContext context) {
    final f = facility;
    final collateral = f.collateralAmount == null
        ? null
        : MoneyAmount(amount: f.collateralAmount!.amount, currency: f.availableAmount?.currency ?? f.collateralAmount!.currency);
    final today = DateUtils.dateOnly(DateTime.now());
    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              TextButton(onPressed: () => cfSnack(context, cfComingSoon), child: const Text('Amend Facility')),
              TextButton(onPressed: () => cfSnack(context, cfComingSoon), child: const Text('Add Sub Facility')),
            ],
          ),
          LcPickerField<String>(
            label: 'Facility Name',
            options: [for (final o in options) o.key],
            labelOf: (k) => k,
            selected: f.key,
            onSelected: (k) {
              if (k != f.key) onFacility(k);
            },
          ),
          const SizedBox(height: 14),
          LcInfoGrid(items: [
            ('Sanctioned Amount', cfMoney(f.effectiveAmount)),
            ('Utilized Amount', cfMoney(f.utilizedAmount)),
            ('Available Amount', cfMoney(f.availableAmount)),
            ('Collateral Value', cfMoney(collateral)),
          ]),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onMore,
              icon: Icon(more ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text(more ? 'Less Information' : 'More Information'),
            ),
          ),
          if (more) ...[
            // Status and Expiry Date are blank in OBDX (bound to undefined,
            // card §8); shown from the response here. Review Frequency, Renew
            // Date and Next Review Date have no known field [UNKNOWN].
            LcInfoGrid(items: [
              ('Funding Type', f.category ?? '--'),
              ('Facility Type', f.facilityType ?? '--'),
              ('Revolving Line', cfYesNo(f.revolving)),
              ('Block Amount', cfMoney(f.blockAmount)),
              ('Status', f.status ?? '--'),
              ('Review Frequency', '--'),
              ('Start Date', cfDateOr(f.lineStartDate, '--')),
              ('Expiry Date', cfDateOr(f.expiryDate, '--')),
              ('Renew Date', '--'),
              ('Next Review Date', '--'),
            ]),
            if (f.schedule.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Facility Schedule',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context)),
              ),
              const SizedBox(height: 8),
              for (final s in f.schedule)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        s.date != null && s.date!.isBefore(today) ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 18,
                        color: s.date != null && s.date!.isBefore(today)
                            ? CorpColors.textSecondary(context)
                            : CorpColors.brand(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: LcInfoItem(label: 'Schedule Date', value: cfDateOr(s.date, '--'))),
                      Expanded(child: LcInfoItem(label: 'Schedule Amount', value: cfMoney(s.amount))),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Collateral Groups (`collateral-groups`): the facility's group with its
/// linked collaterals.
class _CollateralGroupsTab extends ConsumerStatefulWidget {
  const _CollateralGroupsTab({required this.facility});

  final CfFacility facility;

  @override
  ConsumerState<_CollateralGroupsTab> createState() => _CollateralGroupsTabState();
}

class _CollateralGroupsTabState extends ConsumerState<_CollateralGroupsTab> {
  bool _linked = false;

  @override
  Widget build(BuildContext context) {
    const none = LcEmptyState(icon: Icons.link_off_rounded, title: 'No Collateral Group is linked with this facility');
    final pool = widget.facility.poolId;
    if (pool == null) return none;
    return ref.watch(cfCollateralGroupProvider(pool)).when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => _Failed(
            message: _message(e, 'We couldn\'t load the collateral group.'),
            onRetry: () => ref.invalidate(cfCollateralGroupProvider(pool)),
          ),
          data: (g) {
            if (g == null) return none;
            final currency = g.groupAmount?.currency;
            MoneyAmount m(double v) => MoneyAmount(amount: v, currency: currency);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Panel(
                  header: Row(children: [
                    Text(g.poolId, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
                    const SizedBox(width: 10),
                    const CfTag('Group'),
                  ]),
                  child: LcInfoGrid(items: [
                    ('Collateral Group Amount', cfMoney(g.groupAmount)),
                    ('Utilized Amount', cfMoney(m(g.shownUtilized))),
                    ('Block Amount', cfMoney(m(g.shownBlock))),
                    ('Available Amount', cfMoney(g.availableAmount)),
                    ('Contribution to Facility', cfMoney(m(g.contribution(widget.facility.poolPercentage)))),
                  ]),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: g.linked.isEmpty ? null : () => setState(() => _linked = !_linked),
                    icon: Icon(_linked ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                    label: const Text('Linked Collateral'),
                  ),
                ),
                if (_linked)
                  for (final c in g.linked)
                    _Panel(
                      header: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.code, style: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
                          if (c.description != null)
                            Text(c.description!, style: TextStyle(fontSize: 12.5, color: CorpColors.textSecondary(context))),
                        ],
                      ),
                      child: LcInfoGrid(items: [
                        ('Collateral Value', cfMoney(c.value)),
                        ('Collateral Amount (After Haircut)', cfMoney(c.limitContribution)),
                        ('End Date', cfDateOr(c.endDate, '--')),
                        ('Margin', cfPercent(c.lendableMargin)),
                        (
                          'Contribution to Group',
                          '${cfMoney(c.utilization)}${c.contributionPercent == null ? '' : '  ${cfPercent(c.contributionPercent)}'}'
                        ),
                      ]),
                    ),
              ],
            );
          },
        );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: CorpColors.divider(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: 10), child]),
    );
  }
}

/// Covenants (`facility-covenants`): one card per `covenantDTO`.
class _CovenantsTab extends StatelessWidget {
  const _CovenantsTab({required this.covenants});

  final List<CfCovenant> covenants;

  @override
  Widget build(BuildContext context) {
    if (covenants.isEmpty) return const LcEmptyState(icon: Icons.gavel_rounded, title: 'No covenants to show.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in covenants)
          _Panel(
            header: LcInfoItem(label: 'Covenant Id', value: c.name ?? '--'),
            child: LcInfoGrid(items: [
              ('Revision Date', cfDateOr(c.revisionDate, '--')),
              ('Description', c.description ?? '--'),
            ]),
          ),
      ],
    );
  }
}

/// Transaction Summary (`facility-utilization`): search, Filter (Date From
/// / To), Download (PDF); a table on wide screens, cards on phones.
class _UtilizationTab extends ConsumerStatefulWidget {
  const _UtilizationTab({required this.facilityKey});

  final String facilityKey;

  @override
  ConsumerState<_UtilizationTab> createState() => _UtilizationTabState();
}

enum _Sort { none, amount, available }

class _UtilizationTabState extends ConsumerState<_UtilizationTab> {
  DateTime? _from;
  DateTime? _to;
  String _query = '';
  _Sort _sort = _Sort.none;
  bool _ascending = true;

  CfUtilizationKey get _key => (facility: widget.facilityKey, from: _from, to: _to);

  Future<void> _filter() async {
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime? from = _from;
    DateTime? to = _to;
    var showErrors = false;
    final result = await showDialog<(DateTime?, DateTime?)>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) {
          final missing = from == null || to == null;
          final order = from != null && to != null && to!.isBefore(from!);
          return AlertDialog(
            title: const Text('Filter'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LcDateField(
                    label: 'Date From',
                    value: from,
                    lastDate: today,
                    helper: showErrors && from == null ? 'Date From is required.' : null,
                    onChanged: (d) => setDialog(() => from = d),
                  ),
                  const SizedBox(height: 12),
                  LcDateField(
                    label: 'To',
                    value: to,
                    firstDate: from,
                    lastDate: today,
                    helper: showErrors && to == null
                        ? 'To is required.'
                        : showErrors && order
                            ? 'To must not be before Date From.'
                            : null,
                    onChanged: (d) => setDialog(() => to = d),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialog).pop((null, null)), child: const Text('Reset')),
              FilledButton(
                onPressed: () {
                  if (missing || order) return setDialog(() => showErrors = true);
                  Navigator.of(dialog).pop((from, to));
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _from = result.$1;
        _to = result.$2;
      });
    }
  }

  List<CfUtilizationRow> _rows(List<CfUtilizationRow> all) {
    final q = _query.trim();
    final list = q.isEmpty ? [...all] : all.where((r) => r.matches(q)).toList();
    double v(CfUtilizationRow r) => (_sort == _Sort.amount ? r.amount?.amount : r.available?.amount) ?? 0;
    if (_sort != _Sort.none) list.sort((a, b) => _ascending ? v(a).compareTo(v(b)) : v(b).compareTo(v(a)));
    return list;
  }

  void _toggleSort(_Sort s) => setState(() {
        if (_sort == s) {
          _ascending = !_ascending;
        } else {
          _sort = s;
          _ascending = true;
        }
      });

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cfUtilizationProvider(_key));
    final filtered = _from != null || _to != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search..',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            Badge(
              isLabelVisible: filtered,
              smallSize: 8,
              backgroundColor: CorpColors.brand(context),
              child: IconButton(
                tooltip: 'Filter',
                icon: Icon(Icons.tune_rounded, color: CorpColors.textSecondary(context)),
                onPressed: _filter,
              ),
            ),
            CfDownloadButton(
              fileName: 'TransactionSummary.pdf',
              enabled: (async.valueOrNull ?? const []).isNotEmpty,
              download: () => ref
                  .read(corpCreditFacilityRepositoryProvider)
                  .downloadUtilization(widget.facilityKey, from: _from, to: _to),
            ),
          ],
        ),
        if (filtered)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${cfDateOr(_from)} – ${cfDateOr(_to)}',
              style: TextStyle(fontSize: 12.5, color: CorpColors.textSecondary(context)),
            ),
          ),
        const SizedBox(height: 10),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => _Failed(
            message: _message(e, 'We couldn\'t load the transactions.'),
            onRetry: () => ref.invalidate(cfUtilizationProvider(_key)),
          ),
          data: (all) {
            final rows = _rows(all);
            if (rows.isEmpty) return const LcEmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions to show.');
            return LayoutBuilder(
              builder: (context, c) => c.maxWidth >= 720 ? _table(context, rows) : _cards(rows),
            );
          },
        ),
      ],
    );
  }

  /// OBDX shows "--" for a zero amount.
  String _amount(MoneyAmount? m) => m == null || m.amount == 0 ? '--' : cfMoney(m);

  Widget _table(BuildContext context, List<CfUtilizationRow> rows) {
    final head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context));
    final cell = TextStyle(fontSize: 13, color: CorpColors.textPrimary(context));
    Widget sortable(String label, _Sort s) => InkWell(
          onTap: () => _toggleSort(s),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: head),
            Icon(
              _sort != s ? Icons.unfold_more_rounded : (_ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
              size: 14,
              color: CorpColors.textSecondary(context),
            ),
          ]),
        );
    TableRow row(List<Widget> cells, {bool header = false}) => TableRow(
          decoration: BoxDecoration(
            color: header ? CorpColors.divider(context).withValues(alpha: 0.4) : null,
            border: Border(bottom: BorderSide(color: CorpColors.divider(context))),
          ),
          children: [for (final c in cells) Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), child: c)],
        );
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(1.3), 2: FlexColumnWidth(1.4), 3: FlexColumnWidth(1.2), 4: FlexColumnWidth(1.3)},
      children: [
        row([
          Text('Date', style: head),
          Text('Reference Number', style: head),
          Text('Transaction Type', style: head),
          sortable('Amount', _Sort.amount),
          sortable('Available Amount', _Sort.available),
        ], header: true),
        for (final r in rows)
          row([
            Text(cfDateOr(r.date, '--'), style: cell),
            Text(r.reference ?? '--', style: cell),
            Text(r.type ?? '--', style: cell),
            Text(_amount(r.amount), style: cell),
            Text(cfMoney(r.available), style: cell),
          ]),
      ],
    );
  }

  Widget _cards(List<CfUtilizationRow> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in rows)
            _Panel(
              header: LcInfoItem(label: 'Transaction Type', value: r.type ?? '--'),
              child: LcInfoGrid(items: [
                ('Date', cfDateOr(r.date, '--')),
                ('Reference Number', r.reference ?? '--'),
                ('Amount', _amount(r.amount)),
                ('Available Amount', cfMoney(r.available)),
              ]),
            ),
        ],
      );
}
