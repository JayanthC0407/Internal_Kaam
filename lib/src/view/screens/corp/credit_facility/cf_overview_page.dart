import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Credit Facility Management ▸ Overview — OBDX's `credit-facility` module
/// dashboard: the widgets the server layout lists (card §3.1), each from
/// `components/widgets/credit-facility/`. Synopsis widgets sit side by
/// side on wide screens; allocation widgets take the full width.
class CfOverviewPage extends ConsumerWidget {
  const CfOverviewPage({
    super.key,
    this.onFacilitySummary,
    this.onCollateralSummary,
    this.onFacility,
    this.onCollateral,
  });

  /// View Details / the name links; null when the user may not open that
  /// screen, which hides the link.
  final VoidCallback? onFacilitySummary;
  final VoidCallback? onCollateralSummary;
  final ValueChanged<String>? onFacility;
  final ValueChanged<String>? onCollateral;

  /// Width from which synopsis widgets pair up.
  static const pairWidth = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(builder: (context, box) {
      final breakpoint = DashboardBreakpoint.forWidth(MediaQuery.sizeOf(context).width);
      final layout = ref.watch(cfOverviewLayoutProvider(breakpoint));
      if (layout.isLoading && !layout.hasValue) {
        return const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()));
      }
      final widgets = layout.valueOrNull ?? CfOverviewWidget.values;
      Widget build(CfOverviewWidget w) => switch (w) {
            CfOverviewWidget.facilitySynopsis => _FacilitySynopsis(onViewDetails: onFacilitySummary),
            CfOverviewWidget.collateralSynopsis => _CollateralSynopsis(onViewDetails: onCollateralSummary),
            CfOverviewWidget.facilityAllocation => _FacilityAllocation(onOpen: onFacility),
            CfOverviewWidget.collateralAllocation => _CollateralAllocation(onOpen: onCollateral),
          };
      bool isSynopsis(CfOverviewWidget w) =>
          w == CfOverviewWidget.facilitySynopsis || w == CfOverviewWidget.collateralSynopsis;

      final children = <Widget>[];
      for (var i = 0; i < widgets.length; i++) {
        final w = widgets[i];
        final next = i + 1 < widgets.length ? widgets[i + 1] : null;
        if (box.maxWidth >= pairWidth && isSynopsis(w) && next != null && isSynopsis(next)) {
          children.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: build(w)), const SizedBox(width: 14), Expanded(child: build(next))],
          ));
          i++;
        } else {
          children.add(build(w));
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 14), c],
        ],
      );
    });
  }
}

String _money(double amount, String? currency) => cfMoney(MoneyAmount(amount: amount, currency: currency));

String _utilized(double pct) => '${pct == pct.roundToDouble() ? pct.round() : pct} % Utilized';

/// Loading, failure and "nothing to show" for one widget's data.
Widget _load<T>(
  AsyncValue<T> async, {
  required String failed,
  required VoidCallback onRetry,
  required Widget Function(T) data,
}) =>
    async.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => CfFailed(message: cfError(e, failed), onRetry: onRetry),
      data: data,
    );

// ---------------------------------------------------------------- synopsis

class _FacilitySynopsis extends ConsumerWidget {
  const _FacilitySynopsis({this.onViewDetails});

  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SynopsisCard(
        title: 'Credit Facility',
        onViewDetails: onViewDetails,
        body: _load(
          ref.watch(cfOverviewFacilitiesProvider),
          failed: 'We couldn\'t load the facilities.',
          onRetry: () => ref.invalidate(cfOverviewFacilitiesProvider),
          data: (rows) => _SynopsisBody(synopsis: CfSynopsis.facilities(rows), totalLabel: 'Sanctioned Amount'),
        ),
      );
}

class _CollateralSynopsis extends ConsumerWidget {
  const _CollateralSynopsis({this.onViewDetails});

  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SynopsisCard(
        title: 'Collateral',
        onViewDetails: onViewDetails,
        body: _load(
          ref.watch(cfOverviewCollateralsProvider),
          failed: 'We couldn\'t load the collaterals.',
          onRetry: () => ref.invalidate(cfOverviewCollateralsProvider),
          data: (rows) => _SynopsisBody(synopsis: CfSynopsis.collaterals(rows), totalLabel: 'Collateral Amount'),
        ),
      );
}

