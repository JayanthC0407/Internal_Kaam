import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// OBDX `loan-portfolio` — the lending mix: how the outstanding balance
/// splits across loan products.
///
/// Shows [CorpLoanSampleData.portfolio] until live data is passed as
/// [data].
class CorpLoanPortfolioWidget extends StatelessWidget {
  const CorpLoanPortfolioWidget({super.key, this.data});

  final CorpLoanPortfolioData? data;

  /// Colours for the mix, in order; the designs use three.
  static const mixColors = [
    CorpChartColors.primary,
    CorpChartColors.light,
    CorpChartColors.deep,
    CorpChartColors.mint,
  ];

  @override
  Widget build(BuildContext context) {
    final portfolio = data ?? CorpLoanSampleData.portfolio;
    final isSample = data == null;
    String money(double v) =>
        CorpFigures.compact(v, symbol: CorpCurrency.of(context));

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = CorpWidgetLayout.isCompact(constraints);
          final donut = Semantics(
            label: 'Loan mix: ${[
              for (final m in portfolio.mix)
                '${m.label} ${m.share.round()} percent',
            ].join(', ')}',
            child: CorpDonut(
              size: compact ? 132 : 140,
              strokeWidth: 15,
              segments: [
                for (var i = 0; i < portfolio.mix.length; i++)
                  CorpDonutSegment(
                    value: portfolio.mix[i].share,
                    color: mixColors[i % mixColors.length],
                  ),
              ],
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(portfolio.totalOutstanding),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: CorpChartColors.figure(context),
                    ),
                  ),
                  Text(
                    'portfolio',
                    style: TextStyle(
                      fontSize: 11,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          );
          final legend = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < portfolio.mix.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                CorpLegendDot(
                  color: mixColors[i % mixColors.length],
                  label: compact
                      ? portfolio.mix[i].shortLabel
                      : portfolio.mix[i].label,
                  value: '${portfolio.mix[i].share.round()}%',
                ),
              ],
              if (!compact && portfolio.nextReview != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Next review • ${CorpFigures.date(portfolio.nextReview!)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: 'Loan Portfolio',
                compact: compact,
                sample: isSample,
                subtitle: CorpSubtitle(
                  'Current lending mix • ${compact ? CorpFigures.shortMonthYear(portfolio.asOf) : CorpFigures.monthYear(portfolio.asOf)}',
                ),
              ),
              const SizedBox(height: 14),
              CorpStatRow(
                minTileWidth: compact ? 84 : 120,
                gap: compact ? 8 : 10,
                tiles: [
                  CorpStatTile(
                    label: compact ? 'Outstanding' : 'Total outstanding',
                    value: money(portfolio.totalOutstanding),
                  ),
                  CorpStatTile(
                    label: compact ? 'Active' : 'Active loans',
                    value: '${portfolio.activeLoans}',
                    tone: CorpTone.green,
                  ),
                  CorpStatTile(
                    label: 'Monthly EMI',
                    value: money(portfolio.monthlyEmi),
                    tone: CorpTone.amber,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CorpInsetPanel(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loan mix',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: CorpColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (compact) ...[
                      Center(child: donut),
                      const SizedBox(height: 14),
                      legend,
                    ] else
                      Row(
                        children: [
                          donut,
                          const SizedBox(width: 28),
                          Expanded(child: legend),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Weighted rate • ${portfolio.weightedRate == null ? '—' : CorpFigures.percent(portfolio.weightedRate!, decimals: 1)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CorpColors.textSecondary(context),
                      ),
                    ),
                  ),
                  CorpWidgetLink(
                    label: compact ? 'View' : 'View portfolio',
                    onTap: isSample
                        ? () => showCorpSampleDataNotice(
                              context,
                              'The loan portfolio',
                            )
                        : null,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
