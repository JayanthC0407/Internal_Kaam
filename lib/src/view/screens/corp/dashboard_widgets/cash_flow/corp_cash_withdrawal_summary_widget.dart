import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// The month's cash withdrawals: how much, how often, the largest, the
/// limit left, and the split by channel.
///
/// Registered as `cash-withdrawal-summary`, a name of the app's choosing —
/// the OBDX catalog has no component for this design.
///
/// Shows [CorpCashFlowSampleData.withdrawals] until live data is passed as
/// [data]; the total is the channels' sum.
class CorpCashWithdrawalSummaryWidget extends StatelessWidget {
  const CorpCashWithdrawalSummaryWidget({super.key, this.data});

  final CorpCashWithdrawals? data;

  @override
  Widget build(BuildContext context) {
    final w = data ?? CorpCashFlowSampleData.withdrawals;
    final isSample = data == null;
    String money(double v) => CorpFigures.compact(
          v,
          symbol: CorpCurrency.of(context),
          precise: true,
        );

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = CorpWidgetLayout.isCompact(constraints);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: 'Cash Withdrawal Summary',
                compact: compact,
                sample: isSample,
                subtitle: CorpSubtitle(
                  compact
                      ? CorpFigures.monthYear(w.month)
                      : 'Account activity • ${CorpFigures.monthYear(w.month)}',
                ),
              ),
              const SizedBox(height: 14),
              CorpStatRow(
                minTileWidth: compact ? 120 : 110,
                gap: compact ? 8 : 10,
                tiles: [
                  CorpStatTile(
                    label: 'Total withdrawn',
                    value: money(w.total),
                    tone: CorpTone.red,
                  ),
                  CorpStatTile(
                    label: 'Transactions',
                    value: w.transactions == null ? '—' : '${w.transactions}',
                    tone: CorpTone.neutral,
                  ),
                  CorpStatTile(
                    label: compact ? 'Largest' : 'Largest withdrawal',
                    value: w.largest == null ? '—' : money(w.largest!),
                  ),
                  // Only where the host reports a limit.
                  if (w.availableLimit != null)
                    CorpStatTile(
                      label: 'Available limit',
                      value: money(w.availableLimit!),
                      tone: CorpTone.green,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CorpColors.divider(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdrawal activity',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: CorpColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ChannelBar(channels: w.byChannel),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 22,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < w.byChannel.length; i++)
                          CorpLegendDot(
                            color: _ChannelBar
                                .colors[i % _ChannelBar.colors.length],
                            label: w.byChannel[i].label,
                            value: money(w.byChannel[i].amount),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: CorpWidgetLink(
                  label: compact ? 'View details' : 'View withdrawal details',
                  onTap: isSample
                      ? () => showCorpSampleDataNotice(
                            context,
                            'Withdrawal details',
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

/// The channels' shares as one split bar. A channel with a net negative
/// (a reversal) has no share to draw; it stays in the legend.
class _ChannelBar extends StatelessWidget {
  const _ChannelBar({required this.channels});

  final List<CorpWithdrawalChannel> channels;

  static const colors = [
    CorpChartColors.primary,
    CorpChartColors.light,
    CorpChartColors.deep,
  ];

  @override
  Widget build(BuildContext context) {
    final drawn = [
      for (var i = 0; i < channels.length; i++)
        if (channels[i].amount > 0) (channels[i].amount, colors[i % 3]),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        width: double.infinity,
        child: drawn.isEmpty
            ? ColoredBox(color: CorpChartColors.track(context))
            : Row(
                // The parts fill the bar's height; unstretched, an empty
                // ColoredBox is zero tall.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (amount, color) in drawn)
                    Expanded(
                      flex: (amount * 1000).round().clamp(1, 1 << 30),
                      child: ColoredBox(color: color),
                    ),
                ],
              ),
      ),
    );
  }
}
