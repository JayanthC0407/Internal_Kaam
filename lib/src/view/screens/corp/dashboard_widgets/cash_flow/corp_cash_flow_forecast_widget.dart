import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_bar_chart.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// The Quick Range choices.
enum CorpCashFlowRange {
  month1('1M'),
  month3('3M'),
  month6('6M'),

  /// From the forecast's start to the end of that calendar year.
  yearToDate('YTD'),
  year1('1Y'),
  custom('Custom');

  const CorpCashFlowRange(this.label);

  final String label;
}

/// OBDX `cash-flow-forecast` — projected inflow and outflow over the
/// forecast period, grouped by quarter, month, week or day, with the
/// lowest balance the projection reaches.
///
/// Full width on the dashboard. Every figure is worked out from one daily
/// series ([CorpCashFlowSeries]), so the tiles, the chart and the range
/// always agree. Shows [CorpCashFlowSampleData.forecast] until live data
/// is passed as [series].
class CorpCashFlowForecastWidget extends StatefulWidget {
  const CorpCashFlowForecastWidget({super.key, this.series});

  final CorpCashFlowSeries? series;

  @override
  State<CorpCashFlowForecastWidget> createState() =>
      _CorpCashFlowForecastWidgetState();
}

/// Width from which the grouping switch sits beside the title.
const double _toolsBesideFrom = 900;

String _money(double v) =>
    CorpFigures.compact(v, symbol: CorpCashFlowSampleData.currencySymbol);

