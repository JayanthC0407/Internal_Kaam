import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

enum _View { graphical, tabular }

/// Maturity windows the filter offers.
enum _Window {
  days30(30, 'Maturing in 30 days'),
  days90(90, 'Maturing in 90 days');

  const _Window(this.days, this.label);

  final int days;
  final String label;
}

/// OBDX `td-summary` — the term deposit accounts, as a maturity-value
/// chart for one deposit and a table of them all.
///
/// Wide, the chart and the table sit side by side, as in the web design;
/// narrower, a Graphical / Tabular switch shows one at a time, as in the
/// phone design. Full width on the dashboard, for the table.
///
/// Shows [CorpTdSampleData.deposits] until live data is passed as
/// [deposits].
class CorpTdSummaryWidget extends StatefulWidget {
  const CorpTdSummaryWidget({
    super.key,
    this.deposits,
    this.interestEarned,
    this.asOf,
  });

  final List<CorpTermDeposit>? deposits;
  final double? interestEarned;
  final DateTime? asOf;

  @override
  State<CorpTdSummaryWidget> createState() => _CorpTdSummaryWidgetState();
}

/// Width from which the chart and table sit side by side.
const double _sideBySideFrom = 900;

/// Width of the table panel below which it lists cards instead.
const double _tableFrom = 540;

String _money(BuildContext context, double v) =>
    CorpFigures.compact(v, symbol: CorpCurrency.of(context), precise: true);

class _CorpTdSummaryWidgetState extends State<CorpTdSummaryWidget> {
  final _search = TextEditingController();
  var _view = _View.graphical;
  _Window? _window;

  /// The deposit the chart shows; null is the next to mature.
  String? _selectedId;

  bool get _isSample => widget.deposits == null;

  List<CorpTermDeposit> get _all {
    final list = [...(widget.deposits ?? CorpTdSampleData.deposits)];
    // By maturity, deposits with none on record last.
    return list
      ..sort((a, b) {
        final x = a.maturesOn;
        final y = b.maturesOn;
        if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
        return x.compareTo(y);
      });
  }

