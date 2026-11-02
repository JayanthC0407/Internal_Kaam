import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/liquidity_overview_models.dart';
import 'package:ubci_bank/src/core/models/corp/lm_countries.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_liquidity_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/liquidity/lm_widgets.dart';

/// The Overview's balance widgets: Position By Currency, Position By
/// Region and Assets & Liabilities (card §4-§6).

String _money(double amount, String? currency) => cfMoney(MoneyAmount(amount: amount, currency: currency));

/// Position By Currency (`position-by-currency`): one row per currency
/// with its unconverted balance; the balance opens that currency's
/// accounts.
class LmPositionByCurrency extends ConsumerWidget {
  const LmPositionByCurrency({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LmWidgetCard(
        title: 'Position By Currency',
        child: lmLoad(
          ref.watch(lmPositionByCurrencyProvider),
          failed: 'We couldn\'t load the accounts.',
          onRetry: () => ref.invalidate(lmPositionByCurrencyProvider),
          data: (data) {
            final rows = LmCurrencyPosition.group(data.accounts);
            if (rows.isEmpty) return const LmEmpty(title: 'No items to display');
            final style = TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context), fontSize: 12.5);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [Expanded(child: Text('Currency', style: style)), Text('Balance', style: style)]),
                const Divider(),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(r.currency, style: TextStyle(color: CorpColors.textPrimary(context)))),
                        Tooltip(
                          message: 'Click here to view accounts',
                          child: CfLink(
                            label: _money(r.balance, r.currency),
                            size: 14,
                            onTap: () => showLmAccounts(
                              context,
                              title: 'Position By Currency - ${r.currency}',
                              accounts: r.accounts,
                              partyName: data.partyName,
                            ),
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

/// Position By Region (`position-by-region`): totals per country in the
/// "In Equivalent" currency; a country opens its accounts per currency,
/// and an account count opens the accounts. OBDX draws the countries on a
/// world map; the app lists them (no map component) — same figures.
class LmPositionByRegion extends ConsumerStatefulWidget {
  const LmPositionByRegion({super.key});

  @override
  ConsumerState<LmPositionByRegion> createState() => _LmPositionByRegionState();
}

class _LmPositionByRegionState extends ConsumerState<LmPositionByRegion> {
  String? _currency;
  String? _country;

  @override
  Widget build(BuildContext context) => LmWidgetCard(
        title: 'Position By Region',
        child: lmLoad(
          ref.watch(lmRegionBalancesProvider),
          failed: 'We couldn\'t load the accounts.',
          onRetry: () => ref.invalidate(lmRegionBalancesProvider),
          data: (data) {
            final currency = _currency ?? data.defaultCurrency;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LmCurrencyField(
                  label: 'In Equivalent',
                  currencies: data.currencies,
                  selected: currency,
                  onSelected: (c) => setState(() => _currency = c),
                ),
                const SizedBox(height: 12),
                if (currency == null)
                  const LmEmpty(title: 'No items to display')
                else
                  lmLoad(
                    ref.watch(lmRegionPositionsProvider(currency)),
                    failed: 'We couldn\'t load the exchange rates.',
                    onRetry: () => ref.invalidate(lmRegionPositionsProvider(currency)),
                    data: (p) => _body(context, data, p, currency),
                  ),
              ],
            );
          },
        ),
      );

  Widget _body(BuildContext context, LmBalances data, LmRegionPositions p, String currency) {
    if (p.missingRate) return const LmEmpty(title: 'Exchange rate not found', icon: Icons.currency_exchange_rounded);
    if (p.totals.isEmpty) return const LmEmpty(title: 'No items to display');
    final selected = _country;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(:key, :value) in p.totals.entries)
          ListTile(
            dense: true,
            selected: key == selected,
            selectedTileColor: CorpColors.brand(context).withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: Icon(Icons.location_on_outlined, color: CorpColors.brand(context)),
            title: Text(lmCountryName(key)),
            trailing: Text(_money(value, currency), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => setState(() => _country = key == selected ? null : key),
          ),
      ],
    );
    if (selected == null || !p.totals.containsKey(selected)) return list;
    final panel = _CountryPanel(country: selected, data: data);
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 640
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: list),
              const SizedBox(width: 16),
              Expanded(child: panel),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [list, const SizedBox(height: 12), panel]),
    );
  }
}

/// A selected country: per account currency, the count (a link to the
/// accounts) and the unconverted balance.
class _CountryPanel extends StatelessWidget {
  const _CountryPanel({required this.country, required this.data});

