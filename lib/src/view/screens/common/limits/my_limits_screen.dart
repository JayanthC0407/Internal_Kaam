import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/limits/my_limits_models.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/view/providers/common/my_limits_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Account Settings → My Limits (OBDX `limits-enquiry/my-limit`): pick a
/// Channel and a Transaction, then a limit tab; Daily and Monthly Limits
/// each show Amount and Count as Utilized / Available / Total.
/// Evidence and the app's deliberate differences:
/// docs/obdx/features/my-limits.md.
class MyLimitsScreen extends StatelessWidget {
  const MyLimitsScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PayMenuPage(
      title: l10n.myLimitsTitle,
      subtitle: l10n.menuAccountSettings,
      onBack: embedded ? onBack : null,
      builder: (context, wide) => MyLimitsView(wide: wide),
    );
  }
}

/// My Limits without its page: the pickers and the limits. Also shown in
/// Preferences → Limits & Controls. Laid out as the designer's Limits page
/// (UI designs 2026-10-27): boxed Channel / Transactions, the tab label as
/// the heading with OBDX's limit tabs in a dropdown beside it, and white
/// Daily / Monthly Limits cards. A choice reloads at once (no Apply).
class MyLimitsView extends ConsumerStatefulWidget {
  const MyLimitsView({super.key, required this.wide});

  /// Pickers side by side and the wide limit layout.
  final bool wide;

  @override
  ConsumerState<MyLimitsView> createState() => _MyLimitsViewState();
}

class _MyLimitsViewState extends ConsumerState<MyLimitsView> {
  String? _channelId;
  String? _transactionId;

  /// OBDX goes back to the first tab whenever the transaction changes.
  LimitTab _tab = LimitTab.transaction;

  Future<void> _pickChannel(List<LimitChannel> channels, LimitChannel current) async {
    final picked = await showPayPicker<String>(
      context,
      title: AppLocalizations.of(context).limitsChannel,
      selected: current.id,
      options: [for (final c in channels) PayOption(value: c.id, title: c.description, icon: Icons.devices_outlined)],
    );
    if (picked != null && mounted) setState(() => _channelId = picked);
  }

  Future<void> _pickTransaction(List<LimitTransaction> transactions, LimitTransaction current) async {
    final picked = await showPayPicker<String>(
      context,
      title: AppLocalizations.of(context).limitsTransactions,
      selected: current.id,
      options: [for (final t in transactions) PayOption(value: t.id, title: t.name)],
    );
    if (picked != null && mounted) {
      setState(() {
        _transactionId = picked;
        _tab = LimitTab.transaction;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final channels = ref.watch(limitChannelsProvider);
    final transactions = ref.watch(limitTransactionsProvider);

    Widget loading() => const PayCard(
          child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        );
    Widget failed(Object error, VoidCallback retry) => PayErrorRetry(
          message: error is LimitsLoadError && error.message != null ? error.message! : l10n.limitsLoadFailed,
          onRetry: retry,
        );

    final wide = widget.wide;
    return channels.when(
        loading: loading,
        error: (e, _) => failed(e, () => ref.invalidate(limitChannelsProvider)),
        data: (channelList) {
          final channel = channelList.where((c) => c.id == _channelId).firstOrNull ?? LimitChannel.defaultOf(channelList);
          if (channel == null) return PayCard(child: PayMuted(l10n.limitsLoadFailed));
          return transactions.when(
            loading: loading,
            error: (e, _) => failed(e, () => ref.invalidate(limitTransactionsProvider)),
            data: (txnList) {
              if (txnList.isEmpty) return PayCard(child: PayMuted(l10n.limitsNoTransactions));
              final txn = txnList.firstWhere((t) => t.id == _transactionId, orElse: () => txnList.first);
              final pickers = [
                _Picker(
                  label: l10n.limitsChannel,
                  value: channel.description,
                  onTap: channelList.length > 1 ? () => _pickChannel(channelList, channel) : null,
                ),
                _Picker(
                  label: l10n.limitsTransactions,
                  value: txn.name,
                  onTap: txnList.length > 1 ? () => _pickTransaction(txnList, txn) : null,
                ),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PayCard(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: pickers[0]),
                              const SizedBox(width: 16),
                              Expanded(child: pickers[1]),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [pickers[0], const SizedBox(height: 14), pickers[1]],
                          ),
                  ),
                  const SizedBox(height: 22),
                  ref.watch(myLimitsProvider(channel.id)).when(
                        loading: loading,
                        error: (e, _) => failed(e, () => ref.invalidate(myLimitsProvider(channel.id))),
                        data: (limits) => _LimitsBody(
                          limits: limits,
                          transaction: txn,
                          channelName: channel.description,
                          tab: limits.tabs.contains(_tab) ? _tab : (limits.tabs.firstOrNull ?? LimitTab.transaction),
                          wide: wide,
                          onTab: (t) => setState(() => _tab = t),
                        ),
                      ),
                ],
              );
            },
          );
        },
      );
  }
}

