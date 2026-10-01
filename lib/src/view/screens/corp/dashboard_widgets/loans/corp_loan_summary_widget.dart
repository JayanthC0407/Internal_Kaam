import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// OBDX `loan-summary` — outstanding balance, next EMI and rate, with a
/// gauge of how much of the loan is still to repay.
///
/// Shows [CorpLoanSampleData.summary] until live data is passed as [data].
class CorpLoanSummaryWidget extends StatelessWidget {
  const CorpLoanSummaryWidget({super.key, this.data});

  final CorpLoanSummaryData? data;

  @override
  Widget build(BuildContext context) {
    final summary = data ?? CorpLoanSampleData.summary;
    final isSample = data == null;
    final symbol = CorpCurrency.of(context);
    String money(double v) => CorpFigures.compact(v, symbol: symbol);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = CorpWidgetLayout.isCompact(constraints);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: 'Loan Summary',
                compact: compact,
                sample: isSample,
                subtitle: CorpSubtitle(
                  'Repayment trend • ${compact ? CorpFigures.shortMonthYear(summary.asOf) : CorpFigures.monthYear(summary.asOf)}',
                ),
              ),
              const SizedBox(height: 14),
              CorpStatRow(
                minTileWidth: compact ? 84 : 120,
                gap: compact ? 8 : 10,
                tiles: [
                  CorpStatTile(
                    label: 'Outstanding',
                    value: money(summary.outstanding),
                  ),
                  CorpStatTile(
                    label: 'Next EMI',
                    value: money(summary.nextEmi),
                    tone: CorpTone.green,
                  ),
                  CorpStatTile(
                    label: compact ? 'Rate' : 'Interest rate',
                    value: summary.interestRate == null
                        ? '—'
                        : CorpFigures.percent(summary.interestRate!),
                    tone: CorpTone.amber,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CorpInsetPanel(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GaugePanel(summary: summary, money: money),
                    const SizedBox(height: 10),
                    Text(
                      'Repayment health',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: CorpColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                        color: CorpColors.card(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Remaining tenure • ${summary.remainingTenureMonths == null ? '—' : CorpFigures.tenure(summary.remainingTenureMonths!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: CorpColors.textSecondary(context),
                              ),
                            ),
                          ),
                          CorpWidgetLink(
                            label: 'View loan details',
                            onTap: isSample
                                ? () => showCorpSampleDataNotice(
                                      context,
                                      'Loan details',
                                    )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GaugePanel extends StatelessWidget {
  const _GaugePanel({required this.summary, required this.money});

  final CorpLoanSummaryData summary;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final percent = (summary.outstandingShare * 100).round();
    final success = CorpToneColors.of(context, CorpTone.green).label;
    final info = CorpToneColors.of(context, CorpTone.blue).label;

    Widget figure(String label, String value, Color color) => Text.rich(
          TextSpan(
            text: '$label  ',
            children: [TextSpan(text: value)],
          ),
          style: TextStyle(fontSize: 12.5, color: color),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Semantics(
            label: '$percent percent of the loan outstanding',
            child: CorpGauge(
              progress: summary.outstandingShare,
              size: 112,
              center: Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: CorpChartColors.figure(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${money(summary.outstanding)} outstanding',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 22,
            runSpacing: 6,
            children: [
              figure('Paid', money(summary.paid), success),
              figure('Remaining', money(summary.outstanding), info),
              figure(
                'Total Loan',
                money(summary.totalLoan),
                CorpColors.textSecondary(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
