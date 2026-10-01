import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

enum _View { tabular, graphical }

/// OBDX `loans-overview` — the design's "Loan and Finance Summary": every
/// loan and finance account, searchable, as a table or as bars.
///
/// Full width on the dashboard: a table of eight columns is unreadable at
/// half. Below [_tableBelow] it lists cards instead, as on a phone.
///
/// Shows [CorpLoanSampleData.accounts] until live data is passed as
/// [accounts].
class CorpLoansOverviewWidget extends StatefulWidget {
  const CorpLoansOverviewWidget({super.key, this.accounts});

  final List<CorpLoanAccountRow>? accounts;

  @override
  State<CorpLoansOverviewWidget> createState() =>
      _CorpLoansOverviewWidgetState();
}

const double _tableBelow = 720;

String _money(BuildContext context, double v) =>
    CorpFigures.compact(v, symbol: CorpCurrency.of(context));

class _CorpLoansOverviewWidgetState extends State<CorpLoansOverviewWidget> {
  final _search = TextEditingController();
  var _view = _View.tabular;

  /// Product filter; null is every product.
  String? _product;

  bool get _isSample => widget.accounts == null;

  List<CorpLoanAccountRow> get _all =>
      widget.accounts ?? CorpLoanSampleData.accounts;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CorpLoanAccountRow> get _visible {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final row in _all)
        if ((_product == null || row.product == _product) &&
            (query.isEmpty ||
                row.name.toLowerCase().contains(query) ||
                row.party.toLowerCase().contains(query)))
          row,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final visible = _visible;
    final financed = all.fold<double>(0, (s, r) => s + r.amountFinanced);
    final outstanding = all.fold<double>(0, (s, r) => s + r.outstanding);
    DateTime? nextMaturity;
    for (final r in all) {
      final m = r.maturity;
      if (m != null && (nextMaturity == null || m.isBefore(nextMaturity))) {
        nextMaturity = m;
      }
    }

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < _tableBelow;
          final compact = CorpWidgetLayout.isCompact(constraints);
          final tools = CorpTableTools<String>(
            controller: _search,
            hint: 'Search account / party',
            filter: _product,
            filters: {
              null: 'All products',
              for (final p in {for (final r in all) r.product}.toList()..sort())
                p: p,
            },
            filterTooltip: 'Filter by product',
            iconsOnly: narrow,
            onSearch: () => setState(() {}),
            onFilter: (value) => setState(() => _product = value),
            onDownload: () {
              if (_isSample) showCorpSampleDataNotice(context, 'The download');
            },
          );

          final viewToggle = CorpSegmentedToggle<_View>(
            options: const {
              _View.tabular: 'Tabular',
              _View.graphical: 'Graphical',
            },
            value: _view,
            expand: compact,
            onChanged: (value) => setState(() => _view = value),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: 'Loan and Finance Summary',
                compact: compact,
                sample: _isSample,
                subtitle: const CorpSubtitle(
                  'Overview of active loan and finance accounts',
                ),
                trailing: narrow ? null : tools,
              ),
              if (narrow) ...[const SizedBox(height: 12), tools],
              const SizedBox(height: 14),
              CorpStatRow(
                minTileWidth: compact ? 120 : 150,
                gap: compact ? 8 : 10,
                tiles: [
                  CorpStatTile(
                    label: compact ? 'Financed' : 'Total amount financed',
                    value: _money(context, financed),
                  ),
                  CorpStatTile(
                    label: compact ? 'Outstanding' : 'Total outstanding',
                    value: _money(context, outstanding),
                    tone: CorpTone.green,
                  ),
                  CorpStatTile(
                    label: compact ? 'Active' : 'Active accounts',
                    value: '${all.length}',
                    tone: CorpTone.neutral,
                  ),
                  CorpStatTile(
                    label: compact ? 'Next maturity' : 'Next maturity date',
                    value: CorpFigures.dateOr(nextMaturity),
                    tone: CorpTone.amber,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (compact) Expanded(child: viewToggle) else viewToggle,
                  if (!compact) ...[
                    const Spacer(),
                    Text(
                      '${visible.length} of ${all.length} accounts',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CorpColors.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                CorpNoMatch(onClear: _clearFilters)
              else if (_view == _View.graphical)
                _Bars(rows: visible, compact: compact)
              else if (narrow)
                _Cards(rows: visible)
              else
                _AccountsTable(rows: visible),
            ],
          );
        },
      ),
    );
  }

  void _clearFilters() => setState(() {
        _search.clear();
        _product = null;
      });
}

class _AccountsTable extends StatelessWidget {
  const _AccountsTable({required this.rows});

  final List<CorpLoanAccountRow> rows;

  static const _columns = <(String, double, TextAlign)>[
    ('S.No', 0.6, TextAlign.center),
    ('Loan account', 1.6, TextAlign.left),
    ('Party', 1.4, TextAlign.left),
    ('Amount financed', 1.3, TextAlign.right),
    ('Outstanding', 1.2, TextAlign.right),
    ('Maturity', 1.3, TextAlign.center),
    ('Rate', 0.8, TextAlign.center),
    ('Status', 1.0, TextAlign.center),
  ];

