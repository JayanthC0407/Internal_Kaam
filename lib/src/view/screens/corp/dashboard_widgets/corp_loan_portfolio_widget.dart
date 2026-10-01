import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loan_overview.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_dashboard_widget_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_parts.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// "Loan Portfolio" — the current lending mix.
///
/// The donut is the outstanding balance grouped by product description
/// (`productDTO.description` on each `loan/v1/loan` row), so the slices are
/// whatever products the party actually holds rather than a fixed set of
/// categories. Shares are computed from the amounts, not read from the
/// host — OBDX returns no mix breakdown of its own.
///
/// "Next review" is the earliest maturity date across the loans, which is
/// the next date the portfolio genuinely changes. It is omitted when no
/// loan carries a maturity date.
class CorpLoanPortfolioWidget extends ConsumerStatefulWidget {
  const CorpLoanPortfolioWidget({super.key});

  @override
  ConsumerState<CorpLoanPortfolioWidget> createState() =>
      _CorpLoanPortfolioWidgetState();
}

class _CorpLoanPortfolioWidgetState
    extends ConsumerState<CorpLoanPortfolioWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(corpAccountsProvider.notifier).ensureGroupLoaded(corpLoanGroup);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(corpAccountsProvider);
    final overview = ref.watch(corpLoanOverviewProvider);
    final locale = CorpWidgetDate.localeOf(context);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              CorpWidgetHeading(
                title: 'Loan Portfolio',
                subtitle: 'Current lending mix • '
                    '${compact ? CorpWidgetDate.shortMonthYear(DateTime.now(), locale: locale) : CorpWidgetDate.monthYear(DateTime.now(), locale: locale)}',
                compact: compact,
              ),
              const SizedBox(height: 14),
              if (overview.isEmpty)
                CorpWidgetPlaceholder(
                  height: compact ? 170 : 210,
                  isLoading:
                      corpGroupIsInitialLoading(accountsState, corpLoanGroup),
                  message: corpGroupMessage(
                    accountsState,
                    corpLoanGroup,
                    emptyMessage: 'No loans or finances on this party.',
                  ),
                )
              else ...[
                CorpStatTileRow(
                  tiles: [
                    CorpStatTile(
                      label: 'Total outstanding',
                      value: CorpMoneyFormat.compactAmount(
                        overview.totalOutstanding,
                      ),
                      compact: compact,
                    ),
                    CorpStatTile(
                      label: 'Active loans',
                      value: '${overview.activeCount}',
                      tone: CorpStatTone.positive,
                      compact: compact,
                    ),
                    CorpStatTile(
                      label: 'Monthly EMI',
                      value: CorpMoneyFormat.compactAmount(
                        overview.monthlyInstallment,
                      ),
                      tone: CorpStatTone.warning,
                      compact: compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Loan mix',
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13.5,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 10),
                _LoanMix(
                  overview: overview,
                  compact: compact,
                  locale: locale,
                ),
                const SizedBox(height: 14),
                CorpWidgetFooter(
                  compact: compact,
                  caption: overview.weightedRate == null
                      ? null
                      : 'Weighted rate • '
                          '${CorpMoneyFormat.rate(overview.weightedRate)}',
                  actionLabel: 'View portfolio',
                  onAction: () => _openPortfolio(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openPortfolio(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The loan portfolio is not available yet.')),
    );
  }
}

/// Donut beside its legend on the web, stacked on a phone — the difference
/// between the two designs.
class _LoanMix extends StatelessWidget {
  const _LoanMix({
    required this.overview,
    required this.compact,
    required this.locale,
  });

  final CorpLoanOverview overview;
  final bool compact;
  final String locale;

  @override
  Widget build(BuildContext context) {
    if (overview.mix.isEmpty) {
      return CorpWidgetPlaceholder(
        height: compact ? 90 : 110,
        message: 'No outstanding balances to break down.',
      );
    }

    final donut = CorpDonutChart(
      slices: [
        for (var i = 0; i < overview.mix.length; i++)
          CorpDonutSlice(
            value: overview.mix[i].amount,
            color: CorpChartPalette.at(context, i),
            label: overview.mix[i].label,
          ),
      ],
      centerValue: CorpMoneyFormat.compactAmount(overview.totalOutstanding),
      centerLabel: 'portfolio',
      size: compact ? 130 : 150,
      strokeWidth: compact ? 16 : 18,
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < overview.mix.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _LegendRow(
            slice: overview.mix[i],
            color: CorpChartPalette.at(context, i),
          ),
        ],
        if (_nextReview != null) ...[
          const SizedBox(height: 12),
          Text(
            'Next review • ${CorpWidgetDate.full(_nextReview, locale: locale)}',
            style: TextStyle(
              fontSize: 11.5,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: donut),
          const SizedBox(height: 14),
          legend,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        donut,
        const SizedBox(width: 20),
        Expanded(child: legend),
      ],
    );
  }

  /// Earliest maturity still ahead of today — see the class doc. Loans that
  /// have already matured are skipped, so the line never prints a date in
  /// the past; when none is left the caller drops the line entirely.
  DateTime? get _nextReview {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? earliest;
    for (final loan in overview.loans) {
      final maturity = loan.maturityDateTime;
      if (maturity == null || maturity.isBefore(today)) continue;
      if (earliest == null || maturity.isBefore(earliest)) earliest = maturity;
    }
    return earliest;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.color});

  final CorpLoanMixSlice slice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            slice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: CorpColors.textPrimary(context),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(slice.share * 100).round()}%',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: CorpColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