  DateTime get _today => widget.asOf ?? CorpTdSampleData.asOf;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CorpTermDeposit> _visible(List<CorpTermDeposit> all) {
    final query = _search.text.trim().toLowerCase();
    final window = _window;
    return [
      for (final d in all)
        if ((query.isEmpty || d.id.toLowerCase().contains(query)) &&
            (window == null ||
                (d.maturesOn != null &&
                    !d.maturesOn!
                        .isAfter(_today.add(Duration(days: window.days))))))
          d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final visible = _visible(all);
    final totals = CorpTdTotals.of(all);
    final selected = all.isEmpty
        ? null
        : all.firstWhere(
            (d) => d.id == _selectedId,
            orElse: () => all.first,
          );

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final compact = CorpWidgetLayout.isCompact(constraints);
          final sideBySide = width >= _sideBySideFrom;

          final chart = _ChartPanel(
            deposits: all,
            selected: selected,
            onSelect: (id) => setState(() => _selectedId = id),
          );
          final table = _TablePanel(
            rows: visible,
            selectedId: selected?.id,
            onSelect: (id) => setState(() => _selectedId = id),
            onView: _isSample
                ? () => showCorpSampleDataNotice(context, 'Deposit details')
                : null,
            onClear: _clearFilters,
          );
          final tools = CorpTableTools<_Window>(
            controller: _search,
            hint: 'Search TD account',
            filter: _window,
            filters: {
              null: 'All maturities',
              for (final w in _Window.values) w: w.label,
            },
            filterTooltip: 'Filter by maturity',
            iconsOnly: !sideBySide,
            onSearch: () => setState(() {}),
            onFilter: (value) => setState(() => _window = value),
            onDownload: () {
              if (_isSample) showCorpSampleDataNotice(context, 'The download');
            },
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: 'TD Summary',
                compact: compact,
                sample: _isSample,
                subtitle: const CorpSubtitle('Term deposit accounts overview'),
                trailing: sideBySide ? tools : null,
              ),
              if (!sideBySide) ...[
                const SizedBox(height: 12),
                // On a phone the switch leads, as in the design; the search
                // is there too, for a portfolio longer than the sample's.
                if (compact) ...[
                  _viewToggle(expand: true),
                  const SizedBox(height: 12),
                ],
                tools,
              ],
              const SizedBox(height: 14),
              CorpStatRow(
                minTileWidth: compact ? 120 : 150,
                gap: compact ? 8 : 10,
                maxPerRow: compact ? 2 : null,
                tiles: [
                  CorpStatTile(
                    label: compact ? 'Balance' : 'Total balance',
                    value: _money(context, totals.balance),
                  ),
                  CorpStatTile(
                    label: compact ? 'Maturity' : 'Maturity value',
                    value: _money(context, totals.maturityValue),
                    tone: CorpTone.green,
                  ),
                  if (!compact) ...[
                    // Interest earned to date when it is known (the
                    // sample has it); live, the deposit list has no such
                    // figure, so the interest they will pay at maturity.
                    CorpStatTile(
                      label: _isSample || widget.interestEarned != null
                          ? 'Interest earned'
                          : 'Interest at maturity',
                      value: _money(
                        context,
                        widget.interestEarned ??
                            (_isSample
                                ? CorpTdSampleData.interestEarned
                                : totals.maturityValue - totals.balance),
                      ),
                      tone: CorpTone.amber,
                    ),
                    CorpStatTile(
                      label: 'Active TD accounts',
                      value: '${totals.count}',
                      tone: CorpTone.neutral,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (sideBySide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: chart),
                    const SizedBox(width: 12),
                    Expanded(flex: 6, child: table),
                  ],
                )
              else ...[
                if (!compact) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _viewToggle(expand: false),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_view == _View.graphical) chart else table,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _viewToggle({required bool expand}) => CorpSegmentedToggle<_View>(
        options: const {
          _View.graphical: 'Graphical',
          _View.tabular: 'Tabular',
        },
        value: _view,
        expand: expand,
        style: CorpToggleStyle.solid,
        onChanged: (value) => setState(() => _view = value),
      );

  void _clearFilters() => setState(() {
        _search.clear();
        _window = null;
      });
}

/// A titled panel: the "Graphical view" and "Tabular view" boxes.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CorpColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CorpColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CorpColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.deposits,
    required this.selected,
    required this.onSelect,
  });

  final List<CorpTermDeposit> deposits;
  final CorpTermDeposit? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final deposit = selected;
    final picker = deposit == null
        ? null
        : PopupMenuButton<String>(
            tooltip: 'Choose a deposit',
            initialValue: deposit.id,
            onSelected: onSelect,
            itemBuilder: (context) => [
              for (final d in deposits)
                PopupMenuItem(value: d.id, child: Text(d.id)),
            ],
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CorpColors.cardBorder(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    deposit.id,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CorpColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: CorpColors.textSecondary(context),
                  ),
                ],
              ),
            ),
          );

    return _Panel(
      title: 'Graphical view',
      subtitle: 'Maturity value composition',
      trailing: picker,
      child: deposit == null
          ? const SizedBox(height: 120)
          : CorpInsetPanel(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Semantics(
                      label: '${deposit.id}: principal '
                          '${_money(context, deposit.principal)}, interest '
                          '${_money(context, deposit.interest)}',
                      child: CorpDonut(
                        size: 150,
                        strokeWidth: 18,
                        segments: [
                          CorpDonutSegment(
                            value: deposit.principal,
                            color: CorpChartColors.primary,
                          ),
                          CorpDonutSegment(
                            value: deposit.interest,
                            color: CorpChartColors.light,
                          ),
                        ],
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _money(context, deposit.maturityValue),
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: CorpChartColors.figure(context),
                              ),
                            ),
                            Text(
                              'maturity value',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: CorpColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Fact(
                    label: 'Principal',
                    value: _money(context, deposit.principal),
                    tone: CorpTone.blue,
                  ),
                  const SizedBox(height: 4),
                  _Fact(
                    label: 'Interest',
                    value: '${_money(context, deposit.interest)} • '
                        '${CorpFigures.percentOr(deposit.rate)}',
                    tone: CorpTone.green,
                  ),
                  const SizedBox(height: 4),
                  _Fact(
                    label: 'Matures',
                    value: CorpFigures.dateOr(deposit.maturesOn),
                    tone: CorpTone.amber,
                  ),
                ],
              ),
            ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final CorpTone tone;

  @override
  Widget build(BuildContext context) {
    final color = CorpToneColors.of(context, tone).label;
    return Text.rich(
      TextSpan(
        text: '$label  ',
        style: const TextStyle(fontWeight: FontWeight.w500),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      style: TextStyle(fontSize: 12, color: color),
    );
  }
}

class _TablePanel extends StatelessWidget {
  const _TablePanel({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    required this.onView,
    required this.onClear,
  });

  final List<CorpTermDeposit> rows;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onView;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Tabular view',
      subtitle: 'Account-level maturity details',
      child: rows.isEmpty
          ? CorpNoMatch(
              onClear: onClear,
              message: 'No deposits match your search.',
            )
          : LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth < _tableFrom
                      ? _Cards(rows: rows, onView: onView)
                      : _Table(
                          rows: rows,
                          selectedId: selectedId,
                          onSelect: onSelect,
                          onView: onView,
                        ),
            ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    required this.onView,
  });

  final List<CorpTermDeposit> rows;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onView;

  static const _columns = <(String, double, Alignment)>[
    ('TD account', 1.2, Alignment.centerLeft),
    ('Principal', 1.0, Alignment.centerRight),
    ('Rate', 0.8, Alignment.center),
    ('Maturity', 1.3, Alignment.center),
    ('Value', 1.0, Alignment.centerRight),
    ('Status', 1.0, Alignment.center),
    // The row's action; fixed width, see [build].
    ('', 0, Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    final head = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: CorpColors.textSecondary(context),
    );
    final cell = TextStyle(
      fontSize: 12,
      color: CorpColors.textPrimary(context),
    );
    Widget pad(Widget child, int column) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Align(alignment: _columns[column].$3, child: child),
        );

    return Table(
      columnWidths: {
        for (var i = 0; i < _columns.length - 1; i++)
          i: FlexColumnWidth(_columns[i].$2),
        _columns.length - 1: const FixedColumnWidth(44),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: CorpColors.divider(context)),
            ),
          ),
          children: [
            for (var i = 0; i < _columns.length; i++)
              pad(Text(_columns[i].$1, style: head), i),
          ],
        ),
        for (final d in rows)
          TableRow(
            decoration: BoxDecoration(
              // The deposit the chart is showing.
              color:
                  d.id == selectedId ? CorpColors.tableRowHover(context) : null,
              border: Border(
                bottom: BorderSide(color: CorpColors.divider(context)),
              ),
            ),
            children: [
              // Choosing the account shows it in the chart beside.
              TableRowInkWell(
                onTap: () => onSelect(d.id),
                child: pad(
                  Text(
                    d.id,
                    style: cell.copyWith(
                      fontWeight: FontWeight.w600,
                      color: CorpColors.brand(context),
                    ),
                  ),
                  0,
                ),
              ),
              pad(Text(_money(context, d.principal), style: cell), 1),
              pad(Text(CorpFigures.percentOr(d.rate), style: cell), 2),
              pad(Text(CorpFigures.dateOr(d.maturesOn), style: cell), 3),
              pad(Text(_money(context, d.maturityValue), style: cell), 4),
              pad(CorpStatusChip(label: d.status, tone: CorpTone.green), 5),
              IconButton(
                tooltip: 'View ${d.id}',
                onPressed: onView,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: CorpColors.brand(context),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The phone's list: one card per deposit.
class _Cards extends StatelessWidget {
  const _Cards({required this.rows, required this.onView});

  final List<CorpTermDeposit> rows;
  final VoidCallback? onView;

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
          Material(
            color: corpInsetColor(context),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onView,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rows[i].id,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: CorpColors.brand(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_money(context, rows[i].principal)} • '
                            '${CorpFigures.percentOr(rows[i].rate)}',
                            style: muted,
                          ),
                        ),
                        CorpStatusChip(
                          label: rows[i].status,
                          tone: CorpTone.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        text:
                            'Matures ${CorpFigures.dateOr(rows[i].maturesOn)}  ',
                        children: [
                          TextSpan(
                            text: _money(context, rows[i].maturityValue),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: CorpColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      style: muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
