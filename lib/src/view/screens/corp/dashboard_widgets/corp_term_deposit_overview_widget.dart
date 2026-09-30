import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/models/corp/corp_deposit_overview.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_dashboard_widget_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_parts.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// "TD Accounts Overview" — the term-deposit portfolio widget.
///
/// Every figure comes from `GET /digx-common/td/v1/deposit`, aggregated by
/// [CorpTermDepositOverview]: the balance is the principal summed across
/// deposits, the rate is principal-weighted, and the maturity strip is the
/// next four deposits to mature with their maturity amounts. Nothing here
/// is fixture data — a host that sends no rates shows "—" for the average
/// rather than a plausible-looking number.
///
/// One widget for both breakpoints, as the designs differ only in
/// arrangement: the web version lays the maturities out as four cards
/// across, the mobile version as tinted rows. [LayoutBuilder] picks between
/// them on the tile's own width, so the same widget is correct whether the
/// dashboard puts it at half width on a desktop or full width on a phone.
class CorpTermDepositOverviewWidget extends ConsumerStatefulWidget {
  const CorpTermDepositOverviewWidget({super.key});

  @override
  ConsumerState<CorpTermDepositOverviewWidget> createState() =>
      _CorpTermDepositOverviewWidgetState();
}

class _CorpTermDepositOverviewWidgetState
    extends ConsumerState<CorpTermDepositOverviewWidget> {
  @override
  void initState() {
    super.initState();
    // Deposits load lazily, so the widget asks for its own group. Post-frame
    // because this mutates a provider, which Riverpod forbids during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(corpAccountsProvider.notifier).ensureGroupLoaded(corpDepositGroup);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(corpAccountsProvider);
    final overview = ref.watch(corpTermDepositOverviewProvider);
    final locale = CorpWidgetDate.localeOf(context);

    // Read here rather than inside the LayoutBuilder below: a builder
    // callback runs during layout, outside this element's build, and
    // `ref` must not be used from there.
    //
    // This is the host's own converted group total, the fallback for when
    // the deposits span several currencies and a client-side sum would be
    // meaningless — see CorpTermDepositOverview.totalBalance.
    final hostDepositTotal =
        accountsState.summary.summaryFor(corpDepositGroup)?.headlineTotal;

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
                title: 'TD Accounts Overview',
                subtitle: compact
                    ? 'Term deposits • '
                        '${CorpWidgetDate.shortMonthYear(DateTime.now(), locale: locale)}'
                    : 'Term deposit portfolio • '
                        '${CorpWidgetDate.monthYear(DateTime.now(), locale: locale)}',
                compact: compact,
              ),
              const SizedBox(height: 14),
              if (overview.isEmpty)
                CorpWidgetPlaceholder(
                  height: compact ? 140 : 168,
                  isLoading: corpGroupIsInitialLoading(
                    accountsState,
                    corpDepositGroup,
                  ),
                  message: corpGroupMessage(
                    accountsState,
                    corpDepositGroup,
                    emptyMessage: 'No term deposits on this party.',
                  ),
                )
              else ...[
                _statTiles(
                  overview,
                  compact: compact,
                  locale: locale,
                  hostTotal: hostDepositTotal,
                ),
                const SizedBox(height: 16),
                Text(
                  'Upcoming maturities',
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13.5,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 10),
                if (overview.upcomingMaturities.isEmpty)
                  Text(
                    'No deposits maturing.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: CorpColors.textSecondary(context),
                    ),
                  )
                else if (compact)
                  _MaturityRows(
                    deposits: overview.upcomingMaturities,
                    locale: locale,
                  )
                else
                  _MaturityCards(
                    deposits: overview.upcomingMaturities,
                    locale: locale,
                  ),
                const SizedBox(height: 16),
                CorpWidgetFooter(
                  compact: compact,
                  caption: overview.totalMaturityValue == null
                      ? null
                      : '${compact ? 'Maturity value' : 'Total maturity value'}'
                          ' • '
                          '${CorpMoneyFormat.compactAmount(overview.totalMaturityValue)}',
                  actionLabel:
                      compact ? 'View accounts' : 'View TD accounts',
                  onAction: () => _openDeposits(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _statTiles(
    CorpTermDepositOverview overview, {
    required bool compact,
    required String locale,
    required MoneyAmount? hostTotal,
  }) {
    final balance = overview.totalBalance ?? hostTotal;

    return CorpStatTileRow(
      tiles: [
        CorpStatTile(
          label: compact ? 'Balance' : 'Total TD balance',
          value: CorpMoneyFormat.compactAmount(balance),
          compact: compact,
        ),
        CorpStatTile(
          label: compact ? 'Active' : 'Active deposits',
          value: '${overview.activeCount}',
          tone: CorpStatTone.positive,
          compact: compact,
        ),
        CorpStatTile(
          label: compact ? 'Avg rate' : 'Average rate',
          value: CorpMoneyFormat.rate(overview.averageRate),
          tone: CorpStatTone.warning,
          compact: compact,
        ),
        // The mobile design drops this tile — the date does not fit beside
        // three others at phone width, and it is the first row of the
        // maturity list anyway.
        if (!compact)
          CorpStatTile(
            label: 'Next maturity',
            value: CorpWidgetDate.full(
              overview.nextMaturityDate,
              locale: locale,
            ),
            tone: CorpStatTone.neutral,
          ),
      ],
    );
  }

  void _openDeposits(BuildContext context) {
    // The corporate deposits list screen is not built yet; the dashboard
    // owns navigation, so this reports rather than dead-ends.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('TD accounts are not available yet.')),
    );
  }
}

/// Web layout — the four maturity cards across.
class _MaturityCards extends StatelessWidget {
  const _MaturityCards({required this.deposits, required this.locale});

  final List<CorpAccount> deposits;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        // Two across when the tile is narrow, four when it has the room.
        final perRow = constraints.maxWidth < 700 ? 2 : deposits.length;
        final columns = perRow < 1 ? 1 : perRow;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < deposits.length; i++)
              SizedBox(
                width: width,
                child: _MaturityCard(
                  deposit: deposits[i],
                  tone: _toneAt(i),
                  locale: locale,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MaturityCard extends StatelessWidget {
  const _MaturityCard({
    required this.deposit,
    required this.tone,
    required this.locale,
  });

  final CorpAccount deposit;
  final CorpStatTone tone;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: CorpColors.tile(context),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: CorpColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CorpPill(
            label: CorpWidgetDate.short(
              deposit.maturityDateTime,
              locale: locale,
            ),
            tone: tone,
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CorpMoneyFormat.compactAmount(deposit.maturityAmount),
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CorpColors.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Maturity amount',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

/// Mobile layout — one tinted row per maturity.
class _MaturityRows extends StatelessWidget {
  const _MaturityRows({required this.deposits, required this.locale});

  final List<CorpAccount> deposits;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < deposits.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _MaturityRow(
            deposit: deposits[i],
            tone: _toneAt(i),
            locale: locale,
          ),
        ],
      ],
    );
  }
}

class _MaturityRow extends StatelessWidget {
  const _MaturityRow({
    required this.deposit,
    required this.tone,
    required this.locale,
  });

  final CorpAccount deposit;
  final CorpStatTone tone;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: tone.fill(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            CorpWidgetDate.short(deposit.maturityDateTime, locale: locale),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: tone.accent(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              CorpMoneyFormat.compactAmount(deposit.maturityAmount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CorpColors.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'matures',
            style: TextStyle(
              fontSize: 12,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cycles the design's blue / green / blue / amber row tinting.
CorpStatTone _toneAt(int index) {
  const tones = [
    CorpStatTone.info,
    CorpStatTone.positive,
    CorpStatTone.info,
    CorpStatTone.warning,
  ];
  return tones[index % tones.length];
}