String limitTabLabel(AppLocalizations l10n, LimitTab tab, String taskName) => switch (tab) {
      LimitTab.transaction => l10n.limitsTabTransaction(taskName),
      LimitTab.transactionGroup => l10n.limitsTabTransactionGroup,
      LimitTab.channelGroup => l10n.limitsTabChannelGroup,
      LimitTab.channelTransactionGroup => l10n.limitsTabChannelTransactionGroup,
      LimitTab.consolidated => l10n.limitsTabConsolidated,
      LimitTab.consolidatedTransactionGroup => l10n.limitsTabConsolidatedTransactionGroup,
    };

class _Picker extends StatelessWidget {
  const _Picker({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PayBoxedPicker(label: label, value: value, onTap: onTap);
}

/// The selected tab's limits: its label as the heading, OBDX's other tabs
/// in a dropdown beside it (no field label: OBDX's tabs have none), then
/// the Daily and Monthly Limits cards.
class _LimitsBody extends StatelessWidget {
  const _LimitsBody({
    required this.limits,
    required this.transaction,
    required this.channelName,
    required this.tab,
    required this.wide,
    required this.onTab,
  });

  final MyLimits limits;
  final LimitTransaction transaction;
  final String channelName;
  final LimitTab tab;
  final bool wide;
  final ValueChanged<LimitTab> onTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slot = limits.slotFor(transaction.id, tab);
    final label = limitTabLabel(l10n, tab, transaction.name);
    final range = limits.effectiveSameDay ? slot?.amountRange : null;

    final heading = Text(
      label,
      style: TextStyle(fontSize: wide ? 22 : 18, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
    );
    final Widget? dropdown = limits.tabs.length <= 1
        ? null
        : _TabDropdown(
            tabs: [for (final t in limits.tabs) (t, limitTabLabel(l10n, t, transaction.name))],
            selected: tab,
            onTab: onTab,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Row(
            children: [
              Expanded(child: heading),
              if (dropdown != null) ...[const SizedBox(width: 16), SizedBox(width: 360, child: dropdown)],
            ],
          )
        else ...[
          heading,
          if (dropdown != null) ...[const SizedBox(height: 10), dropdown],
        ],
        if (range != null) ...[
          const SizedBox(height: 12),
          _AmountRange(range: range),
        ],
        const SizedBox(height: 16),
        _PeriodPair(
          daily: _PeriodCard(
            title: l10n.limitsDaily,
            limit: slot?.daily,
            emptyText: l10n.limitsDailyNotAssigned(channelName),
          ),
          monthly: _PeriodCard(
            title: l10n.limitsMonthly,
            limit: slot?.monthly,
            emptyText: l10n.limitsMonthlyNotAssigned(channelName),
          ),
          sideBySide: wide,
        ),
      ],
    );
  }
}

/// OBDX's limit tabs as the design's dropdown: the selected tab's label
/// and a chevron, the list in the app's picker.
class _TabDropdown extends StatelessWidget {
  const _TabDropdown({required this.tabs, required this.selected, required this.onTab});

  final List<(LimitTab, String)> tabs;
  final LimitTab selected;
  final ValueChanged<LimitTab> onTab;

