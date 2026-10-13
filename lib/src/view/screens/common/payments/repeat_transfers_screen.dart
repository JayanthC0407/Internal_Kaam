import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/payment/standing_instruction.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/network_transfer_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/common/payments/network_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// `status` values of `GET payments/instructions`.
const kInstructionsActive = 'ACTIVE';
const kInstructionsStopped = 'CANCELLED';

/// Repeat Transfers Inquiry — OBDX's `standing-instructions-list`: the
/// active and the closed repeat transfers, each opening View Repeat
/// Transfer (schedule, payments history, "Stop").
///
/// New repeat transfers are made by Repeat Transfers - Existing / Adhoc
/// Payee ([NetworkTransferScreen] in a repeat mode) — [onNewTap].
class RepeatTransfersScreen extends ConsumerStatefulWidget {
  const RepeatTransfersScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onNewTap,
  });

  final bool embedded;
  final VoidCallback? onBack;

  /// Starts a new repeat transfer inside the dashboard; when null the
  /// repeat flow's route is pushed.
  final VoidCallback? onNewTap;

  @override
  ConsumerState<RepeatTransfersScreen> createState() => _RepeatTransfersScreenState();
}

class _RepeatTransfersScreenState extends ConsumerState<RepeatTransfersScreen> {
  bool _showActive = true;
  String _query = '';

  void _new() {
    final tap = widget.onNewTap;
    if (tap != null) return tap();
    Navigator.of(context).pushNamed(
      RoutesConst.networkTransferScreen,
      arguments: NetworkTransferMode.repeatExistingPayee,
    );
  }

  Future<void> _open(StandingInstruction si) async {
    final message = await showRepeatTransferDetail(context, si);
    if (message == null || !mounted) return;
    // Stopped: both lists change.
    ref.invalidate(standingInstructionsProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(standingInstructionsProvider(kInstructionsActive));
    final stopped = ref.watch(standingInstructionsProvider(kInstructionsStopped));
    final current = _showActive ? active : stopped;
    final items = current.valueOrNull?.items ?? const <StandingInstruction>[];
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? items
        : items
            .where((si) => [si.payeeName, si.reference, si.frequencyLabel, si.debitAccount ?? '']
                .any((v) => v.toLowerCase().contains(q)))
            .toList();

    String count(AsyncValue<StandingInstructionPage> v) =>
        v.hasValue ? ' (${v.value!.total})' : '';

    return PayMenuPage(
      title: 'Repeat Transfers Inquiry',
      subtitle: 'Payments the bank makes for you on a schedule',
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) {
        final switcher = PaySegmented<bool>(
          options: [(true, 'Active${count(active)}'), (false, 'Closed${count(stopped)}')],
          selected: _showActive,
          onChanged: (v) => setState(() => _showActive = v),
        );
        final search = TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: payInputDecoration(
            context,
            hint: 'Search By Payee Name',
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
              child: Icon(Icons.search_rounded, size: 20, color: HomeColors.textSecondary(context)),
            ),
          ),
        );

        final Widget list;
        if (current.hasError) {
          list = Padding(
            padding: const EdgeInsets.all(10),
            child: PayErrorRetry(
              message: "We couldn't load your repeat transfers.",
              onRetry: () => ref.invalidate(
                standingInstructionsProvider(_showActive ? kInstructionsActive : kInstructionsStopped),
              ),
            ),
          );
        } else if (current.isLoading) {
          list = Column(children: [for (var i = 0; i < 3; i++) const _InstructionLine.placeholder()]);
        } else if (items.isEmpty) {
          list = _EmptyList(active: _showActive, onNew: _new);
        } else if (shown.isEmpty) {
          list = Padding(
            padding: const EdgeInsets.all(14),
            child: PayMuted('Nothing matches "${_query.trim()}".'),
          );
        } else {
          list = Column(
            children: [
              if (wide) const _HeaderLine(),
              for (final (i, si) in shown.indexed)
                _InstructionLine(
                  instruction: si,
                  wide: wide,
                  last: i == shown.length - 1,
                  onTap: () => _open(si),
                ),
            ],
          );
        }
        final total = current.valueOrNull?.total ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                children: [
                  Expanded(child: switcher),
                  const SizedBox(width: 16),
                  SizedBox(width: 280, child: search),
                  const SizedBox(width: 12),
                  PayPrimaryButton(
                    label: 'New Repeat Transfer',
                    icon: Icons.add_rounded,
                    onPressed: _new,
                  ),
                ],
              )
            else ...[
              switcher,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'New Repeat Transfer',
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: FilledButton(
                        onPressed: _new,
                        style: FilledButton.styleFrom(
                          backgroundColor: HomeColors.brand(context),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Icon(Icons.add_rounded, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            PaySection(padding: wide ? 8 : 6, child: list),
            if (total > items.length && items.isNotEmpty) ...[
              const SizedBox(height: 8),
              PayMuted('Showing the latest ${items.length} of $total.'),
            ],
          ],
        );
      },
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: HomeColors.textSecondary(context),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HomeColors.divider(context))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 54),
          Expanded(flex: 4, child: Text('Transfer To', style: style)),
          Expanded(flex: 3, child: Text('Frequency', style: style)),
          Expanded(flex: 3, child: Text('Next Payment', style: style)),
          Expanded(flex: 3, child: Text('Amount', style: style, textAlign: TextAlign.end)),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// One repeat transfer in the list.
