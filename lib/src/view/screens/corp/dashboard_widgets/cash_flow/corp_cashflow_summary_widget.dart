import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// The month's cash position: opening balance, money in and out, closing
/// balance and the net change.
///
/// Registered as `cashflow-summary`, a name of the app's choosing — the
/// OBDX catalog has no component for this design.
///
/// Shows [CorpCashFlowSampleData.month] until live data is passed as
/// [data]; the closing balance and net change are worked out from it.
class CorpCashflowSummaryWidget extends StatelessWidget {
  const CorpCashflowSummaryWidget({super.key, this.data});

  final CorpCashFlowMonth? data;

  @override
  Widget build(BuildContext context) {
    final month = data ?? CorpCashFlowSampleData.month;
    final isSample = data == null;
    const symbol = CorpCashFlowSampleData.currencySymbol;
    String money(double v) => CorpFigures.compact(v, symbol: symbol);
    final rising = month.net >= 0;

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = CorpWidgetLayout.isCompact(constraints);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: 'Cashflow Summary',
                compact: compact,
                sample: isSample,
                subtitle: CorpSubtitle(
                  compact
                      ? CorpFigures.monthYear(month.month)
                      : 'Monthly overview • '
                          '${CorpFigures.monthYear(month.month)}',
                ),
              ),
              const SizedBox(height: 14),
              CorpStatRow(
                minTileWidth: compact ? 120 : 110,
                gap: compact ? 8 : 10,
                tiles: [
                  CorpStatTile(
                    label: compact ? 'Opening' : 'Opening balance',
                    value: money(month.openingBalance),
                    tone: CorpTone.neutral,
                  ),
                  CorpStatTile(
                    label: compact ? 'Inflow' : 'Total inflow',
                    value: money(month.inflow),
                  ),
                  CorpStatTile(
                    label: compact ? 'Outflow' : 'Total outflow',
                    value: money(month.outflow),
                    tone: CorpTone.red,
                  ),
                  CorpStatTile(
                    label: compact ? 'Closing' : 'Closing balance',
                    value: money(month.closingBalance),
                    tone: CorpTone.green,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CorpHighlightPanel(
                label: 'Net change',
                value: CorpFigures.signedCompact(month.net, symbol: symbol),
                tone: rising ? CorpTone.green : CorpTone.red,
                stacked: compact,
                detail: compact
                    ? '${month.inflowCount} in • ${month.outflowCount} out • '
                        '${month.pendingCount} pending'
                    : rising
                        ? 'Positive movement vs opening balance'
                        : 'Negative movement vs opening balance',
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: CorpWidgetLink(
                  label: 'View detailed cashflow',
                  onTap: isSample
                      ? () => showCorpSampleDataNotice(
                            context,
                            'The detailed cashflow',
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