  @override
  Widget build(BuildContext context) {
    final current = tabs.where((t) => t.$1 == selected).firstOrNull?.$2 ?? '';
    return Semantics(
      button: true,
      child: Material(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final picked = await showPayPicker<LimitTab>(
              context,
              title: current,
              selected: selected,
              options: [for (final (t, label) in tabs) PayOption(value: t, title: label)],
            );
            if (picked != null) onTab(picked);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HomeColors.divider(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    current,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: HomeColors.textPrimary(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountRange extends StatelessWidget {
  const _AmountRange({required this.range});

  final TransactionAmountRange range;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget item(String label, double? amount, String currency) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context))),
              const SizedBox(height: 2),
              Text(
                amount == null ? '-' : MoneyFormat.format(amount, currencyCode: currency),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
              ),
            ],
          ),
        );
    return Row(
      children: [
        item(l10n.limitsMinimumAmount, range.min, range.minCurrency),
        const SizedBox(width: 12),
        item(l10n.limitsMaximumAmount, range.max, range.maxCurrency),
      ],
    );
  }
}

class _PeriodPair extends StatelessWidget {
  const _PeriodPair({required this.daily, required this.monthly, required this.sideBySide});

  final Widget daily;
  final Widget monthly;
  final bool sideBySide;

  @override
  Widget build(BuildContext context) => sideBySide
      ? IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: daily), const SizedBox(width: 12), Expanded(child: monthly)],
          ),
        )
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [daily, const SizedBox(height: 12), monthly]);
}

/// Daily Limits or Monthly Limits: an Amount and a Count donut, or OBDX's
/// "not assigned" text.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.title, required this.limit, required this.emptyText});

  final String title;
  final PeriodicLimit? limit;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final l = limit;
    final brand = HomeColors.brand(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context))),
          const SizedBox(height: 14),
          if (l == null || !l.isAssigned)
            // The design's empty panel, with OBDX's sentence kept whole.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              decoration: BoxDecoration(
                color: HomeColors.backgroundSecondary(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: brand.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: brand.withValues(alpha: 0.25)),
                    ),
                    child: Icon(Icons.receipt_long_outlined, color: brand, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context)),
                  ),
                ],
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LimitDonut(
                    label: l10n.limitsAmount,
                    percent: l.amountPercent,
                    used: l.utilizedAmount > 0,
                    utilized: MoneyFormat.format(l.utilizedAmount, currencyCode: l.currency),
                    available: MoneyFormat.format(l.availableAmount, currencyCode: l.currency),
                    total: l.maxAmount == null ? '-' : MoneyFormat.format(l.maxAmount!, currencyCode: l.currency),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LimitDonut(
                    label: l10n.limitsCount,
                    percent: l.countPercent,
                    used: l.utilizedCount > 0,
                    utilized: '${l.utilizedCount}',
                    available: '${l.availableCount}',
                    total: l.maxCount == null ? '-' : '${l.maxCount}',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// my-limits-graph: a donut with "N%" (plus "Utilized" once something is
/// used) and the Utilized / Available / Total legend.
class _LimitDonut extends StatelessWidget {
  const _LimitDonut({
    required this.label,
    required this.percent,
    required this.used,
    required this.utilized,
    required this.available,
    required this.total,
  });

  final String label;
  final int percent;
  final bool used;
  final String utilized;
  final String available;
  final String total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usedColor = HomeColors.brand(context);
    final freeColor = HomeColors.success(context);
    final secondary = HomeColors.textSecondary(context);
    final primary = HomeColors.textPrimary(context);

    Widget legend(Color? dot, String name, String value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot ?? Colors.transparent, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 11.5, color: secondary)),
                    Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: primary)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: secondary)),
        const SizedBox(height: 8),
        Center(
          child: Semantics(
            label: '$label $percent% ${l10n.limitsUtilized}',
            child: SizedBox.square(
              dimension: 96,
              child: CustomPaint(
                painter: _DonutPainter(
                  fraction: percent / 100,
                  used: usedColor,
                  free: freeColor.withValues(alpha: 0.55),
                ),
                child: Center(
                  child: Text(
                    used ? '$percent%\n${l10n.limitsUtilized}' : '$percent%',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: used ? 12 : 15, fontWeight: FontWeight.w700, color: primary, height: 1.2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        legend(usedColor, l10n.limitsUtilized, utilized),
        legend(freeColor, l10n.limitsAvailable, available),
        legend(null, l10n.limitsTotal, total),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.fraction, required this.used, required this.free});

  final double fraction;
  final Color used;
  final Color free;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = free);
    if (fraction > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction.clamp(0, 1), false, paint..color = used);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.fraction != fraction || old.used != used || old.free != free;
}
