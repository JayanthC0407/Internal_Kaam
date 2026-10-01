import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

enum _Filter { upcoming, overdue }

/// OBDX `loan-installments-due` — the loan instalments falling due soon,
/// or already overdue.
///
/// Shows [CorpLoanSampleData.installments] until live data is passed as
/// [installments].
class CorpLoanInstallmentsWidget extends StatefulWidget {
  const CorpLoanInstallmentsWidget({super.key, this.installments});

  final List<CorpLoanInstallment>? installments;

  @override
  State<CorpLoanInstallmentsWidget> createState() =>
      _CorpLoanInstallmentsWidgetState();
}

class _CorpLoanInstallmentsWidgetState
    extends State<CorpLoanInstallmentsWidget> {
  var _filter = _Filter.upcoming;

  bool get _isSample => widget.installments == null;

  @override
  Widget build(BuildContext context) {
    final all = widget.installments ?? CorpLoanSampleData.installments;
    final shown = [
      for (final i in all)
        if (i.isOverdue == (_filter == _Filter.overdue)) i,
    ]..sort((a, b) => a.dueOn.compareTo(b.dueOn));

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = CorpWidgetLayout.isCompact(constraints);
          void viewAll() => showCorpSampleDataNotice(context, 'Instalments');
          final toggle = CorpSegmentedToggle<_Filter>(
            options: const {
              _Filter.upcoming: 'Upcoming',
              _Filter.overdue: 'Overdue',
            },
            value: _filter,
            expand: compact,
            onChanged: (value) => setState(() => _filter = value),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: 'Installments Due',
                compact: compact,
                sample: _isSample,
                subtitle: CorpSubtitle(_subtitle(shown.length)),
                trailing: compact
                    ? CorpWidgetLink(
                        label: 'View all',
                        onTap: _isSample ? viewAll : null,
                      )
                    : toggle,
              ),
              if (compact) ...[const SizedBox(height: 12), toggle],
              const SizedBox(height: 14),
              _Figures(installments: shown, filter: _filter, compact: compact),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                _Empty(filter: _filter)
              else
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _InstallmentRow(installment: shown[i], compact: compact),
                ],
              if (!compact) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All amounts shown in GBP',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: CorpColors.textSecondary(context),
                        ),
                      ),
                    ),
                    CorpWidgetLink(
                      label: 'View all installments',
                      onTap: _isSample ? viewAll : null,
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _subtitle(int count) {
    final plural = count == 1 ? '' : 's';
    return _filter == _Filter.upcoming
        ? '$count upcoming installment$plural • next ${CorpLoanSampleData.upcomingWindowDays} days'
        : '$count overdue installment$plural';
  }
}

String _money(BuildContext context, double v) =>
    CorpFigures.compact(v, symbol: CorpCurrency.of(context));

class _Figures extends StatelessWidget {
  const _Figures({
    required this.installments,
    required this.filter,
    required this.compact,
  });

  final List<CorpLoanInstallment> installments;
  final _Filter filter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final overdue = filter == _Filter.overdue;
    final total = installments.fold<double>(0, (sum, i) => sum + i.amount);
    final first = installments.isEmpty ? null : installments.first;
    final nextLabel = overdue ? 'Oldest' : 'Next payment';
    final nextValue = first == null
        ? '—'
        : compact
            ? _money(context, first.amount)
            : '${_money(context, first.amount)} • ${CorpFigures.dayMonth(first.dueOn)}';

    return CorpStatRow(
      minTileWidth: compact ? 110 : 130,
      gap: compact ? 8 : 10,
      tiles: [
        CorpStatTile(
          label: overdue ? 'Total overdue' : 'Total due',
          value: _money(context, total),
          tone: overdue ? CorpTone.red : CorpTone.blue,
        ),
        // The count repeats the subtitle; the phone layout has no room.
        if (!compact)
          CorpStatTile(
            label: 'Installments',
            value: '${installments.length} ${overdue ? 'overdue' : 'due'}',
            tone: CorpTone.neutral,
          ),
        CorpStatTile(
          label: nextLabel,
          value: nextValue,
          tone: overdue ? CorpTone.amber : CorpTone.green,
        ),
      ],
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({required this.installment, required this.compact});

  final CorpLoanInstallment installment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chip = switch (installment.status) {
      CorpInstallmentStatus.dueSoon =>
        const CorpStatusChip(label: 'Due soon', tone: CorpTone.blue),
      CorpInstallmentStatus.upcoming =>
        const CorpStatusChip(label: 'Upcoming', tone: CorpTone.green),
      CorpInstallmentStatus.overdue =>
        const CorpStatusChip(label: 'Overdue', tone: CorpTone.red),
    };
    final name = Text(
      installment.loanName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: CorpColors.textPrimary(context),
      ),
    );
    final muted = TextStyle(
      fontSize: 11.5,
      color: CorpColors.textSecondary(context),
    );
    final amount = Text(
      _money(context, installment.amount),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: CorpToneColors.of(context, CorpTone.blue).label,
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CorpColors.divider(context)),
      ),
      child: compact
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      const SizedBox(height: 3),
                      Text(
                        '${CorpFigures.date(installment.dueOn)} • ${_money(context, installment.amount)}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                chip,
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      const SizedBox(height: 3),
                      Text(
                        'Due ${CorpFigures.date(installment.dueOn)}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: amount),
                Expanded(
                  flex: 3,
                  child: Align(alignment: Alignment.centerLeft, child: chip),
                ),
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter});

  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    return CorpInsetPanel(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Text(
        filter == _Filter.overdue
            ? 'Nothing overdue. All instalments are paid on time.'
            : 'No instalments due in the next '
                '${CorpLoanSampleData.upcomingWindowDays} days.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          color: CorpColors.textSecondary(context),
        ),
      ),
    );
  }
}
