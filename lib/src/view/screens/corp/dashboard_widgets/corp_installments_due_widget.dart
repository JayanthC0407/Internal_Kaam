import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loan_overview.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_dashboard_widget_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_parts.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// "Installments Due" — upcoming and overdue loan repayments.
///
/// Built from the same `loan/v1/loan` list as the other loan widgets: each
/// loan contributes the one installment the list endpoint carries, its
/// `nextInstallmentDate` and `installmentAmount`. A full repayment schedule
/// would need a `loan/{id}/schedule` call per loan, which the dashboard
/// deliberately does not make — the widget's job is the next thing due, and
/// "View all installments" is where the complete schedule belongs.
///
/// Loans whose host record carries no next-installment date are omitted
/// rather than listed with a blank date.
class CorpInstallmentsDueWidget extends ConsumerStatefulWidget {
  const CorpInstallmentsDueWidget({super.key});

  @override
  ConsumerState<CorpInstallmentsDueWidget> createState() =>
      _CorpInstallmentsDueWidgetState();
}

class _CorpInstallmentsDueWidgetState
    extends ConsumerState<CorpInstallmentsDueWidget> {
  /// Which tab of the segmented control is showing.
  bool _showOverdue = false;

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

    final rows = _showOverdue
        ? overview.overdueInstallments
        : overview.upcomingInstallments;
    final total = CorpLoanOverview.totalOf(rows);

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
                title: 'Installments Due',
                subtitle: _subtitleFor(rows),
                compact: compact,
                trailing: _SegmentedToggle(
                  showOverdue: _showOverdue,
                  overdueCount: overview.overdueInstallments.length,
                  onChanged: (value) => setState(() => _showOverdue = value),
                ),
              ),
              const SizedBox(height: 14),
              if (overview.isEmpty)
                CorpWidgetPlaceholder(
                  height: compact ? 150 : 180,
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
                      label: 'Total due',
                      value: CorpMoneyFormat.compactAmount(total),
                      compact: compact,
                    ),
                    CorpStatTile(
                      label: 'Installments',
                      value: '${rows.length} due',
                      tone: CorpStatTone.neutral,
                      compact: compact,
                    ),
                    CorpStatTile(
                      label: 'Next payment',
                      value: rows.isEmpty
                          ? '—'
                          : '${CorpMoneyFormat.compactAmount(rows.first.amount)}'
                              ' • '
                              '${CorpWidgetDate.short(rows.first.dueDate, locale: locale)}',
                      tone: CorpStatTone.positive,
                      compact: compact,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  CorpWidgetPlaceholder(
                    height: compact ? 70 : 90,
                    message: _showOverdue
                        ? 'Nothing overdue.'
                        : 'No installments scheduled.',
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _InstallmentRow(
                          installment: rows[i],
                          compact: compact,
                          locale: locale,
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 14),
                CorpWidgetFooter(
                  compact: compact,
                  caption: _currencyCaption(total?.currency),
                  actionLabel:
                      compact ? 'View all' : 'View all installments',
                  onAction: () => _openInstallments(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _subtitleFor(List<CorpInstallmentDue> rows) {
    if (rows.isEmpty) {
      return _showOverdue ? 'Nothing overdue' : 'No installments scheduled';
    }
    final noun = rows.length == 1 ? 'installment' : 'installments';
    if (_showOverdue) return '${rows.length} overdue $noun';

    // "next 10 days" in the design is the window to the furthest row
    // shown, computed rather than fixed so it stays true.
    final days = rows.last.dueDate
        .difference(DateTime.now())
        .inDays
        .clamp(0, 3650);
    return '${rows.length} upcoming $noun • next ${days + 1} days';
  }

  String? _currencyCaption(String? currency) {
    final code = currency?.trim().toUpperCase();
    if (code == null || code.isEmpty) return null;
    return 'All amounts shown in $code';
  }

  void _openInstallments(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The installment schedule is not available yet.'),
      ),
    );
  }
}

/// The Upcoming / Overdue pill toggle in the widget's top-right corner.
class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.showOverdue,
    required this.overdueCount,
    required this.onChanged,
  });

  final bool showOverdue;
  final int overdueCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: CorpColors.tile(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CorpColors.cardBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, label: 'Upcoming', selected: !showOverdue, value: false),
          _segment(
            context,
            // The count earns its place here: an overdue installment the
            // user cannot see from the Upcoming tab is the one thing on
            // this widget that needs acting on.
            label: overdueCount > 0 ? 'Overdue ($overdueCount)' : 'Overdue',
            selected: showOverdue,
            value: true,
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required bool selected,
    required bool value,
  }) {
    return InkWell(
      onTap: selected ? null : () => onChanged(value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? CorpColors.brand(context).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? CorpColors.brand(context)
                : CorpColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.installment,
    required this.compact,
    required this.locale,
  });

  final CorpInstallmentDue installment;
  final bool compact;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusTone) = switch (installment.status) {
      CorpInstallmentStatus.overdue => ('Overdue', CorpStatTone.warning),
      CorpInstallmentStatus.dueSoon => ('Due soon', CorpStatTone.info),
      CorpInstallmentStatus.upcoming => ('Upcoming', CorpStatTone.positive),
    };

    final amount = Text(
      CorpMoneyFormat.compactAmount(installment.amount),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 13.5 : 15,
        fontWeight: FontWeight.w700,
        color: CorpColors.brand(context),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CorpColors.cardBorder(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  installment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13.5,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Due ${CorpWidgetDate.full(installment.dueDate, locale: locale)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 11.5,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // On a phone the amount sits above the pill so neither is
          // squeezed; side by side everywhere else, as the web design has.
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                amount,
                const SizedBox(height: 4),
                CorpPill(label: statusLabel, tone: statusTone),
              ],
            )
          else ...[
            amount,
            const SizedBox(width: 12),
            CorpPill(label: statusLabel, tone: statusTone),
          ],
        ],
      ),
    );
  }
}