/// facility-synopsis / collateral-synopsis: the header with View Details
/// over [body] (the figures, or loading / failure).
class _SynopsisCard extends StatelessWidget {
  const _SynopsisCard({required this.title, required this.body, this.onViewDetails});

  final String title;
  final Widget body;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpWidgetHeader(
            title: title,
            trailing: onViewDetails == null ? null : CorpWidgetLink(label: 'View Details', onTap: onViewDetails),
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

/// The three local-currency figures and the "Utilized Status" meter.
class _SynopsisBody extends StatelessWidget {
  const _SynopsisBody({required this.synopsis, required this.totalLabel});

  final CfSynopsis? synopsis;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final s = synopsis;
    // OBDX renders an empty body when there are no rows.
    if (s == null) return const LcEmptyState(icon: Icons.inbox_outlined, title: 'Nothing to show.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcInfoGrid(items: [
          (totalLabel, _money(s.total, s.currency)),
          ('Utilized Amount', _money(s.utilized, s.currency)),
          ('Available Amount', _money(s.available, s.currency)),
        ]),
        const SizedBox(height: 14),
        _UtilizedMeter(utilized: s.utilizedPercent, available: s.availablePercent),
      ],
    );
  }
}

/// "Utilized Status": OBDX's horizontal status meter — the utilized part in
/// red (#B71C1C) on a green (#008A25) track, "{n}%" at either end.
class _UtilizedMeter extends StatelessWidget {
  const _UtilizedMeter({required this.utilized, required this.available});

  final int utilized;
  final int available;

