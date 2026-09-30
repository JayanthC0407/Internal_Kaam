import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loan_overview.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_dashboard_widget_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_parts.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// "Loan Summary" — the repayment-progress widget.
///
/// Reads the loan list from `GET /digx-common/loan/v1/loan` through
/// [CorpLoanOverview]: outstanding and sanctioned amounts summed across
/// loans, the EMI from each loan's scheduled installment, and the rate
/// outstanding-weighted.
///
/// The gauge is the share repaid — sanctioned less outstanding, over
/// sanctioned. Hosts that do not return `amountFinanced` give no
/// denominator, so the gauge renders empty with "—" rather than inventing
/// a percentage from the outstanding balance alone.
class CorpLoanSummaryWidget extends ConsumerStatefulWidget {
  const CorpLoanSummaryWidget({super.key});

  @override
  ConsumerState<CorpLoanSummaryWidget> createState() =>
      _CorpLoanSummaryWidgetState();
}

class _CorpLoanSummaryWidgetState extends ConsumerState<CorpLoanSummaryWidget> {
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
                title: 'Loan Summary',
                subtitle: 'Repayment trend • '
                    '${compact ? CorpWidgetDate.shortMonthYear(DateTime.now(), locale: locale) : CorpWidgetDate.monthYear(DateTime.now(), locale: locale)}',
                compact: compact,
              ),
              const SizedBox(height: 14),
              if (overview.isEmpty)
                CorpWidgetPlaceholder(
                  height: compact ? 160 : 200,
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
                      label: 'Outstanding',
                      value: CorpMoneyFormat.compactAmount(
                        overview.totalOutstanding,
                      ),
                      compact: compact,
                    ),
                    CorpStatTile(
                      label: 'Next EMI',
                      // The next payment that will actually be taken, not
                      // an overdue one — see nextUpcomingInstallment.
                      value: CorpMoneyFormat.compactAmount(
                        overview.nextUpcomingInstallment?.amount ??
                            overview.monthlyInstallment,
                      ),
                      tone: CorpStatTone.positive,
                      compact: compact,
                    ),
                    CorpStatTile(
                      label: 'Interest rate',
                      value: CorpMoneyFormat.rate(overview.weightedRate),
                      tone: CorpStatTone.warning,
                      compact: compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _RepaymentPanel(overview: overview, compact: compact),
                const SizedBox(height: 14),
                _RepaymentHealth(overview: overview, compact: compact),
                const SizedBox(height: 12),
                CorpWidgetFooter(
                  compact: compact,
                  actionLabel: 'View loan details',
                  onAction: () => _openLoans(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openLoans(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loan details are not available yet.')),
    );
  }
}

/// The gauge panel: the arc, the outstanding figure under it, and the
/// paid / remaining / total breakdown.
class _RepaymentPanel extends StatelessWidget {
  const _RepaymentPanel({required this.overview, required this.compact});

  final CorpLoanOverview overview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 14 : 16,
      ),
      decoration: BoxDecoration(
        color: CorpColors.tile(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CorpColors.cardBorder(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CorpProgressGauge(
            progress: overview.repaidFraction,
            size: compact ? 130 : 150,
            strokeWidth: compact ? 12 : 14,
          ),
          const SizedBox(height: 6),
          Text(
            '${CorpMoneyFormat.compactAmount(overview.totalOutstanding)} outstanding',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12.5 : 13.5,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          _BreakdownLine(overview: overview, compact: compact),
        ],
      ),
    );
  }
}

/// "Paid £319K · Remaining £824K · Total Loan £1.20M" — wraps rather than
/// truncating, since all three figures matter.
class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({required this.overview, required this.compact});

  final CorpLoanOverview overview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, String value, Color color})>[
      (
        label: 'Paid',
        value: CorpMoneyFormat.compactAmount(overview.totalRepaid),
        color: CorpColors.positiveBalance(context),
      ),
      (
        label: 'Remaining',
        value: CorpMoneyFormat.compactAmount(overview.totalOutstanding),
        color: CorpColors.brand(context),
      ),
      (
        label: 'Total Loan',
        value: CorpMoneyFormat.compactAmount(overview.totalFinanced),
        color: CorpColors.textPrimary(context),
      ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final entry in entries)
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${entry.label} ',
                  style: TextStyle(
                    fontSize: compact ? 11 : 11.5,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
                TextSpan(
                  text: entry.value,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 12,
                    fontWeight: FontWeight.w700,
                    color: entry.color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Repayment health — Remaining tenure • 47 EMI".
class _RepaymentHealth extends StatelessWidget {
  const _RepaymentHealth({required this.overview, required this.compact});

  final CorpLoanOverview overview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final remaining = overview.remainingInstallments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Repayment health',
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: CorpColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          remaining == null
              // The host did not report a tenure; the loan count is the
              // honest thing to show instead of a blank line.
              ? '${overview.activeCount} '
                  '${overview.activeCount == 1 ? 'active loan' : 'active loans'}'
              : 'Remaining tenure • $remaining EMI',
          style: TextStyle(
            fontSize: compact ? 11.5 : 12.5,
            color: CorpColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
