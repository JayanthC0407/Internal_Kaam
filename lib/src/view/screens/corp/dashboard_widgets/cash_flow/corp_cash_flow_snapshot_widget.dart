import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// OBDX `cash-flow-snapshot` — today's money in and out of the current
/// accounts, and the net.
///
/// Shows [CorpCashFlowSampleData.today] until live data is passed as
/// [data].
class CorpCashFlowSnapshotWidget extends StatelessWidget {
  const CorpCashFlowSnapshotWidget({super.key, this.data});

  final CorpCashFlowDay? data;

  @override
  Widget build(BuildContext context) {
    final day = data ?? CorpCashFlowSampleData.today;
    final isSample = data == null;
    const symbol = CorpCashFlowSampleData.currencySymbol;
    String money(double v) =>
        CorpFigures.compact(v, symbol: symbol, precise: true);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = CorpWidgetLayout.isCompact(constraints);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: compact ? 'Today Cashflow' : 'Today Cashflow Snapshot',
                compact: compact,
                sample: isSample,
                subtitle: CorpSubtitle(
                  compact
                      ? CorpFigures.date(day.date)
                      : '${CorpFigures.date(day.date)} • Current account '
                          'activity',
                ),
              ),
              const SizedBox(height: 14),
              CorpStatRow(
                minTileWidth: 120,
                gap: compact ? 8 : 12,
                tiles: [
                  CorpStatTile(
                    label: compact ? 'Inflow' : 'Total Inflow',
                    value: money(day.inflow),
                    valueSize: compact ? 17 : 21,
                  ),
                  CorpStatTile(
                    label: compact ? 'Outflow' : 'Total Outflow',
                    value: money(day.outflow),
                    tone: CorpTone.red,
                    valueSize: compact ? 17 : 21,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CorpHighlightPanel(
                label: 'Net Cashflow',
                value: CorpFigures.signedCompact(day.net, symbol: symbol),
                tone: day.net >= 0 ? CorpTone.green : CorpTone.red,
                stacked: compact,
                detail: compact
                    ? '${day.inflowCount} in • ${day.outflowCount} out • '
                        '${day.pendingCount} pending'
                    : '${day.inflowCount} inflows • ${day.outflowCount} '
                        'outflows • ${day.pendingCount} pending',
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: CorpWidgetLink(
                  label: 'View transactions',
                  onTap: isSample
                      ? () => showCorpSampleDataNotice(
                            context,
                            "Today's transactions",
                          )
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
