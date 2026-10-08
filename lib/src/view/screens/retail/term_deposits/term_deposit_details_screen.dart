import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/account_transaction.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/infra/repositories/retail/term_deposit_repository.dart';
import 'package:ubci_bank/src/view/providers/retail/term_deposit_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_route_args.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/widgets/td_shared_widgets.dart';

export 'package:ubci_bank/src/view/screens/retail/term_deposits/td_route_args.dart'
    show TermDepositDetailsArgs;

/// One term deposit: `GET .../deposit/{id};module=` and its
/// `payOutInstructions`, plus its transactions — the sections of the OBDX
/// details screen (deposit, maturity, general) under a balance banner
/// with the deposit's actions: top up, redeem, edit maturity.
class TermDepositDetailsScreen extends ConsumerStatefulWidget {
  const TermDepositDetailsScreen({
    super.key,
    required this.args,
    this.embedded = false,
    this.onBack,
  });

  final TermDepositDetailsArgs args;

  /// Rendered inside the desktop dashboard shell, beside the side menu.
  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<TermDepositDetailsScreen> createState() =>
      _TermDepositDetailsScreenState();
}

class _TermDepositDetailsScreenState
    extends ConsumerState<TermDepositDetailsScreen> {
  bool _hidden = false;

  String get _id => widget.args.deposit.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(termDepositDetailProvider(_id).notifier).ensureLoaded();
    });
  }

  Future<void> _refresh() async {
    await ref.read(termDepositDetailProvider(_id).notifier).refresh();
    ref.invalidate(termDepositTransactionsProvider);
  }

  /// Opens an action; refreshes this deposit and the list when it's done.
  Future<void> _act(String route, TermDeposit deposit) async {
    HapticFeedback.selectionClick();
    final done = await Navigator.of(context).pushNamed(
      route,
      arguments: TdActionArgs(deposit: deposit),
    );
    if (done == true && mounted) {
      _refresh();
      ref.read(termDepositsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = Responsive.of(context).useWideLayout;
    final state = ref.watch(termDepositDetailProvider(_id));
    final deposit = state.deposit ?? widget.args.deposit;
    final pad = EdgeInsets.fromLTRB(wide ? 28 : 16, 8, wide ? 28 : 16, 28);

    Widget content;
    if (state.isLoading && state.deposit == null) {
      content = const TdOuterCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (state.deposit == null) {
      content = TdOuterCard(
        child: TdErrorRetry(
          message: state.errorMessage ?? l10n.tdDetailsLoadFailed,
          onRetry: _refresh,
        ),
      );
    } else {
      content = TdOuterCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Banner(
              deposit: deposit,
              hidden: _hidden,
              wide: wide,
              onToggleHidden: () => setState(() => _hidden = !_hidden),
              onTopUp: () => _act(RoutesConst.tdTopUpScreen, deposit),
              onRedeem: () => _act(RoutesConst.tdRedeemScreen, deposit),
              onEditMaturity: () =>
                  _act(RoutesConst.tdMaturityEditScreen, deposit),
            ),
            const SizedBox(height: 16),
            _DetailsPanels(
              deposit: deposit,
              state: state,
              wide: wide,
              hidden: _hidden,
              onEditMaturity: deposit.isActive
                  ? () => _act(RoutesConst.tdMaturityEditScreen, deposit)
                  : null,
            ),
            const SizedBox(height: 16),
            _TransactionsPanel(deposit: deposit),
          ],
        ),
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
                title: '${l10n.tdTermDeposit} ••${deposit.lastFour}',
                wide: wide,
                onBack: widget.onBack,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: pad,
                  children: [content],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner ───────────────────────────────────────────────────────────────

class _Banner extends ConsumerWidget {
  const _Banner({
    required this.deposit,
    required this.hidden,
    required this.wide,
    required this.onToggleHidden,
    required this.onTopUp,
    required this.onRedeem,
    required this.onEditMaturity,
  });

  final TermDeposit deposit;
  final bool hidden;
  final bool wide;
  final VoidCallback onToggleHidden;
  final VoidCallback onTopUp;
  final VoidCallback onRedeem;
  final VoidCallback onEditMaturity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final d = deposit;
    final today = ref.watch(tdBusinessDateProvider).valueOrNull;
    final days = today == null ? null : d.daysToMaturity(today);
    final muted = TextStyle(
      fontSize: 12,
      color: Colors.white.withValues(alpha: 0.82),
    );

    final balance = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.tdCurrentBalance, style: muted),
            InkResponse(
              onTap: onToggleHidden,
              radius: 18,
              child: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
                color: Colors.white,
              ),
            ),
            TdStatusPill(status: d.status ?? 'ACTIVE', onDark: true),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tdMoney(d.currentValue, currency: d.currencyCode, hidden: hidden),
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 30 : 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 28,
          runSpacing: 10,
          children: [
            _BannerStat(
              label: l10n.tdMaturityAmount,
              value: tdMoney(
                d.maturityAmount,
                currency: d.currencyCode,
                hidden: hidden,
              ),
            ),
            _BannerStat(
              label: l10n.tdMaturityDate,
              value: tdDate(d.maturityDate),
            ),
            _BannerStat(
              label: l10n.tdInterestRate,
              value: tdRate(d.interestRate),
            ),
          ],
        ),
        if (d.isActive && days != null) ...[
          const SizedBox(height: 10),
          Text(
            days > 0 ? l10n.tdMaturesInDays(days) : l10n.tdMatured,
            style: muted.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );

    final actions = d.isActive
        ? [
            _ActionButton(
              icon: Icons.add_card_outlined,
              label: l10n.tdTopUp,
              onTap: onTopUp,
            ),
            _ActionButton(
              icon: Icons.output_rounded,
              label: l10n.tdRedeem,
              onTap: onRedeem,
            ),
            _ActionButton(
              icon: Icons.event_repeat_rounded,
              label: l10n.tdEditMaturity,
              onTap: onEditMaturity,
            ),
          ]
        : const <Widget>[];

    return Container(
      padding: EdgeInsets.all(wide ? 22 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [HomeColors.brand(context), HomeColors.brandDark(context)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: wide && actions.isNotEmpty
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: balance),
                const SizedBox(width: 16),
                for (final a in actions) ...[a, const SizedBox(width: 10)],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                balance,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: actions[i]),
                      ],
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      );
}