  static const _used = Color(0xFFB71C1C);
  static const _free = Color(0xFF008A25);

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context));
    return Semantics(
      label: 'Utilized Status: $utilized% utilized, $available% available',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Utilized Status', style: style),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('$utilized%', style: style.copyWith(color: _used)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (utilized / 100).clamp(0, 1).toDouble(),
                    minHeight: 10,
                    color: _used,
                    backgroundColor: _free,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$available%', style: style.copyWith(color: _free)),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- allocation

class _FacilityAllocation extends ConsumerWidget {
  const _FacilityAllocation({this.onOpen});

  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AllocationCard<CfFacility>(
        title: 'Facility Allocation',
        ownCurrencyLabel: 'Facility Currency',
        centreLabel: 'Sanctioned Amount',
        nameLabel: 'Facility Name',
        nameOf: (f) => f.lineCode,
        onOpen: onOpen == null ? null : (f) => onOpen!(f.key),
        percentOf: (f) => f.utilizedPercent,
        columns: [
          _Col('Sanctioned Amount', (f, lc) => lc ? f.effectiveBase : f.effectiveAmount),
          _Col('Utilized Amount', (f, lc) => lc ? f.utilizedBase : f.utilizedAmount),
          _Col('Available Amount', (f, lc) => lc ? f.availableBase : f.availableAmount),
        ],
        async: ref.watch(cfOverviewFacilitiesProvider).whenData(CfAllocation.facilities),
        failed: 'We couldn\'t load the facilities.',
        onRetry: () => ref.invalidate(cfOverviewFacilitiesProvider),
      );
}

class _CollateralAllocation extends ConsumerWidget {
  const _CollateralAllocation({this.onOpen});

  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AllocationCard<CfCollateral>(
        title: 'Collateral Category Allocation',
        ownCurrencyLabel: 'Collateral Currency',
        centreLabel: 'Collateral Amount (After Haircut)',
        nameLabel: 'Collateral Name',
        nameOf: (c) => c.code,
        onOpen: onOpen == null ? null : (c) => onOpen!(c.code),
        percentOf: (c) => c.allocationUtilizedPercent,
        columns: [
          _Col('Utilized Amount', (c, lc) => lc ? c.utilizationBase : c.utilization),
          _Col('Available Amount', (c, lc) => lc ? c.availableBase : c.availableAmount),
          _Col.date('Revision Date', (c) => c.startDate),
        ],
        async: ref.watch(cfOverviewCollateralsProvider).whenData(CfAllocation.collaterals),
        failed: 'We couldn\'t load the collaterals.',
        onRetry: () => ref.invalidate(cfOverviewCollateralsProvider),
      );
}

/// A table column of an allocation widget: an amount in its own or local
/// currency, or a date.
class _Col<T> {
  const _Col(this.label, MoneyAmount? Function(T row, bool local) money)
      : _money = money,
        _date = null;

  const _Col.date(this.label, DateTime? Function(T row) date)
      : _date = date,
        _money = null;

  final String label;
  final MoneyAmount? Function(T, bool)? _money;
  final DateTime? Function(T)? _date;

  String text(T row, bool local) =>
      _date != null ? cfDateOr(_date(row), '--') : cfMoney(_money!(row, local));

  Comparable<dynamic> sortKey(T row, bool local) => _date != null
      ? (_date(row)?.millisecondsSinceEpoch ?? 0)
      : (_money!(row, local)?.amount ?? 0);
}

/// facility-allocation / collateral-allocation: the currency toggle, the
/// donut of category totals (local currency) with the grand total in the
/// centre, the category tabs with their share, and the selected category's
/// rows — a sortable table on wide cards, cards below.
class _AllocationCard<T> extends StatefulWidget {
  const _AllocationCard({
    super.key,
    required this.title,
    required this.ownCurrencyLabel,
    required this.centreLabel,
    required this.nameLabel,
    required this.nameOf,
    required this.percentOf,
    required this.columns,
    required this.async,
    required this.failed,
    required this.onRetry,
    this.onOpen,
  });

  final String title;
  final String ownCurrencyLabel;
  final String centreLabel;
  final String nameLabel;
  final String Function(T) nameOf;
  final double Function(T) percentOf;
  final List<_Col<T>> columns;
  final AsyncValue<CfAllocation<T>?> async;
  final String failed;
  final VoidCallback onRetry;
  final ValueChanged<T>? onOpen;

  /// Card width from which the rows are a table.
  static const tableWidth = 720.0;

  @override
  State<_AllocationCard<T>> createState() => _AllocationCardState<T>();
}

class _AllocationCardState<T> extends State<_AllocationCard<T>> {
  int _slice = 0;

  /// OBDX's default is the facility / collateral currency (`CC`).
  bool _local = false;

  /// Sorted column: -1 none, 0 name, 1.. [widget.columns], then status.
  int _sort = -1;
  bool _ascending = true;

  static const _palette = [
    CorpChartColors.primary,
    CorpChartColors.deep,
    CorpChartColors.mint,
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    CorpChartColors.light,
    Color(0xFFEF4444),
  ];

  Color _color(int i) => _palette[i % _palette.length];

  List<T> _sorted(List<T> rows) {
    if (_sort < 0) return rows;
    final cols = widget.columns.length;
    Comparable<dynamic> key(T r) => _sort == 0
        ? widget.nameOf(r)
        : _sort <= cols
            ? widget.columns[_sort - 1].sortKey(r, _local)
            : widget.percentOf(r);
    final out = [...rows]..sort((a, b) => key(a).compareTo(key(b)));
    return _ascending ? out : out.reversed.toList();
  }

  void _onSort(int column, bool ascending) => setState(() {
        _sort = column;
        _ascending = ascending;
      });

  @override
  Widget build(BuildContext context) {
    return CorpCardShell(
      child: LayoutBuilder(builder: (context, box) {
        final compact = CorpWidgetLayout.isCompact(box);
        Widget toggle(bool expand) => CorpSegmentedToggle<bool>(
              options: {false: widget.ownCurrencyLabel, true: 'Local Currency'},
              value: _local,
              expand: expand,
              onChanged: (v) => setState(() => _local = v),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The currency toggle sits beside the title on wide cards and
            // on its own full-width row on compact ones.
            CorpWidgetHeader(title: widget.title, compact: compact, trailing: compact ? null : toggle(false)),
            if (compact) ...[const SizedBox(height: 10), toggle(true)],
            const SizedBox(height: 14),
            _load<CfAllocation<T>?>(
              widget.async,
              failed: widget.failed,
              onRetry: widget.onRetry,
              data: (a) {
                // OBDX renders nothing when there are no rows.
                if (a == null) {
                  return const LcEmptyState(icon: Icons.donut_large_rounded, title: 'Nothing to show.');
                }
                final slice = a.slices[_slice.clamp(0, a.slices.length - 1)];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _chart(context, a, compact),
                    const SizedBox(height: 14),
                    _tabs(context, a, compact),
                    const SizedBox(height: 14),
                    if (box.maxWidth >= _AllocationCard.tableWidth)
                      _table(context, _sorted(slice.rows))
                    else
                      for (final r in _sorted(slice.rows)) _rowCard(context, r),
                  ],
                );
              },
            ),
          ],
        );
      }),
    );
  }

  Widget _chart(BuildContext context, CfAllocation<T> a, bool compact) {
    final donut = CorpDonut(
      size: 150,
      segments: [
        for (final (i, s) in a.slices.indexed) CorpDonutSegment(value: s.total, color: _color(i)),
      ],
      center: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.centreLabel,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: CorpColors.textSecondary(context))),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(_money(a.total, a.currency),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CorpChartColors.figure(context))),
            ),
          ],
        ),
      ),
    );
    final caption = Text('*Equivalent Local Currency',
        style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: CorpColors.textSecondary(context)));
    return Column(children: [donut, const SizedBox(height: 6), caption]);
  }

  /// The category tabs: a row on wide cards, full-width rows on compact
  /// ones (OBDX's nav-bar is horizontal on large screens only).
  Widget _tabs(BuildContext context, CfAllocation<T> a, bool compact) {
    Widget tab(int i, CfAllocationSlice<T> s) {
      final selected = i == _slice;
      final brand = CorpColors.brand(context);
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _slice = i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? brand.withValues(alpha: 0.10) : null,
            border: Border.all(color: selected ? brand : CorpColors.divider(context)),
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
            children: [
              CorpLegendDot(color: _color(i), label: s.category.isEmpty ? '--' : s.category),
              const SizedBox(width: 10),
              if (compact) const Spacer(),
              Text(cfPercent(s.share),
                  style: TextStyle(fontWeight: FontWeight.w700, color: selected ? brand : CorpColors.textPrimary(context))),
            ],
          ),
        ),
      );
    }

    final tabs = [for (final (i, s) in a.slices.indexed) tab(i, s)];
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final t in tabs) Padding(padding: const EdgeInsets.only(bottom: 8), child: t)],
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: tabs);
  }

  Widget _name(T row) => CfLink(
        label: widget.nameOf(row),
        size: 13.5,
        onTap: widget.onOpen == null ? null : () => widget.onOpen!(row),
      );

  Widget _status(BuildContext context, T row) {
    final pct = widget.percentOf(row);
    return SizedBox(width: 210, child: CfUtilizedBar(percent: pct, label: _utilized(pct)));
  }

  Widget _table(BuildContext context, List<T> rows) {
    final cols = widget.columns;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sort < 0 ? null : _sort,
        sortAscending: _ascending,
        headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context), fontSize: 12.5),
        columns: [
          DataColumn(label: Text(widget.nameLabel), onSort: _onSort),
          for (final c in cols) DataColumn(label: Text(c.label), onSort: _onSort),
          DataColumn(label: const Text('Utilization Status'), onSort: _onSort),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(_name(r)),
              for (final c in cols) DataCell(Text(c.text(r, _local))),
              DataCell(_status(context, r)),
            ]),
        ],
      ),
    );
  }

  Widget _rowCard(BuildContext context, T row) => CfPanel(
        header: _name(row),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LcInfoGrid(items: [for (final c in widget.columns) (c.label, c.text(row, _local))]),
            const SizedBox(height: 10),
            CfUtilizedBar(percent: widget.percentOf(row), label: _utilized(widget.percentOf(row))),
          ],
        ),
      );
}