class _InstructionLine extends StatelessWidget {
  const _InstructionLine({
    required StandingInstruction this.instruction,
    required this.wide,
    required this.last,
    required VoidCallback this.onTap,
  });

  const _InstructionLine.placeholder()
      : instruction = null,
        wide = false,
        last = false,
        onTap = null;

  final StandingInstruction? instruction;
  final bool wide;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final si = instruction;
    final grey = HomeColors.divider(context);
    final secondary = HomeColors.textSecondary(context);
    final decoration = BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: grey.withValues(alpha: 0.7))),
    );
    if (si == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: decoration,
        child: Row(
          children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: grey, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 140, height: 12, color: grey),
                const SizedBox(height: 6),
                Container(width: 200, height: 10, color: grey),
              ],
            ),
          ],
        ),
      );
    }

    final next = !si.active
        ? 'Closed'
        : si.nextDate == null
            ? '—'
            : payDate(si.nextDate);
    final amount = Text(
      payAmount(si.amount, si.currency),
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: si.active ? HomeColors.textPrimary(context) : secondary,
      ),
    );
    final name = Text(
      si.payeeName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: HomeColors.textPrimary(context),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: decoration,
          child: Row(
            children: [
              PayAvatar(name: si.payeeName, size: 42),
              const SizedBox(width: 12),
              if (wide) ...[
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      if (si.kindLabel != null)
                        Text(si.kindLabel!, style: TextStyle(fontSize: 12.5, color: secondary)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(si.frequencyLabel, style: TextStyle(fontSize: 13, color: HomeColors.textPrimary(context))),
                ),
                Expanded(
                  flex: 3,
                  child: Text(next, style: TextStyle(fontSize: 13, color: si.active ? HomeColors.textPrimary(context) : secondary)),
                ),
                Expanded(flex: 3, child: amount),
              ] else ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      const SizedBox(height: 2),
                      Text(
                        si.frequencyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // The amount, and when it next goes — the date is what
                // people look for, so it gets its own line, not a cut-off one.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    amount,
                    const SizedBox(height: 2),
                    Text(
                      si.active ? 'Next $next' : 'Closed',
                      style: TextStyle(fontSize: 12, color: secondary),
                    ),
                  ],
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.active, required this.onNew});

  final bool active;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            PayAvatar(
              name: 'Repeat',
              size: 56,
              icon: active ? Icons.event_repeat_rounded : Icons.event_busy_outlined,
            ),
            const SizedBox(height: 12),
            Text(
              active ? 'No repeat transfers yet' : 'No closed repeat transfers',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              active
                  ? 'Pay rent, bills or savings automatically — set it once and the bank does the rest.'
                  : 'Repeat transfers you stop will show here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
            ),
            if (active) ...[
              const SizedBox(height: 16),
              PaySecondaryButton(label: 'New Repeat Transfer', icon: Icons.add_rounded, onPressed: onNew),
            ],
          ],
        ),
      );
}

// ── Detail ───────────────────────────────────────────────────────────────

/// A repeat transfer's schedule, payment history and "Stop" — a dialog
/// on wide screens (as OBDX shows it), a tall sheet on a phone. Returns a
/// message to show when it was stopped, else null.
Future<String?> showRepeatTransferDetail(BuildContext context, StandingInstruction si) {
  final panel = _InstructionDetail(instruction: si);
  if (MediaQuery.sizeOf(context).width >= 768) {
    return showDialog<String>(
      context: context,
      builder: (dialog) => Dialog(
        backgroundColor: HomeColors.card(dialog),
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(dialog).height * 0.88,
          ),
          child: panel,
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.92),
      decoration: BoxDecoration(
        color: HomeColors.card(sheet),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(top: false, child: panel),
    ),
  );
}

class _InstructionDetail extends ConsumerStatefulWidget {
  const _InstructionDetail({required this.instruction});

  final StandingInstruction instruction;

  @override
  ConsumerState<_InstructionDetail> createState() => _InstructionDetailState();
}

class _InstructionDetailState extends ConsumerState<_InstructionDetail> {
  /// History rows shown before "Show all".
  static const _historyPreview = 5;

  bool _stopping = false;
  bool _allHistory = false;
  String? _error;

  StandingInstruction get si => widget.instruction;

