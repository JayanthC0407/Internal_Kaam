import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:demo_bank/src/core/models/common/money_amount.dart';
import 'package:demo_bank/src/core/models/corp/liquidity_overview_models.dart';
import 'package:demo_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:demo_bank/src/infra/network/response_handler.dart';
import 'package:demo_bank/src/view/providers/corp/corp_liquidity_providers.dart';
import 'package:demo_bank/src/view/screens/corp/corp_colors.dart';
import 'package:demo_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/dashboard_widgets/common/corp_bar_chart.dart';
import 'package:demo_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:demo_bank/src/view/screens/corp/liquidity/lm_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// The Overview's sweep widgets: Top 5 Cross Currency Sweeps, Top 5
/// Sweeps and Sweep Monitor (card §7, §8).

String _date(DateTime? d) => cfDateOr(d, '--');

String _time(DateTime? d) =>
    d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

TextStyle _head(BuildContext context) =>
    TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context), fontSize: 12.5);

/// The two Top 5 widgets: a currency select over [build]'s rows for it.
class _TopSweeps extends ConsumerStatefulWidget {
  const _TopSweeps({required this.cross, required this.title, required this.label, required this.build});

  final bool cross;
  final String Function(String? currency) title;
  final String label;
  final Widget Function(BuildContext, List<LmSweepLog>) build;

  @override
  ConsumerState<_TopSweeps> createState() => _TopSweepsState();
}

class _TopSweepsState extends ConsumerState<_TopSweeps> {
  String? _currency;

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(lmSweepCurrenciesProvider);
    final currency = _currency ?? setup.valueOrNull?.defaultCurrency;
    return LmWidgetCard(
      title: widget.title(currency),
      child: lmLoad(
        setup,
        failed: 'We couldn\'t load the currencies.',
        onRetry: () => ref.invalidate(lmSweepCurrenciesProvider),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LmCurrencyField(
              label: widget.label,
              currencies: s.currencies,
              selected: currency,
              onSelected: (c) => setState(() => _currency = c),
            ),
            const SizedBox(height: 12),
            if (currency != null)
              lmLoad(
                ref.watch(lmTopSweepsProvider((currency: currency, cross: widget.cross))),
                failed: 'We couldn\'t load the sweeps.',
                onRetry: () => ref.invalidate(lmTopSweepsProvider((currency: currency, cross: widget.cross))),
                data: (rows) => widget.build(context, rows),
              ),
          ],
        ),
      ),
    );
  }
}

/// Top 5 Cross Currency Sweeps (`cross-border-sweeps`).
class LmCrossBorderSweeps extends StatelessWidget {
  const LmCrossBorderSweeps({super.key});

  @override
  Widget build(BuildContext context) => _TopSweeps(
        cross: true,
        title: (_) => 'Top 5 Cross Currency Sweeps',
        label: 'Currency Selector',
        build: (context, rows) {
          if (rows.isEmpty) {
            return const LmEmpty(
              title: 'No Cross Currency Sweeps Available',
              subtitle: 'Check this section for cross border currency sweeps',
              icon: Icons.currency_exchange_rounded,
            );
          }
          return LayoutBuilder(
            builder: (context, box) => box.maxWidth >= lmTableWidth
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: _head(context),
                      columns: const [
                        DataColumn(label: Text('Structure')),
                        DataColumn(label: Text('Sweep Out'), numeric: true),
                        DataColumn(label: Text('Sweep In'), numeric: true),
                        DataColumn(label: Text('Exchange Rate')),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(cells: [
                            DataCell(Text(r.structureId ?? '--')),
                            DataCell(Text(cfMoney(r.outAmount))),
                            DataCell(Text(cfMoney(r.inAmount))),
                            DataCell(Text(r.exchangeRate ?? '--')),
                          ]),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final r in rows)
                        CfPanel(
                          header: Text(r.structureId ?? '--',
                              style: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
                          child: LcInfoGrid(items: [
                            ('Sweep Out', cfMoney(r.outAmount)),
                            ('Sweep In', cfMoney(r.inAmount)),
                            ('Exchange Rate', r.exchangeRate ?? '--'),
                          ]),
                        ),
                    ],
                  ),
          );
        },
      );
}