/// A banner action: an icon over a label, on a translucent tile.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 92, minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Details panels ───────────────────────────────────────────────────────

class _DetailsPanels extends ConsumerWidget {
  const _DetailsPanels({
    required this.deposit,
    required this.state,
    required this.wide,
    required this.hidden,
    required this.onEditMaturity,
  });

  final TermDeposit deposit;
  final TdDetailState state;
  final bool wide;
  final bool hidden;
  final VoidCallback? onEditMaturity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final d = deposit;
    final rollOver =
        ref.watch(tdRollOverOptionsProvider).valueOrNull ?? const [];
    String money(dynamic v) =>
        tdMoney(v, currency: d.currencyCode, hidden: hidden);

    final depositPanel = TdPanel(
      title: l10n.tdDepositDetails,
      child: TdInfoGrid(
        columns: wide ? 3 : 2,
        items: [
          (l10n.tdOriginalPrincipal, money(d.principalAmount)),
          if (!d.isClosed)
            (l10n.tdCurrentPrincipal, money(d.currentPrincipalAmount)),
          (l10n.tdDepositDate, tdDate(d.valueDate ?? d.openingDate)),
          (l10n.tdDepositTerm, d.tenure.label),
          (l10n.tdInterestRate, tdRate(d.interestRate)),
          (l10n.tdHoldAmount, money(d.holdAmount)),
        ],
      ),
    );

