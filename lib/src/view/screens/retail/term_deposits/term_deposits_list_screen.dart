import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/providers/retail/term_deposit_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_route_args.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/widgets/td_shared_widgets.dart';

/// "Term Deposits" — the customer's deposits from
/// `GET /digx-common/td/v1/deposit` (active and closed): a portfolio
/// banner, an Active / Closed switch and a card per deposit, opening
/// the deposit details screen. "Open deposit" starts a new one.
///
/// Wide screens lay the cards out two or three a row; phones stack them.
class TermDepositsListScreen extends ConsumerStatefulWidget {
  const TermDepositsListScreen({
    super.key,
    this.embedded = false,
    this.onDepositSelected,
    this.onBack,
  });

  /// Rendered inside the desktop dashboard shell, beside the side menu.
  final bool embedded;

  /// Called instead of pushing the details route when [embedded].
  final ValueChanged<TermDeposit>? onDepositSelected;
  final VoidCallback? onBack;

  @override
  ConsumerState<TermDepositsListScreen> createState() =>
      _TermDepositsListScreenState();
}

class _TermDepositsListScreenState
    extends ConsumerState<TermDepositsListScreen> {
  bool _showClosed = false;
  bool _hidden = false;
  String? _currency;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(termDepositsProvider.notifier).ensureLoaded();
    });
  }

  void _open(TermDeposit deposit) {
    HapticFeedback.selectionClick();
    final onSelected = widget.onDepositSelected;
    if (widget.embedded && onSelected != null) {
      onSelected(deposit);
      return;
    }
    Navigator.of(context).pushNamed(
      RoutesConst.termDepositDetailsScreen,
      arguments: TermDepositDetailsArgs(deposit: deposit),
    );
  }

  Future<void> _openNew() async {
    HapticFeedback.selectionClick();
    final opened =
        await Navigator.of(context).pushNamed(RoutesConst.tdOpenScreen);
    if (opened == true && mounted) {
      ref.read(termDepositsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = Responsive.of(context).useWideLayout;
    final state = ref.watch(termDepositsProvider);
    final summary = state.summary;

    final openButton = wide
        ? FilledButton.icon(
            onPressed: _openNew,
            style: FilledButton.styleFrom(
              backgroundColor: HomeColors.brand(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.tdOpenDeposit),
          )
        : IconButton.filled(
            tooltip: l10n.tdOpenDeposit,
            onPressed: _openNew,
            style: IconButton.styleFrom(
              backgroundColor: HomeColors.brand(context),
            ),
            icon: const Icon(Icons.add_rounded),
          );

    Widget body;
    if (state.isLoading && summary == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (summary == null) {
      body = TdOuterCard(
        child: TdErrorRetry(
          message: state.errorMessage ?? l10n.tdLoadFailed,
          onRetry: () => ref.read(termDepositsProvider.notifier).refresh(),
        ),
      );
    } else {
      final deposits = _showClosed ? summary.closed : summary.active;
      final totals = summary.totals;
      final current = totals.isEmpty
          ? null
          : totals.firstWhere(
              (t) => t.currency == _currency,
              orElse: () => totals.first,
            );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorMessage != null) ...[
            _Notice(message: state.errorMessage!),
            const SizedBox(height: 12),
          ],
          if (current != null)
            _PortfolioBanner(
              totals: current,
              currencies: [for (final t in totals) t.currency],
              onCurrency: (c) => setState(() => _currency = c),
              hidden: _hidden,
              onToggleHidden: () => setState(() => _hidden = !_hidden),
              wide: wide,
            ),
          const SizedBox(height: 18),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: TdSegmented<bool>(
                options: [
                  (false, '${l10n.tdActive} (${summary.active.length})'),
                  (true, '${l10n.tdClosed} (${summary.closed.length})'),
                ],
                selected: _showClosed,
                onChanged: (v) => setState(() => _showClosed = v),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (deposits.isEmpty)
            TdOuterCard(
              child: _EmptyState(
                message: _showClosed ? l10n.tdNoClosed : l10n.tdNoDeposits,
                onOpen: _showClosed ? null : _openNew,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 640
                        ? 2
                        : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - (columns - 1) * gap) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final d in deposits)
                      SizedBox(
                        width: width,
                        child: TdDepositCard(
                          deposit: d,
                          hidden: _hidden,
                          onTap: () => _open(d),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 28 : 16,
                wide ? 36 : 24,
                wide ? 28 : 16,
                8,
              ),
              child: CasaScreenHeader(
                title: l10n.menuTermDeposits,
                wide: wide,
                onBack: widget.onBack,
                trailing: openButton,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(termDepositsProvider.notifier).refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    wide ? 28 : 16,
                    8,
                    wide ? 28 : 16,
                    28,
                  ),
                  children: [body],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HomeColors.warning(context).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 12.5,
            color: HomeColors.textPrimary(context),
          ),
        ),
      );
}

/// Totals for one currency: invested, maturity value, expected interest.
class _PortfolioBanner extends StatelessWidget {
  const _PortfolioBanner({
    required this.totals,
    required this.currencies,
    required this.onCurrency,
    required this.hidden,
    required this.onToggleHidden,
    required this.wide,
  });

  final TdCurrencyTotals totals;
  final List<String> currencies;
  final ValueChanged<String> onCurrency;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String money(double v) =>
        MoneyFormat.format(v, currencyCode: totals.currency, hidden: hidden);
    final muted = TextStyle(
      fontSize: 12,
      color: Colors.white.withValues(alpha: 0.8),
    );

    Widget stat(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: muted),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );

    final stats = [
      stat(l10n.tdMaturityValue, money(totals.maturity)),
      stat(l10n.tdExpectedInterest, money(totals.expectedInterest)),
      stat(l10n.tdDepositCount, '${totals.count}'),
    ];

    return Container(
      padding: EdgeInsets.all(wide ? 24 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [HomeColors.brand(context), HomeColors.brandDark(context)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.tdTotalInvested, style: muted)),
              if (currencies.length > 1)
                for (final c in currencies)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: c == totals.currency,
                      onSelected: (_) => onCurrency(c),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  money(totals.invested),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: wide ? 30 : 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: hidden ? l10n.tdShowAmounts : l10n.tdHideAmounts,
                onPressed: onToggleHidden,
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (wide)
            Row(
              children: [
                for (final s in stats) Expanded(child: s),
              ],
            )
          else
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: stats,
            ),
        ],
      ),
    );
  }
}

