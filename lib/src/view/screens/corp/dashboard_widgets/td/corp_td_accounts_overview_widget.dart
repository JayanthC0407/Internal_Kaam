import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// OBDX `td-accounts-overview` — the term deposit portfolio at a glance,
/// and the deposits maturing next.
///
/// Shows [CorpTdSampleData.deposits] until live data is passed as
/// [deposits].
class CorpTdAccountsOverviewWidget extends StatelessWidget {
  const CorpTdAccountsOverviewWidget({super.key, this.deposits, this.asOf});

  final List<CorpTermDeposit>? deposits;

  /// "Today", for the subtitle and for which maturities are upcoming.
  final DateTime? asOf;

  /// How many upcoming maturities are listed.
  static const upcomingCount = 4;

  /// Colours the upcoming dates take in turn, as in the design.
  static const _tones = [
    CorpTone.blue,
    CorpTone.green,
    CorpTone.blue,
    CorpTone.amber,
  ];

  @override
  Widget build(BuildContext context) {
    final all = deposits ?? CorpTdSampleData.deposits;
    final today = asOf ?? CorpTdSampleData.asOf;
    final isSample = deposits == null;
    final totals = CorpTdTotals.of(all);
    final upcoming = [
      for (final d in all)
        if (d.maturesOn != null && !d.maturesOn!.isBefore(today)) d,
    ]..sort((a, b) => a.maturesOn!.compareTo(b.maturesOn!));
    final next = upcoming.take(upcomingCount).toList();
    String money(double v) =>
        CorpFigures.compact(v, symbol: CorpCurrency.of(context), precise: true);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = CorpWidgetLayout.isCompact(constraints);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: 'TD Accounts Overview',
                compact: compact,
                sample: isSample,
                subtitle: CorpSubtitle(
                  compact
                      ? 'Term deposits • ${CorpFigures.shortMonthYear(today)}'
                      : 'Term deposit portfolio • ${CorpFigures.monthYear(today)}',
                ),
              ),
              const SizedBox(height: 14),
              CorpStatRow(
                minTileWidth: compact ? 84 : 118,
                gap: compact ? 8 : 10,
                tiles: [
                  CorpStatTile(
                    label: compact ? 'Balance' : 'Total TD balance',
                    value: money(totals.balance),
                  ),
                  CorpStatTile(
                    label: compact ? 'Active' : 'Active deposits',
                    value: '${totals.count}',
                    tone: CorpTone.green,
                  ),
                  CorpStatTile(
                    label: compact ? 'Avg rate' : 'Average rate',
                    value: CorpFigures.percentOr(totals.averageRate),
                    tone: CorpTone.amber,
                  ),
                  // The phone has room for three; the date is in the list.
                  if (!compact)
                    CorpStatTile(
                      label: 'Next maturity',
                      value: totals.nextMaturity == null
                          ? '—'
                          : CorpFigures.date(totals.nextMaturity!),
                      tone: CorpTone.neutral,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Upcoming maturities',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: CorpColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              if (next.isEmpty)
                CorpInsetPanel(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No deposits mature in the coming months.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
                )
              else if (compact)
                Column(
                  children: [
                    for (var i = 0; i < next.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _MaturityRow(
                        deposit: next[i],
                        tone: _tones[i % _tones.length],
                        money: money,
                      ),
                    ],
                  ],
                )
              else
                CorpStatRow(
                  minTileWidth: 104,
                  maxPerRow: upcomingCount,
                  tiles: [
                    for (var i = 0; i < next.length; i++)
                      _MaturityCard(
                        deposit: next[i],
                        tone: _tones[i % _tones.length],
                        money: money,
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${compact ? 'Maturity value' : 'Total maturity value'}'
                      ' • ${money(totals.maturityValue)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CorpColors.textSecondary(context),
                      ),
                    ),
                  ),
                  CorpWidgetLink(
                    label: compact ? 'View accounts' : 'View TD accounts',
                    onTap: isSample
                        ? () => showCorpSampleDataNotice(
                              context,
                              'Term deposit accounts',
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

/// Web: a small card per maturity — date pill, amount, caption.
class _MaturityCard extends StatelessWidget {
  const _MaturityCard({
    required this.deposit,
    required this.tone,
    required this.money,
  });

  final CorpTermDeposit deposit;
  final CorpTone tone;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${deposit.id} matures ${CorpFigures.date(deposit.maturesOn!)}, '
          '${money(deposit.maturityValue)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: CorpColors.card(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CorpColors.divider(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CorpStatusChip(
              label: CorpFigures.dayMonth(deposit.maturesOn!),
              tone: tone,
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                money(deposit.maturityValue),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CorpColors.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Maturity amount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: CorpColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phone: one tinted line per maturity.
class _MaturityRow extends StatelessWidget {
  const _MaturityRow({
    required this.deposit,
    required this.tone,
    required this.money,
  });

  final CorpTermDeposit deposit;
  final CorpTone tone;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final colors = CorpToneColors.of(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              CorpFigures.dayMonth(deposit.maturesOn!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.label,
              ),
            ),
          ),
          Text(
            money(deposit.maturityValue),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'matures',
              style: TextStyle(
                fontSize: 11.5,
                color: CorpColors.textSecondary(context),
              ),
            ),
          ),
          Text(
            deposit.id,
            style: TextStyle(
              fontSize: 11.5,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