    final payouts = state.payouts;
    final maturityPanel = TdPanel(
      title: l10n.tdMaturityDetails,
      trailing: onEditMaturity == null
          ? null
          : TextButton(onPressed: onEditMaturity, child: Text(l10n.tdEdit)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TdInfoGrid(
            columns: wide ? 3 : 2,
            items: [
              (l10n.tdMaturityAmount, money(d.maturityAmount)),
              (l10n.tdMaturityDate, tdDate(d.maturityDate)),
              (
                l10n.tdMaturityInstruction,
                tdRollOverLabel(d.rollOverType, rollOver),
              ),
            ],
          ),
          if (state.payoutsError != null)
            TdMuted(state.payoutsError!)
          else if (payouts != null && payouts.isNotEmpty) ...[
            Text(
              l10n.tdPayoutInstructions,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: HomeColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 6),
            for (final p in payouts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 16,
                      color: HomeColors.brand(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.tdPayoutLine(
                          (p.percentage ?? 100).toStringAsFixed(0),
                          p.componentType == 'I'
                              ? l10n.tdInterest
                              : p.componentType == 'P'
                                  ? l10n.tdPrincipal
                                  : l10n.tdPrincipalAndInterest,
                          p.accountLabel,
                        ),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: HomeColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );

    final generalPanel = TdPanel(
      title: l10n.tdGeneralDetails,
      child: TdInfoGrid(
        columns: wide ? 3 : 2,
        items: [
          (l10n.tdAccountNumber, d.displayNumber),
          (l10n.tdHoldingPattern, _holding(l10n, d.holdingPattern)),
          (l10n.tdPrimaryHolder, d.partyName ?? d.holderName ?? '—'),
          (l10n.tdBranch, d.branchName ?? d.branchCode ?? '—'),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        depositPanel,
        const SizedBox(height: 14),
        maturityPanel,
        const SizedBox(height: 14),
        generalPanel,
      ],
    );
  }

  static String _holding(AppLocalizations l10n, String? pattern) =>
      switch (pattern?.toUpperCase()) {
        'SINGLE' => l10n.tdHoldingSingle,
        'JOINT' => l10n.tdHoldingJoint,
        _ => pattern ?? '—',
      };
}

// ── Transactions ─────────────────────────────────────────────────────────

class _TransactionsPanel extends ConsumerStatefulWidget {
  const _TransactionsPanel({required this.deposit});

  final TermDeposit deposit;

  @override
  ConsumerState<_TransactionsPanel> createState() => _TransactionsPanelState();
}

class _TransactionsPanelState extends ConsumerState<_TransactionsPanel> {
  TdTransactionPeriod _period = TdTransactionPeriod.currentMonth;
  String _type = 'A';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = TdTransactionsQuery(
      depositId: widget.deposit.id,
      period: _period,
      type: _type,
    );
    final value = ref.watch(termDepositTransactionsProvider(query));
    final periods = {
      TdTransactionPeriod.currentMonth: l10n.tdPeriodCurrentMonth,
      TdTransactionPeriod.previousMonth: l10n.tdPeriodPreviousMonth,
      TdTransactionPeriod.previousQuarter: l10n.tdPeriodPreviousQuarter,
      TdTransactionPeriod.lastTen: l10n.tdPeriodLastTen,
    };

    return TdPanel(
      title: l10n.tdTransactions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final MapEntry(key: p, value: label) in periods.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: p == _period,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: TdSegmented<String>(
                options: [
                  ('A', l10n.tdTxnAll),
                  ('C', l10n.tdTxnCredits),
                  ('D', l10n.tdTxnDebits),
                ],
                selected: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
            ),
          ),
          const SizedBox(height: 6),
          value.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => TdErrorRetry(
              message: '$error',
              onRetry: () =>
                  ref.invalidate(termDepositTransactionsProvider(query)),
            ),
            data: (items) => items.isEmpty
                ? TdMuted(l10n.tdNoTransactions)
                : Column(
                    children: [
                      for (final t in items) _TransactionRow(transaction: t),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final AccountTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final credit = t.direction == TransactionDirection.credit;
    final tone =
        credit ? HomeColors.success(context) : HomeColors.textPrimary(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HomeColors.divider(context))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              credit ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 16,
              color: tone,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.description.isEmpty ? '—' : t.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [tdDate(t.date), if (t.reference.isNotEmpty) t.reference]
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${credit ? '+' : '−'}${tdMoney(t.amount)}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}