  Future<void> _stop() async {
    if (!await _confirmStop()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(networkTransferRepositoryProvider);
    setState(() {
      _stopping = true;
      _error = null;
    });
    var result = await repository.stopInstruction(si);
    while (mounted &&
        result is Success<InstructionStopOutcome> &&
        result.data?.challenge != null) {
      final outcome = result.data!;
      if (!mounted) return;
      // Nothing is loading while they type the code.
      setState(() => _stopping = false);
      final otp = await showPayOtpPrompt(
        context,
        title: 'Verify to stop this repeat transfer',
        error: outcome.invalidOtp ? 'That code is not right. Please try again.' : null,
        attemptsLeft: outcome.challenge!.attemptsLeft,
      );
      if (!mounted) return;
      // Cancelled: nothing was stopped.
      if (otp == null) return;
      setState(() => _stopping = true);
      result = await repository.stopInstruction(si, challenge: outcome.challenge, otp: otp);
    }
    if (!mounted) return;
    if (result is Success<InstructionStopOutcome> && result.data != null) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(
        result.data!.pendingApproval
            ? 'Stopping the repeat transfer to ${si.payeeName} is waiting for approval.'
            : 'Repeat Transfer to ${si.payeeName} stopped.',
      );
      return;
    }
    setState(() {
      _stopping = false;
      _error = result.resolveUserMessage(
        l10n: l10n,
        fallback: "We couldn't stop this transfer. Please try again.",
      );
    });
  }

  Future<bool> _confirmStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: HomeColors.card(dialog),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // OBDX's own question (standing-instruction-detail).
        title: const Text('Are you sure you want to Stop Repeat Transfer?'),
        content: Text(
          "The bank won't make any more payments of ${payAmount(si.amount, si.currency)} "
          'to ${si.payeeName}. Payments already made are not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: HomeColors.error(dialog),
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // OBDX's field names (standing-instruction-detail).
    final rows = <(String, String)>[
      ('Frequency', si.frequencyLabel),
      if (si.active && si.nextDate != null) ('Next Payment', payDate(si.nextDate)),
      if (si.startDate != null) ('Start Date', payDate(si.startDate)),
      if (si.endsByCount)
        ('No. of Payments', '${si.instances}')
      else
        ('End Date', si.endDate != null ? payDate(si.endDate) : 'No end date'),
      if (si.debitAccount != null) ('Transfer From', payMask(si.debitAccount!)),
      if (si.kindLabel != null) ('Type', si.kindLabel!),
      ('Reference', si.reference),
      if (si.remarks != null) ('Note', si.remarks!),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
          child: Row(
            children: [
              const Expanded(child: PaySectionLabel('View Repeat Transfer')),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: HomeColors.textSecondary(context)),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              PayReceiptHero(
                amount: payAmount(si.amount, si.currency),
                toName: si.payeeName,
                toDetail: si.frequencyLabel,
                caption: si.active ? 'You pay' : 'You paid',
              ),
              const SizedBox(height: 12),
              for (final (i, (label, value)) in rows.indexed)
                PayReviewRow(label: label, value: value, last: i == rows.length - 1),
              const SizedBox(height: 18),
              const PaySectionLabel('Payments History'),
              const SizedBox(height: 6),
              _history(),
            ],
          ),
        ),
        // Pinned below the scrolling details, so "Stop" is always in reach.
        if (si.active)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: HomeColors.divider(context))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  PayFieldError(_error),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _stopping ? null : _stop,
                  icon: _stopping
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.block_rounded),
                  label: const Text('Stop Repeat Transfer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeColors.error(context),
                    minimumSize: const Size(0, 52),
                    side: BorderSide(color: HomeColors.error(context).withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _history() {
    final detail = ref.watch(standingInstructionDetailProvider(si));
    if (detail.hasError) {
      return PayErrorRetry(
        message: "We couldn't load the payment history.",
        onRetry: () => ref.invalidate(standingInstructionDetailProvider(si)),
      );
    }
    if (detail.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final history = detail.value!.history;
    if (history.isEmpty) return const PayMuted('No payments yet.');
    final shown = _allHistory ? history : history.take(_historyPreview).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final run in shown) _ExecutionLine(run),
        if (history.length > _historyPreview)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _allHistory = !_allHistory),
              child: Text(_allHistory ? 'Show fewer' : 'Show all ${history.length}'),
            ),
          ),
      ],
    );
  }
}

class _ExecutionLine extends StatelessWidget {
  const _ExecutionLine(this.run);

  final InstructionExecution run;

  @override
  Widget build(BuildContext context) {
    final tone = run.completed ? HomeColors.success(context) : HomeColors.error(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            run.completed ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 20,
            color: tone,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payDate(run.date),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
                if (!run.completed)
                  Text(
                    run.failureReason ?? 'Not paid',
                    style: TextStyle(fontSize: 12.5, color: tone),
                  ),
              ],
            ),
          ),
          Text(
            run.completed ? 'Completed' : 'Failed',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tone),
          ),
        ],
      ),
    );
  }
}