/// One deposit in the list.
class TdDepositCard extends ConsumerWidget {
  const TdDepositCard({
    super.key,
    required this.deposit,
    required this.onTap,
    this.hidden = false,
  });

  final TermDeposit deposit;
  final VoidCallback onTap;
  final bool hidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final today = ref.watch(tdBusinessDateProvider).valueOrNull;
    final d = deposit;
    final days = today == null ? null : d.daysToMaturity(today);
    final progress = _progress(d, today);
    final brand = HomeColors.brand(context);

    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.savings_outlined, color: brand, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.tdTermDeposit} ••${d.lastFour}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HomeColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          d.displayNumber,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: HomeColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TdStatusPill(status: d.status ?? 'ACTIVE'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                l10n.tdCurrentBalance,
                style: TextStyle(
                  fontSize: 11.5,
                  color: HomeColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tdMoney(d.currentValue,
                    currency: d.currencyCode, hidden: hidden),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: HomeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Fact(
                      label: l10n.tdInterestRate,
                      value: tdRate(d.interestRate)),
                  _Fact(
                    label: l10n.tdMaturityAmount,
                    value: tdMoney(
                      d.maturityAmount,
                      currency: d.currencyCode,
                      hidden: hidden,
                    ),
                  ),
                ],
              ),
              if (d.isActive) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: HomeColors.divider(context),
                    color: brand,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l10n.tdMaturityDate}: ${tdDate(d.maturityDate)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: HomeColors.textSecondary(context),
                        ),
                      ),
                    ),
                    if (days != null)
                      Text(
                        days > 0 ? l10n.tdMaturesInDays(days) : l10n.tdMatured,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: days > 30
                              ? HomeColors.textSecondary(context)
                              : HomeColors.warning(context),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// How far the deposit is through its term (opening → maturity).
  static double? _progress(TermDeposit d, DateTime? today) {
    final start = d.valueDate ?? d.openingDate;
    final end = d.maturityDate;
    if (today == null || start == null || end == null) return null;
    final total = end.difference(start).inDays;
    if (total <= 0) return 1;
    return (today.difference(start).inDays / total).clamp(0.0, 1.0);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: HomeColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.onOpen});

  final String message;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.savings_outlined,
            size: 44,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
          if (onOpen != null) ...[
            const SizedBox(height: 16),
            TdPrimaryButton(
              label: l10n.tdOpenDeposit,
              icon: Icons.add_rounded,
              onPressed: onOpen,
            ),
          ],
        ],
      ),
    );
  }
}