class _CorpCashFlowForecastWidgetState
    extends State<CorpCashFlowForecastWidget> {
  var _grouping = CorpCashFlowGrouping.monthly;
  var _range = CorpCashFlowRange.year1;
  DateTimeRange? _custom;

  CorpCashFlowSeries get _series =>
      widget.series ?? CorpCashFlowSampleData.forecast;

  bool get _isSample => widget.series == null;

  /// The days [_range] covers.
  (DateTime, DateTime) get _window {
    final s = _series;
    DateTime months(int n) => DateTime(s.start.year, s.start.month + n, 0);
    final end = switch (_range) {
      CorpCashFlowRange.month1 => months(1),
      CorpCashFlowRange.month3 => months(3),
      CorpCashFlowRange.month6 => months(6),
      CorpCashFlowRange.yearToDate => DateTime(s.start.year, 12, 31),
      CorpCashFlowRange.year1 => s.end,
      CorpCashFlowRange.custom => _custom?.end ?? s.end,
    };
    final start = _range == CorpCashFlowRange.custom
        ? (_custom?.start ?? s.start)
        : s.start;
    return (start, end.isAfter(s.end) ? s.end : end);
  }

  Future<void> _chooseRange(CorpCashFlowRange range) async {
    if (range != CorpCashFlowRange.custom) {
      setState(() => _range = range);
      return;
    }
    final s = _series;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: s.start,
      lastDate: s.end,
      initialDateRange: _custom ?? DateTimeRange(start: s.start, end: s.end),
      helpText: 'Forecast range',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = CorpCashFlowRange.custom;
      _custom = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;
    final (from, to) = _window;
    final totals = series.totals(from, to);
    final (lowest, lowestOn) = series.lowestBalance(from, to);
    final buckets = series.buckets(from, to, _grouping);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = CorpWidgetLayout.isCompact(constraints);
          final beside = constraints.maxWidth >= _toolsBesideFrom;
          void download() =>
              showCorpSampleDataNotice(context, 'The report download');

          final grouping = CorpSegmentedToggle<CorpCashFlowGrouping>(
            options: const {
              CorpCashFlowGrouping.quarterly: 'Quarterly',
              CorpCashFlowGrouping.monthly: 'Monthly',
              CorpCashFlowGrouping.weekly: 'Weekly',
              CorpCashFlowGrouping.daily: 'Daily',
            },
            value: _grouping,
            expand: !beside,
            style: CorpToggleStyle.solid,
            onChanged: (value) => setState(() => _grouping = value),
          );
          final downloadButton = compact
              ? IconButton(
                  tooltip: 'Download report',
                  onPressed: _isSample ? download : null,
                  icon: Icon(
                    Icons.download_rounded,
                    color: CorpColors.brand(context),
                  ),
                )
              : FilledButton.icon(
                  onPressed: _isSample ? download : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: CorpColors.brand(context),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Report'),
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: 'Cash Flow Forecast',
                compact: compact,
                sample: _isSample,
                subtitle: CorpSubtitle(
                  compact
                      ? '${CorpFigures.shortMonthYear(from)} – '
                          '${CorpFigures.shortMonthYear(to)} • GBP'
                      : 'For the period ${CorpFigures.date(from)} – '
                          '${CorpFigures.date(to)} • Equivalent to local '
                          'currency (GBP)',
                ),
                trailing: beside
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          grouping,
                          const SizedBox(width: 10),
                          downloadButton,
                        ],
                      )
                    : (compact ? downloadButton : null),
              ),
              if (!beside) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: grouping),
                    if (!compact) ...[
                      const SizedBox(width: 10),
                      downloadButton,
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _Figures(
                totals: totals,
                lowest: lowest,
                lowestOn: lowestOn,
                compact: compact,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: CorpColors.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CorpColors.divider(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cash Flow Trend',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CorpColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    CorpBarChart(
                      height: compact ? 190 : 240,
                      // A phone fits a year of months without scrolling.
                      minGroupWidth: compact ? 17 : 22,
                      labels: [
                        for (final b in buckets) _label(b, compact: compact),
                      ],
                      detailLabels: [for (final b in buckets) _detail(b)],
                      series: [
                        CorpBarSeries(
                          label: 'Inflow',
                          color: const Color(0xFF06B6D4),
                          values: [for (final b in buckets) b.inflow],
                        ),
                        CorpBarSeries(
                          label: 'Outflow',
                          color: CorpChartColors.mint,
                          values: [for (final b in buckets) b.outflow],
                        ),
                      ],
                      line: [for (final b in buckets) b.net],
                      lineLabel: compact ? 'Net' : 'Surplus / Deficit',
                      valueLabel: _axisMoney,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _RangePills(
                value: _range,
                custom: _custom,
                onChanged: _chooseRange,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Axis ticks are round numbers: `£2B`, `£50M`, `-£1B`.
  static String _axisMoney(double v) => v == 0
      ? '${CorpCashFlowSampleData.currencySymbol}0'
      : CorpFigures.compact(v, symbol: CorpCashFlowSampleData.currencySymbol)
          .replaceFirst(RegExp(r'\.0+(?=[KMB]$)'), '');

  static String _label(CorpCashFlowBucket b, {required bool compact}) =>
      switch (b.grouping) {
        CorpCashFlowGrouping.monthly => compact
            ? CorpFigures.dayMonth(b.start).substring(3, 4)
            : CorpFigures.dayMonth(b.start).substring(3),
        CorpCashFlowGrouping.quarterly =>
          '${CorpFigures.dayMonth(b.start).substring(3)}–'
              '${CorpFigures.dayMonth(b.end).substring(3)}',
        CorpCashFlowGrouping.weekly => CorpFigures.dayMonth(b.start),
        CorpCashFlowGrouping.daily => '${b.start.day}',
      };

  static String _detail(CorpCashFlowBucket b) => switch (b.grouping) {
        CorpCashFlowGrouping.monthly => CorpFigures.monthYear(b.start),
        CorpCashFlowGrouping.quarterly =>
          '${CorpFigures.shortMonthYear(b.start)} – '
              '${CorpFigures.shortMonthYear(b.end)}',
        CorpCashFlowGrouping.weekly => 'Week of ${CorpFigures.date(b.start)}',
        CorpCashFlowGrouping.daily => CorpFigures.date(b.start),
      };
}

/// "▲ 8.4% vs previous period" — green when the move is good for the
/// business (more in, less out), red when not.
class _Change extends StatelessWidget {
  const _Change({
    required this.percent,
    required this.higherIsBetter,
    this.short = false,
  });

  final double? percent;
  final bool higherIsBetter;

  /// "vs prior" rather than "vs previous period", for a phone's tile.
  final bool short;

  @override
  Widget build(BuildContext context) {
    final p = percent;
    if (p == null) return const SizedBox.shrink();
    final up = p >= 0;
    final good = up == higherIsBetter;
    final color = CorpToneColors.of(
      context,
      good ? CorpTone.green : CorpTone.red,
    ).label;
    // Icons, not ▲ / ▼ characters: the app font may not have them.
    return Row(
      children: [
        Icon(
          up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
          size: 18,
          color: color,
        ),
        Expanded(
          child: Text(
            '${p.abs().toStringAsFixed(1)}% '
            '${short ? 'vs prior' : 'vs previous period'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: color),
          ),
        ),
      ],
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({
    required this.totals,
    required this.lowest,
    required this.lowestOn,
    required this.compact,
  });

  final CorpCashFlowTotals totals;
  final double lowest;
  final DateTime lowestOn;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final inflowChange = _Change(
      percent: CorpCashFlowTotals.change(totals.inflow, totals.previousInflow),
      higherIsBetter: true,
      short: compact,
    );
    final outflowChange = _Change(
      percent:
          CorpCashFlowTotals.change(totals.outflow, totals.previousOutflow),
      higherIsBetter: false,
      short: compact,
    );
    final netChange = _Change(
      percent: CorpCashFlowTotals.change(totals.net, totals.previousNet),
      higherIsBetter: true,
    );
    final netTone = totals.net >= 0 ? CorpTone.green : CorpTone.red;

    if (!compact) {
      return CorpStatRow(
        minTileWidth: 170,
        tiles: [
          CorpStatTile(
            label: 'Total Inflow',
            value: _money(totals.inflow),
            valueSize: 20,
            caption: inflowChange,
          ),
          CorpStatTile(
            label: 'Total Outflow',
            value: _money(totals.outflow),
            tone: CorpTone.red,
            valueSize: 20,
            caption: outflowChange,
          ),
          CorpStatTile(
            label: 'Net Cash Flow',
            value: CorpFigures.signedCompact(
              totals.net,
              symbol: CorpCashFlowSampleData.currencySymbol,
            ),
            tone: netTone,
            valueSize: 20,
            caption: netChange,
          ),
          CorpStatTile(
            label: 'Lowest Projected Balance',
            value: _money(lowest),
            tone: CorpTone.neutral,
            valueSize: 20,
            caption: Text(CorpFigures.shortMonthYear(lowestOn)),
          ),
        ],
      );
    }

    // Phone: inflow and outflow side by side, the net across under them,
    // as in the design; the lowest balance as one line below.
    final net = CorpToneColors.of(context, netTone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorpStatRow(
          gap: 8,
          minTileWidth: 120,
          tiles: [
            CorpStatTile(
              label: 'Total Inflow',
              value: _money(totals.inflow),
              caption: inflowChange,
            ),
            CorpStatTile(
              label: 'Total Outflow',
              value: _money(totals.outflow),
              tone: CorpTone.red,
              caption: outflowChange,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: net.fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: net.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Cash Flow',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: CorpColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    netChange,
                  ],
                ),
              ),
              Text(
                CorpFigures.signedCompact(
                  totals.net,
                  symbol: CorpCashFlowSampleData.currencySymbol,
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: net.label,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Lowest projected balance ${_money(lowest)} • '
          '${CorpFigures.shortMonthYear(lowestOn)}',
          style: TextStyle(
            fontSize: 11.5,
            color: CorpColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

/// The Quick Range pills. They wrap onto a second line on a narrow phone
/// rather than shrinking below a comfortable tap size.
class _RangePills extends StatelessWidget {
  const _RangePills({
    required this.value,
    required this.custom,
    required this.onChanged,
  });

  final CorpCashFlowRange value;
  final DateTimeRange? custom;
  final ValueChanged<CorpCashFlowRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            'Quick Range:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: CorpColors.textPrimary(context),
            ),
          ),
        ),
        for (final range in CorpCashFlowRange.values)
          Semantics(
            button: true,
            selected: range == value,
            child: InkWell(
              onTap: () => onChanged(range),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                // Sized by the label; tall enough to tap comfortably.
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: range == value ? brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  range == CorpCashFlowRange.custom &&
                          value == range &&
                          custom != null
                      ? '${CorpFigures.dayMonth(custom!.start)} – '
                          '${CorpFigures.dayMonth(custom!.end)}'
                      : range.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        range == value ? FontWeight.w700 : FontWeight.w500,
                    color: range == value
                        ? Colors.white
                        : CorpColors.textSecondary(context),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