/// Top 5 Sweeps (`top-five-sweeps`): the five largest sweeps in, one bar
/// per structure, OBDX's colour.
class LmTopFiveSweeps extends StatelessWidget {
  const LmTopFiveSweeps({super.key});

  static const barColor = Color(0xFF006AB5);

  @override
  Widget build(BuildContext context) => _TopSweeps(
        cross: false,
        title: (c) => 'Top 5 Sweeps in ${c ?? ''}'.trim(),
        label: 'Currency',
        build: (context, rows) {
          if (rows.isEmpty) {
            return const LmEmpty(
              title: 'No Top Five Sweeps Available.',
              subtitle: 'Check this section for top five sweeps.',
              icon: Icons.bar_chart_rounded,
            );
          }
          final currency = rows.first.inAmount?.currency;
          return CorpBarChart(
            labels: [for (final r in rows) r.structureId ?? '--'],
            detailLabels: [for (final r in rows) 'Structure Id: ${r.structureId ?? '--'}'],
            series: [
              CorpBarSeries(label: 'Amount:', color: barColor, values: [for (final r in rows) r.inAmount?.amount ?? 0]),
            ],
            valueLabel: (v) => cfMoney(MoneyAmount(amount: v, currency: currency)),
          );
        },
      );
}

/// Sweep Monitor (`sweep-log`): the first five sweeps of the chosen
/// status; refresh and Download (PDF / CSV) when there are rows; View All
/// opens Log Monitors in OBDX (not built here).
class LmSweepMonitor extends ConsumerStatefulWidget {
  const LmSweepMonitor({super.key});

  @override
  ConsumerState<LmSweepMonitor> createState() => _LmSweepMonitorState();
}

/// A Sweep Monitor column: header, cell text (or widget) and sort key.
typedef _Col = ({String label, Widget Function(BuildContext, LmSweepLog) cell, Comparable<dynamic> Function(LmSweepLog) key});

class _LmSweepMonitorState extends ConsumerState<LmSweepMonitor> {
  LmSweepStatus _status = LmSweepStatus.upcoming;
  int? _sort;
  bool _ascending = true;
  bool _downloading = false;