  @override
  Widget build(BuildContext context) {
    final head = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: CorpColors.textSecondary(context),
    );
    final cell = TextStyle(
      fontSize: 12.5,
      color: CorpColors.textPrimary(context),
    );

    Widget pad(Widget child, TextAlign align) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Align(
            alignment: switch (align) {
              TextAlign.right => Alignment.centerRight,
              TextAlign.center => Alignment.center,
              _ => Alignment.centerLeft,
            },
            child: child,
          ),
        );

    return Table(
      columnWidths: {
        for (var i = 0; i < _columns.length; i++)
          i: FlexColumnWidth(_columns[i].$2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: corpInsetColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            for (final c in _columns) pad(Text(c.$1, style: head), c.$3),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CorpColors.divider(context)),
              ),
            ),
            children: [
              pad(
                Text(
                  (i + 1).toString().padLeft(2, '0'),
                  style: cell.copyWith(fontWeight: FontWeight.w700),
                ),
                _columns[0].$3,
              ),
              pad(Text(rows[i].name, style: cell), _columns[1].$3),
              pad(Text(rows[i].party, style: cell), _columns[2].$3),
              pad(Text(_money(context, rows[i].amountFinanced), style: cell),
                  _columns[3].$3),
              pad(Text(_money(context, rows[i].outstanding), style: cell),
                  _columns[4].$3),
              pad(Text(CorpFigures.dateOr(rows[i].maturity), style: cell),
                  _columns[5].$3),
              pad(Text(CorpFigures.percentOr(rows[i].rate), style: cell),
                  _columns[6].$3),
              pad(
                CorpStatusChip(label: rows[i].status, tone: CorpTone.green),
                _columns[7].$3,
              ),
            ],
          ),
      ],
    );
  }
}

/// The phone's list: one card per account.
class _Cards extends StatelessWidget {
  const _Cards({required this.rows});

  final List<CorpLoanAccountRow> rows;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 11.5,
      color: CorpColors.textSecondary(context),
    );
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CorpColors.divider(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '${rows[i].name}  ',
                          children: [
                            TextSpan(
                              text: _money(context, rows[i].amountFinanced),
                              style: TextStyle(
                                color: CorpToneColors.of(
                                  context,
                                  CorpTone.blue,
                                ).label,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CorpColors.textPrimary(context),
                        ),
                      ),
                    ),
                    CorpStatusChip(label: rows[i].status, tone: CorpTone.green),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Text(rows[i].party, style: muted)),
                    Text(
                      'Outstanding ${_money(context, rows[i].outstanding)}',
                      style: muted,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Matures ${CorpFigures.dateOr(rows[i].maturity)} • '
                  '${CorpFigures.percentOr(rows[i].rate)}',
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The graphical view: per account, the amount financed as a track and
/// the part still outstanding filled in.
class _Bars extends StatelessWidget {
  const _Bars({required this.rows, required this.compact});

  final List<CorpLoanAccountRow> rows;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final largest = rows.map((r) => r.amountFinanced).fold<double>(0, math.max);
    final label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: CorpColors.textPrimary(context),
    );
    final muted = TextStyle(
      fontSize: 11.5,
      color: CorpColors.textSecondary(context),
    );

    Widget bar(CorpLoanAccountRow row) => LayoutBuilder(
          builder: (context, c) {
            final full =
                largest <= 0 ? 0.0 : c.maxWidth * row.amountFinanced / largest;
            final filled = row.amountFinanced <= 0
                ? 0.0
                : full * row.outstanding / row.amountFinanced;
            return Stack(
              children: [
                Container(
                  height: 12,
                  width: full,
                  decoration: BoxDecoration(
                    color: CorpChartColors.track(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Container(
                  height: 12,
                  width: filled,
                  decoration: BoxDecoration(
                    color: CorpChartColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            );
          },
        );

    return CorpInsetPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows) ...[
            Semantics(
              label:
                  '${row.name}: ${_money(context, row.outstanding)} outstanding '
                  'of ${_money(context, row.amountFinanced)} financed',
              excludeSemantics: true,
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(row.name, style: label)),
                            Text(
                              '${_money(context, row.outstanding)} / ${_money(context, row.amountFinanced)}',
                              style: muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        bar(row),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            row.name,
                            style: label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(child: bar(row)),
                        SizedBox(
                          width: 130,
                          child: Text(
                            '${_money(context, row.outstanding)} / ${_money(context, row.amountFinanced)}',
                            textAlign: TextAlign.right,
                            style: muted,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              const CorpLegendDot(
                color: CorpChartColors.primary,
                label: 'Outstanding',
              ),
              CorpLegendDot(
                color: CorpChartColors.track(context),
                label: 'Repaid',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