  final String country;
  final LmBalances data;

  void _open(BuildContext context, String currency) {
    final currencies = [for (final r in LmRegionPositions.byCurrency(data.accounts, country)) r.currency];
    var chosen = currency;
    showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Position By Region'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(lmCountryName(country), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  LmCurrencyField(
                    label: 'Currency',
                    currencies: currencies,
                    selected: chosen,
                    onSelected: (c) => setDialog(() => chosen = c),
                  ),
                  const SizedBox(height: 12),
                  LmAccountsTable(
                    accounts: [for (final a in data.accounts) if (a.country == country && a.currency == chosen) a],
                    partyName: data.partyName,
                    balanceLabel: 'Balance',
                  ),
                ],
              ),
            ),
          ),
          actions: [FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Ok'))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context), fontSize: 12.5);
    return CfPanel(
      header: Text(lmCountryName(country),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Expanded(child: Text('Accounts', style: style)), Text('Balance', style: style)]),
          const Divider(),
          for (final r in LmRegionPositions.byCurrency(data.accounts, country))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Tooltip(
                      message: 'Click to view detailed account positions',
                      child: CfLink(label: '${r.count}', size: 14, onTap: () => _open(context, r.currency)),
                    ),
                  ),
                ),
                Text(_money(r.balance, r.currency)),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Assets & Liabilities (`assets-and-liabilities`, titled "Balances
/// Summary"): converted Assets and Liabilities bars and the Net Positions;
/// a bar opens the Accounts Summary for that side.
class LmBalancesSummary extends ConsumerStatefulWidget {
  const LmBalancesSummary({super.key});

  static const assetsColor = CorpChartColors.primary;
  static const liabilitiesColor = Color(0xFFE5484D);

  @override
  ConsumerState<LmBalancesSummary> createState() => _LmBalancesSummaryState();
}

class _LmBalancesSummaryState extends ConsumerState<LmBalancesSummary> {
  String? _currency;

  @override
  Widget build(BuildContext context) => LmWidgetCard(
        title: 'Balances Summary',
        child: lmLoad(
          ref.watch(lmAssetsBalancesProvider),
          failed: 'We couldn\'t load the accounts.',
          onRetry: () => ref.invalidate(lmAssetsBalancesProvider),
          data: (data) {
            final currency = _currency ?? data.defaultCurrency;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LmCurrencyField(
                  label: 'Assets & Liabilities with Net Position',
                  currencies: data.currencies,
                  selected: currency,
                  onSelected: (c) => setState(() => _currency = c),
                ),
                const SizedBox(height: 14),
                if (currency == null || data.accounts.isEmpty)
                  const LmEmpty(title: 'No data to display')
                else
                  lmLoad(
                    ref.watch(lmAssetsLiabilitiesProvider(currency)),
                    failed: 'We couldn\'t load the exchange rates.',
                    onRetry: () => ref.invalidate(lmAssetsLiabilitiesProvider(currency)),
                    data: (al) => al.missingRate
                        ? const LmEmpty(title: 'Exchange rate not found', icon: Icons.currency_exchange_rounded)
                        : _chart(context, data, al, currency),
                  ),
              ],
            );
          },
        ),
      );

  Widget _chart(BuildContext context, LmBalances data, LmAssetsLiabilities al, String currency) {
    final top = [al.assets, al.liabilities].reduce((a, b) => a > b ? a : b);
    Widget bar(String label, double value, Color color, bool assets) => Expanded(
          child: Semantics(
            button: true,
            label: '$label: ${_money(value, currency)}',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showLmAccounts(
                context,
                title: 'Accounts Summary',
                accounts: LmAssetsLiabilities.accountsFor(data.accounts, assets: assets),
                partyName: data.partyName,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      child: Text(_money(value, currency),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: top == 0 ? 2 : (140 * value / top).clamp(2, 140).toDouble(),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              bar('Assets', al.assets, LmBalancesSummary.assetsColor, true),
              bar('Liabilities', al.liabilities, LmBalancesSummary.liabilitiesColor, false),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          children: const [
            CorpLegendDot(color: LmBalancesSummary.assetsColor, label: 'Assets'),
            CorpLegendDot(color: LmBalancesSummary.liabilitiesColor, label: 'Liabilities'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Net Positions :', style: TextStyle(color: CorpColors.textSecondary(context))),
            const SizedBox(width: 8),
            Text(_money(al.net, currency),
                style: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
          ],
        ),
      ],
    );
  }
}