  Widget _twoLines(BuildContext context, String first, String? second) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(first),
          if (second != null && second.isNotEmpty)
            Text(second, style: TextStyle(fontSize: 12, color: CorpColors.textSecondary(context))),
        ],
      );

  /// OBDX's columns for the tab (sweep-log/hooks.js:90-160).
  List<_Col> _columns(Map<String, String> structures) {
    _Col text(String label, String? Function(LmSweepLog) v) =>
        (label: label, cell: (_, r) => Text(v(r) ?? '--'), key: (r) => v(r) ?? '');
    _Col account(String label, String? Function(LmSweepLog) number, String? Function(LmSweepLog) name) => (
          label: label,
          cell: (c, r) => _twoLines(c, number(r) ?? '--', name(r)),
          key: (r) => number(r) ?? '',
        );
    _Col money(String label, MoneyAmount? Function(LmSweepLog) v) =>
        (label: label, cell: (_, r) => Text(cfMoney(v(r))), key: (r) => v(r)?.amount ?? 0);
    final common = <_Col>[
      (
        label: 'Date & Time',
        cell: (c, r) => _twoLines(c, _date(r.valueDate), _time(r.valueDate)),
        key: (r) => r.valueDate?.millisecondsSinceEpoch ?? 0,
      ),
      (
        label: 'Structure Details',
        cell: (c, r) => _twoLines(c, r.structureId ?? '--', structures[r.structureId]),
        key: (r) => r.structureId ?? '',
      ),
      text('Instruction Description', (r) => r.instructionDescription ?? '-'),
    ];
    return switch (_status) {
      LmSweepStatus.executed => [
          ...common,
          text('Sweep Type', (r) => r.sweepType),
          account('Sweep Out Account', (r) => r.outAccount, (r) => r.outAccountName),
          money('Sweep Out Amount', (r) => r.outAmount),
          text('Exchange Rate', (r) => r.exchangeRate),
          account('Sweep In Account', (r) => r.inAccount, (r) => r.inAccountName),
          money('Sweep In Amount', (r) => r.inAmount),
        ],
      LmSweepStatus.exception => [
          ...common,
          account('Source Account', (r) => r.outAccount, (r) => r.outAccountName),
          account('Destination Account', (r) => r.inAccount, (r) => r.inAccountName),
          text('Exception Message', (r) => r.exceptionMessage),
        ],
      _ => [
          ...common,
          account('Source Account', (r) => r.outAccount, (r) => r.outAccountName),
          account('Destination Account', (r) => r.inAccount, (r) => r.inAccountName),
        ],
    };
  }

  Future<void> _download(bool pdf) async {
    setState(() => _downloading = true);
    final result = await ref
        .read(corpLiquidityRepositoryProvider)
        .downloadSweepMonitor(_status, today: ref.read(lmTodayProvider), pdf: pdf);
    if (!mounted) return;
    final name = 'SweepMonitor.${pdf ? 'pdf' : 'csv'}';
    if (result is Success<List<int>> && result.data != null) {
      try {
        await StatementFileSaver.saveStatement(
            bytes: result.data!, fileName: name, mimeType: pdf ? 'application/pdf' : 'text/csv');
        if (mounted) cfSnack(context, 'Downloaded $name');
      } catch (_) {
        if (mounted) cfSnack(context, 'Could not save the file.');
      }
    } else {
      final message = result is Error<List<int>> ? result.error : null;
      cfSnack(context, message?.trim().isNotEmpty == true ? message! : 'Could not download the file.');
    }
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lmSweepMonitorProvider(_status));
    final hasRows = async.valueOrNull?.isNotEmpty == true;
    final structures = ref.watch(lmStructuresProvider).valueOrNull ?? const {};
    return LmWidgetCard(
      title: 'Sweep Monitor',
      trailing: hasRows
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Click here to refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => ref.invalidate(lmSweepMonitorProvider(_status)),
              ),
              PopupMenuButton<bool>(
                tooltip: 'Download',
                enabled: !_downloading,
                onSelected: _download,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: true, child: Text('PDF')),
                  PopupMenuItem(value: false, child: Text('CSV')),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _downloading
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded),
                ),
              ),
            ])
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CorpSegmentedToggle<LmSweepStatus>(
              options: {for (final s in LmSweepStatus.values) s: s.label},
              value: _status,
              onChanged: (s) {
                // OBDX disables the buttons while a tab loads.
                if (async.isLoading) return;
                setState(() {
                  _status = s;
                  _sort = null;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          lmLoad(
            async,
            failed: 'We couldn\'t load the sweeps.',
            onRetry: () => ref.invalidate(lmSweepMonitorProvider(_status)),
            data: (rows) {
              // OBDX shows an empty list on errors too.
              if (rows.isEmpty) {
                return const LmEmpty(
                  title: 'No New Sweeps',
                  subtitle: 'Check this section for sweep details',
                  icon: Icons.sync_alt_rounded,
                );
              }
              final columns = _columns(structures);
              final sorted = [...rows];
              if (_sort case final i?) {
                sorted.sort((a, b) => columns[i].key(a).compareTo(columns[i].key(b)));
                if (!_ascending) sorted.setAll(0, sorted.reversed.toList());
              }
              return LayoutBuilder(
                builder: (context, box) => box.maxWidth >= lmTableWidth
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: _sort,
                          sortAscending: _ascending,
                          headingTextStyle: _head(context),
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 64,
                          columns: [
                            for (final c in columns)
                              DataColumn(
                                label: Text(c.label),
                                onSort: (i, a) => setState(() {
                                  _sort = i;
                                  _ascending = a;
                                }),
                              ),
                          ],
                          rows: [
                            for (final r in sorted) DataRow(cells: [for (final c in columns) DataCell(c.cell(context, r))]),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final r in sorted)
                            CfPanel(
                              header: columns.first.cell(context, r),
                              child: Wrap(
                                spacing: 20,
                                runSpacing: 10,
                                children: [
                                  for (final c in columns.skip(1))
                                    SizedBox(
                                      width: 150,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.label, style: _head(context)),
                                          const SizedBox(height: 2),
                                          c.cell(context, r),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
              );
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Tooltip(
              message: 'Click here to view all sweep logs',
              child: TextButton(
                // Log Monitors is out of scope (card §1).
                onPressed: () => cfSnack(context, 'This feature will be available soon.'),
                child: const Text('View All'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
