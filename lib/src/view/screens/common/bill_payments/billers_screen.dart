import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/add_biller_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/bill_payment_history_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/edit_biller_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/pay_bill_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/pay_bills_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/widgets/bills_help_panel.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Billers — OBDX `manage-bill-payments` (Bill Payments → Billers).
///
/// The user's registered billers, searchable by nickname and category, in
/// the designer's layout (UI designs 2026-10-27): one table on web (Biller
/// Name, Bill Type, Status, Bill Amount, Actions), cards on a phone, in
/// OBDX's group order. Presented bills get a tick box for Select all to Pay
/// (manage-bill-payments-list/hooks.js:156-248). Delete follows OBDX's
/// rules (blocked while auto pay / a scheduled payment is active) and asks
/// for an OTP when the bank wants one. Add Billers, Edit Biller (Manual
/// billers), Pay Bill (one bill, flows/pay-bill) and Pay Bills (several,
/// initiate-multiple-bill-payments) open in place.
/// Evidence: docs/obdx/features/bill-payments.md §3-4.
class BillersScreen extends ConsumerStatefulWidget {
  const BillersScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<BillersScreen> createState() => _BillersScreenState();
}

class _BillersScreenState extends ConsumerState<BillersScreen> {
  String _query = '';

  /// Biller Details shown in place of the list (works embedded and pushed).
  RegisteredBiller? _open;

  /// Add Billers shown in place of the list.
  bool _adding = false;

  /// Bill Payment History shown in place of the list (OBDX's page action).
  bool _history = false;

  /// Edit Biller shown in place of the list or details.
  RegisteredBiller? _editing;

  /// Registration ids being deleted.
  final _deleting = <String>{};

  /// Ticked for Select all to Pay (registration ids).
  final _selected = <String>{};

  /// Pay Bill shown in place of the list or details, and whether it came
  /// from a row's Pay (OBDX `isSinglePay`) or from Select all to Pay.
  RegisteredBiller? _paying;
  bool _payingSingle = true;

  /// Pay Bills (two or more ticked) shown in place of the list.
  List<RegisteredBiller>? _payingMany;

  DateTime get _today => DateTime.now();

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// A row's or Details' Pay (OBDX `showPayBill(id, true)`).
  void _pay(RegisteredBiller biller) => setState(() {
        _paying = biller;
        _payingSingle = true;
      });

  /// Pay for the ticked bills (OBDX `payAllSelectedBills`,
  /// manage-bill-payments-list/hooks.js:215-248): one goes to Pay Bill
  /// (`showPayBill(id, false)`), several to Pay Bills
  /// (initiate-multiple-bill-payments), in the list's order.
  void _paySelected(List<RegisteredBiller> all) {
    final l10n = AppLocalizations.of(context);
    if (_selected.isEmpty) return _snack(l10n.billersSelectAtLeastOne);
    final ticked = groupBillers(all).values.expand((g) => g).where((b) => _selected.contains(b.id)).toList();
    if (ticked.isEmpty) return;
    setState(() {
      if (ticked.length == 1) {
        _paying = ticked.first;
        _payingSingle = false;
      } else {
        _payingMany = ticked;
      }
    });
  }

  /// Leaves Pay Bill for the list; after a payment the list reloads (the
  /// provider is invalidated by Pay Bill) and the ticks are cleared.
  void _closePay({bool paid = false}) => setState(() {
        _paying = null;
        _payingMany = null;
        if (paid) {
          _open = null;
          _selected.clear();
        }
      });

  void _edit(RegisteredBiller biller) {
    final l10n = AppLocalizations.of(context);
    // OBDX refuses edits while a change awaits approval (hooks.js:476-479).
    if (!biller.canEdit) return _snack(l10n.billerEditPending);
    // Only Manual billers so far: their existing Auto Pay / Scheduled Pay
    // instruction would go back in the PUT (bill-payments.md §6.4).
    if (biller.hasPaymentInstruction) return _snack(l10n.editBillerPaymentInstructionSoon);
    setState(() => _editing = biller);
  }

  Future<void> _delete(RegisteredBiller biller) async {
    final l10n = AppLocalizations.of(context);
    // OBDX blocks delete while auto pay / a scheduled payment is active
    // (hooks.js:491-499).
    if (!biller.canDelete(_today)) return _snack(l10n.billerDeleteBlocked);
    if (!await _confirmDelete()) return;
    if (!mounted) return;

    final repository = ref.read(billPaymentsRepositoryProvider);
    setState(() => _deleting.add(biller.id));
    var result = await repository.deleteRegisteredBiller(biller.id, body: biller.raw);
    while (mounted &&
        result is Success<BillerDeleteOutcome> &&
        result.data?.challenge != null) {
      final outcome = result.data!;
      setState(() => _deleting.remove(biller.id));
      if (!mounted) return;
      final otp = await showPayOtpPrompt(
        context,
        title: l10n.billerDeleteOtpTitle(biller.nickname),
        error: outcome.invalidOtp ? l10n.billerOtpInvalid : null,
        attemptsLeft: outcome.challenge!.attemptsLeft,
      );
      // Cancelled: nothing was deleted.
      if (!mounted || otp == null) return;
      setState(() => _deleting.add(biller.id));
      result = await repository.deleteRegisteredBiller(
        biller.id,
        body: biller.raw,
        challenge: outcome.challenge,
        otp: otp,
      );
    }
    if (!mounted) return;
    setState(() => _deleting.remove(biller.id));

    if (result is Success<BillerDeleteOutcome> && result.data != null) {
      HapticFeedback.mediumImpact();
      _snack(result.data!.pendingApproval
          ? l10n.billerDeletePendingApproval(biller.nickname)
          : l10n.billerDeleted(biller.nickname));
      setState(() => _open = null);
      ref.invalidate(registeredBillersProvider);
    } else {
      _snack(result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.billerDeleteFailed(biller.nickname),
      ));
    }
  }

  Future<bool> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.billerDelete),
        content: Text(l10n.billerDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.billerNo)),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.billerYes)),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing;
    if (editing != null) {
      return EditBillerScreen(
        biller: editing,
        // Cancel: back to where Edit was opened (list or details).
        onExit: () => setState(() => _editing = null),
        onUpdated: (_) {
          setState(() {
            _editing = null;
            _open = null;
          });
          ref.invalidate(registeredBillersProvider);
          ref.invalidate(billerDetailsProvider(editing.id));
        },
      );
    }
    final payingMany = _payingMany;
    if (payingMany != null) {
      return PayBillsScreen(
        billers: payingMany,
        onExit: _closePay,
        onPayAnother: () => _closePay(paid: true),
        onAddBiller: () {
          _closePay(paid: true);
          setState(() => _adding = true);
        },
      );
    }
    final paying = _paying;
    if (paying != null) {
      return PayBillScreen(
        key: ValueKey(paying.id),
        registrationId: paying.id,
        single: _payingSingle,
        onExit: _closePay,
        onPayAnother: () => _closePay(paid: true),
        onAddBiller: () {
          _closePay(paid: true);
          setState(() => _adding = true);
        },
      );
    }
    if (_history) {
      return BillPaymentHistoryScreen(embedded: true, onBack: () => setState(() => _history = false));
    }
    if (_adding) {
      return AddBillerScreen(
        onExit: () => setState(() => _adding = false),
        onAdded: (_) {
          setState(() => _adding = false);
          ref.invalidate(registeredBillersProvider);
        },
      );
    }
    final open = _open;
    if (open != null) {
      return _BillerDetailsView(
        biller: open,
        deleting: _deleting.contains(open.id),
        onBack: () => setState(() => _open = null),
        onEdit: () => _edit(open),
        onDelete: () => _delete(open),
        onPay: open.canPayNow ? () => _pay(open) : null,
      );
    }

    final l10n = AppLocalizations.of(context);
    final billers = ref.watch(registeredBillersProvider);
    return PayMenuPage(
      title: l10n.billersTitle,
      subtitle: l10n.billersSubtitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) {
        final all = billers.valueOrNull ?? const <RegisteredBiller>[];
        final payable = {for (final b in all) if (b.selectableForPay) b.id};
        // A refresh can drop a biller or its bill: keep only valid ticks.
        _selected.retainAll(payable);
        final allTicked = payable.isNotEmpty && _selected.length == payable.length;
        // No presented bill → nothing to tick: the bar shows search only.
        final canPay = payable.isNotEmpty;

        final search = TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: payInputDecoration(
            context,
            hint: l10n.billersSearchHint,
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
              child: Icon(Icons.search_rounded, size: 20, color: HomeColors.textSecondary(context)),
            ),
          ),
        );
        // [fit]: the label may wrap (phone, beside Pay); on web it sits in
        // an unbounded Row, where it must keep its own width.
        Widget selectAll({bool fit = false}) {
          final label = Text(
            l10n.billersSelectAllToPay,
            style: TextStyle(fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
          );
          return InkWell(
            onTap: () => setState(() => allTicked ? _selected.clear() : _selected.addAll(payable)),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: allTicked,
                  onChanged: (v) => setState(() => (v ?? false) ? _selected.addAll(payable) : _selected.clear()),
                ),
                if (fit) Flexible(child: label) else label,
              ],
            ),
          );
        }
        // OBDX keeps Pay disabled until something is ticked.
        final payAll = Tooltip(
          message: _selected.isEmpty ? l10n.billersSelectAtLeastOne : '',
          child: FilledButton(
            onPressed: _selected.isEmpty ? null : () => _paySelected(all),
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(l10n.billerPay),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // OBDX's page actions.
            if (wide)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PaySecondaryButton(
                    label: l10n.billHistoryTitle,
                    icon: Icons.history_rounded,
                    onPressed: () => setState(() => _history = true),
                  ),
                  const SizedBox(width: 12),
                  PaySecondaryButton(
                    label: l10n.billersAdd,
                    icon: Icons.add_rounded,
                    onPressed: () => setState(() => _adding = true),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.history_rounded,
                      label: l10n.billHistoryTitle,
                      onTap: () => setState(() => _history = true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.add_rounded,
                      label: l10n.billersAdd,
                      onTap: () => setState(() => _adding = true),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            // The design's top bar: search, Select all to Pay, Pay.
            PayCard(
              padding: 14,
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 5, child: search),
                        const Spacer(flex: 2),
                        if (canPay) ...[selectAll(), const SizedBox(width: 16), payAll],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        search,
                        if (canPay) ...[
                          const SizedBox(height: 10),
                          Row(children: [Expanded(child: Align(alignment: Alignment.centerLeft, child: selectAll(fit: true))), payAll]),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            billers.when(
              loading: () => const PayCard(
                child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              ),
              error: (error, _) => PayErrorRetry(
                message: error is BillPaymentsLoadError && error.message != null
                    ? error.message!
                    : l10n.billersLoadFailed,
                onRetry: () => ref.invalidate(registeredBillersProvider),
              ),
              data: (list) => _table(context, l10n, list, wide),
            ),
            const SizedBox(height: 14),
            BillsHelpPanel.pay(l10n),
          ],
        );
      },
    );
  }

  Widget _table(BuildContext context, AppLocalizations l10n, List<RegisteredBiller> list, bool wide) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? list
        : list
            .where((b) => [b.nickname, b.category?.name ?? '']
                .any((v) => v.toLowerCase().contains(q)))
            .toList();
    // One list in OBDX's group order: bills presented, recharge, then
    // direct payment (manage-bill-payments/hooks.js:300-335).
    final rows = groupBillers(shown).values.expand((g) => g).toList();

    if (rows.isEmpty) {
      if (q.isNotEmpty) {
        return PayCard(child: PayMuted(l10n.billersNoMatch(_query.trim())));
      }
      return BillsHelpPanel.add(
        l10n,
        action: PaySecondaryButton(
          label: l10n.billersAdd,
          icon: Icons.add_rounded,
          onPressed: () => setState(() => _adding = true),
        ),
      );
    }

    return PayCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            PayTableHeader(
              leading: 48,
              cells: [
                (l10n.billerName, 6),
                (l10n.billersColBillType, 2),
                (l10n.billersColStatus, 2),
                (l10n.billerBillAmount, 2),
                (l10n.billersColActions, 3),
              ],
            ),
          for (final (i, biller) in rows.indexed)
            _BillerRow(
              biller: biller,
              today: _today,
              wide: wide,
              last: i == rows.length - 1,
              selectable: biller.selectableForPay,
              selected: _selected.contains(biller.id),
              deleting: _deleting.contains(biller.id),
              onSelect: (v) => setState(() => v ? _selected.add(biller.id) : _selected.remove(biller.id)),
              onOpen: () => setState(() => _open = biller),
              onPay: biller.canPayNow ? () => _pay(biller) : null,
              onEdit: () => _edit(biller),
              onDelete: () => _delete(biller),
            ),
        ],
      ),
    );
  }
}

/// Biller Details' own type label — OBDX biller-details/hooks.js:181-188
/// uses a different set from the Billers list: PRESENTMENT and
/// PRESENTMENT_PAYMENT → "e-Bills", PAYMENT → "Payment", RECHARGE →
/// "Recharge"; anything else is left blank.
String billerDetailsTypeLabel(AppLocalizations l10n, BillerType type) => switch (type) {
      BillerType.presentment || BillerType.presentmentPayment => l10n.billerDetailsTypeEbills,
      BillerType.payment => l10n.billerDetailsTypePayment,
      BillerType.recharge => l10n.billerTypeRecharge,
      BillerType.unknown => '',
    };

/// OBDX's type label on the Billers list (manage-bill-payments/hooks.js:240-266).
String billerTypeLabel(AppLocalizations l10n, BillerType type) => switch (type) {
      BillerType.presentment => l10n.billerTypeEbill,
      BillerType.presentmentPayment => l10n.billerTypeEbillManual,
      BillerType.recharge => l10n.billerTypeRecharge,
      _ => l10n.billerTypeManual,
    };

String? _statusLabel(AppLocalizations l10n, BillerPaymentStatus? status) => switch (status) {
      BillerPaymentStatus.overdue => l10n.billerStatusPastDue,
      BillerPaymentStatus.autopay => l10n.billerStatusAutoPay,
      BillerPaymentStatus.scheduledPay => l10n.billerStatusScheduledPay,
      null => null,
    };

String? _registrationLabel(AppLocalizations l10n, RegisteredBiller biller) {
  switch ((biller.registrationStatus ?? '').toUpperCase()) {
    case 'PENDING':
      return l10n.billerApprovalPending;
    case 'REJECTED':
      return l10n.billerRejected;
  }
  return null;
}

enum _Action { details, edit, delete }

/// Phone actions under the search: two equal tiles in one row.
class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: brand.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: brand.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The type / registration / payment-status chips OBDX shows for a biller.
/// [withType]: the type chip too (the web table has a Bill Type column).
List<Widget> _billerChips(
  AppLocalizations l10n,
  RegisteredBiller biller,
  DateTime today, {
  bool detailsLabels = false,
  bool withType = true,
}) {
  final status = biller.paymentStatus(today);
  final statusText = _statusLabel(l10n, status);
  final registration = _registrationLabel(l10n, biller);
  final presented = biller.type == BillerType.presentment ||
      (biller.type == BillerType.presentmentPayment && biller.ebill != null);
  final typeText =
      detailsLabels ? billerDetailsTypeLabel(l10n, biller.type) : billerTypeLabel(l10n, biller.type);
  return [
    if (withType && typeText.isNotEmpty) _Chip(typeText),
    if (registration != null) _Chip(registration, tone: _Tone.danger),
    if (statusText != null) _Chip(statusText, tone: status == BillerPaymentStatus.overdue ? _Tone.warning : _Tone.brand),
    if (presented)
      biller.hasBillDue ? _Chip(l10n.billerBillsDue) : _Chip(l10n.billerNoBillsDue, tone: _Tone.success),
  ];
}

String _ebillAmount(RegisteredBiller biller) {
  final total = biller.ebill?.totalAmount;
  if (total == null) return '';
  return MoneyFormat.format(total.amount, currencyCode: total.currency ?? biller.biller?.currency ?? '');
}

/// The first relationship, as OBDX's list shows it (`label + ' ' + value`,
/// manage-bill-payments-list.html:33). List rows carry no label, so OBDX
/// prints "undefined"; the app shows the label only when it is known.
String _relationshipLine(RegisteredBiller biller) {
  if (biller.relationships.isEmpty) return '';
  final rel = biller.relationships.first;
  final label = biller.biller?.specLabels[rel.labelId];
  return [label, rel.value].whereType<String>().where((v) => v.isNotEmpty).join(' ');
}

/// The design's rounded tile with the biller's initial.
class _InitialTile extends StatelessWidget {
  const _InitialTile(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.withValues(alpha: 0.25)),
      ),
      child: Text(initial, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: brand)),
    );
  }
}

/// One biller: a table row on web, a card on a phone.
class _BillerRow extends StatelessWidget {
  const _BillerRow({
    required this.biller,
    required this.today,
    required this.wide,
    required this.last,
    required this.selectable,
    required this.selected,
    required this.deleting,
    required this.onSelect,
    required this.onOpen,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  final RegisteredBiller biller;
  final DateTime today;
  final bool wide;
  final bool last;

  /// Presented bills only (OBDX's tick box rule).
  final bool selectable;
  final bool selected;
  final bool deleting;
  final ValueChanged<bool> onSelect;
  final VoidCallback onOpen;
  /// Null: OBDX shows no Pay for this biller.
  final VoidCallback? onPay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = HomeColors.textPrimary(context);
    final secondary = HomeColors.textSecondary(context);
    final amount = _ebillAmount(biller);
    final due = biller.ebill?.dueDate;
    final relationship = _relationshipLine(biller);
    final presented = biller.type == BillerType.presentment ||
        (biller.type == BillerType.presentmentPayment && biller.ebill != null);
    // OBDX's Status column: bills due or not, for presenting billers.
    final statusText = presented ? (biller.hasBillDue ? l10n.billerBillsDue : l10n.billerNoBillsDue) : '';

    final tick = SizedBox(
      width: 48,
      child: selectable
          ? Checkbox(value: selected, onChanged: deleting ? null : (v) => onSelect(v ?? false))
          : null,
    );

    final who = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InitialTile(biller.nickname),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                biller.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
              ),
              if (relationship.isNotEmpty)
                Text(relationship, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: secondary)),
              if (due != null)
                Text(
                  l10n.billerDueBy(MaterialLocalizations.of(context).formatShortDate(due)),
                  style: TextStyle(fontSize: 13.5, color: secondary),
                ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: _billerChips(l10n, biller, today, withType: !wide)),
            ],
          ),
        ),
      ],
    );

    final pay = onPay == null
        ? null
        : OutlinedButton(
      onPressed: deleting ? null : onPay,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(84, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(l10n.billerPay),
    );
    final menu = deleting
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        : PopupMenuButton<_Action>(
            tooltip: l10n.billersColActions,
            icon: Icon(Icons.more_horiz_rounded, color: HomeColors.brand(context)),
            onSelected: (action) => switch (action) {
              _Action.details => onOpen(),
              _Action.edit => onEdit(),
              _Action.delete => onDelete(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: _Action.edit, child: Text(l10n.billerEdit)),
              PopupMenuItem(value: _Action.delete, child: Text(l10n.billerDelete)),
              PopupMenuItem(value: _Action.details, child: Text(l10n.billerDetailsTitle)),
            ],
          );

    final Widget content = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              tick,
              Expanded(flex: 6, child: who),
              Expanded(flex: 2, child: Text(billerTypeLabel(l10n, biller.type), style: TextStyle(fontWeight: FontWeight.w600, color: primary))),
              Expanded(flex: 2, child: Text(statusText, style: TextStyle(fontWeight: FontWeight.w600, color: primary))),
              Expanded(
                flex: 2,
                child: Text(amount, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primary)),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [if (pay != null) ...[pay, const SizedBox(width: 6)], menu],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectable) tick,
                  Expanded(child: who),
                  if (amount.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(amount, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primary)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: pay ?? const SizedBox.shrink()), const SizedBox(width: 4), menu]),
            ],
          );

    return InkWell(
      onTap: deleting ? null : onOpen,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 14, vertical: 16),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
        ),
        child: content,
      ),
    );
  }
}

enum _Tone { brand, warning, success, danger }

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.tone = _Tone.brand});

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _Tone.brand => HomeColors.brand(context),
      _Tone.warning => HomeColors.warning(context),
      _Tone.success => HomeColors.success(context),
      _Tone.danger => HomeColors.error(context),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// Biller Details — OBDX `biller-details` (labels: nls/biller-details.js).
///
/// A summary card first (shown at once from the list item while the
/// details load): who, the chips, the bill amount and due date, and the
/// actions — then the label/value "Details", and "Payment Type" only when
/// auto pay or a schedule is set.
class _BillerDetailsView extends ConsumerWidget {
  const _BillerDetailsView({
    required this.biller,
    required this.deleting,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    required this.onPay,
  });

  final RegisteredBiller biller;
  final bool deleting;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  /// Null: OBDX shows no Pay for this biller.
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final details = ref.watch(billerDetailsProvider(biller.id));
    String date(DateTime? d) => d == null ? '' : MaterialLocalizations.of(context).formatMediumDate(d);
    final today = DateTime.now();

    return PayMenuPage(
      title: l10n.billerDetailsTitle,
      subtitle: biller.nickname,
      onBack: onBack,
      builder: (context, wide) {
        // The registration from the details call once loaded, else the list item.
        final reg = details.valueOrNull?.registration ?? biller;
        final master = details.valueOrNull?.biller ?? biller.biller;

        final summary = _SummaryCard(
          biller: reg,
          billerName: master?.name ?? reg.displayBillerName,
          today: today,
          deleting: deleting,
          onPay: onPay,
          onEdit: onEdit,
          onDelete: onDelete,
        );

        final Widget body = details.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => PayErrorRetry(
            message: error is BillPaymentsLoadError && error.message != null
                ? error.message!
                : l10n.billerDetailsLoadFailed,
            onRetry: () => ref.invalidate(billerDetailsProvider(biller.id)),
          ),
          data: (data) {
            final reg = data.registration;
            final location = reg.location;
            final schedule = reg.autopayInstructions;
            final rows = _nonEmpty([
              (l10n.billerName, master?.name ?? reg.displayBillerName),
              (l10n.billerCategory, reg.category?.name ?? master?.categoryName ?? ''),
              (l10n.billerLocation, [location?.areaName, location?.city].whereType<String>().join(', ')),
              (l10n.billerType, billerDetailsTypeLabel(l10n, reg.type)),
              (l10n.billerNickname, reg.nickname),
              (l10n.billerCustomerName, reg.customerName ?? ''),
              // Relationship fields, named by the biller's specifications
              // (biller-details/hooks.js:198-206).
              for (final rel in reg.relationships)
                (master?.specLabels[rel.labelId] ?? rel.labelId ?? '', rel.value ?? ''),
            ]);
            final payment = !(reg.autopay || reg.schedulePayment)
                ? const <(String, String)>[]
                : _nonEmpty([
                    (l10n.billerPaymentType, reg.autopay ? l10n.billerStatusAutoPay : l10n.billerStatusScheduledPay),
                    (l10n.billerPayFrom, schedule?.debitAccountDisplay ?? ''),
                    (l10n.billerFrequency, schedule?.frequency ?? ''),
                    (l10n.billerStartDate, date(schedule?.startDate)),
                    (l10n.billerEndDate, date(schedule?.endDate)),
                  ]);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PaySection(
                  title: l10n.billerDetailsSection,
                  icon: Icons.info_outline_rounded,
                  child: _Rows(rows),
                ),
                if (payment.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  PaySection(
                    title: l10n.billerPaymentType,
                    icon: Icons.event_repeat_rounded,
                    child: _Rows(payment),
                  ),
                ],
              ],
            );
          },
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [summary, const SizedBox(height: 14), body],
        );
      },
    );
  }
}

List<(String, String)> _nonEmpty(List<(String, String)> rows) =>
    rows.where((r) => r.$1.isNotEmpty && r.$2.isNotEmpty).toList();

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.biller,
    required this.billerName,
    required this.today,
    required this.deleting,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  final RegisteredBiller biller;
  final String billerName;
  final DateTime today;
  final bool deleting;
  /// Null: OBDX shows no Pay for this biller.
  final VoidCallback? onPay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = HomeColors.textSecondary(context);
    final primary = HomeColors.textPrimary(context);
    final amount = _ebillAmount(biller);
    final due = biller.ebill?.dueDate;
    final overdue = biller.paymentStatus(today) == BillerPaymentStatus.overdue;

    Widget figure(String label, String value, {Color? color}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: secondary)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color ?? primary)),
          ],
        );

    return PayCard(
      padding: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PayAvatar(name: biller.nickname, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(biller.nickname, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
                    if (billerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(billerName, style: TextStyle(fontSize: 13.5, color: secondary)),
                    ],
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: _billerChips(l10n, biller, today, detailsLabels: true)),
                  ],
                ),
              ),
            ],
          ),
          if (amount.isNotEmpty || due != null) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: HomeColors.divider(context)),
            const SizedBox(height: 14),
            Row(
              children: [
                if (amount.isNotEmpty) Expanded(child: figure(l10n.billerBillAmount, amount)),
                if (due != null)
                  Expanded(
                    child: figure(
                      l10n.billerBillDueDate,
                      MaterialLocalizations.of(context).formatMediumDate(due),
                      color: overdue ? HomeColors.error(context) : null,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (deleting)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else
            Row(
              children: [
                if (onPay != null) ...[
                  Expanded(child: PayPrimaryButton(label: l10n.billerPay, onPressed: onPay)),
                  const SizedBox(width: 10),
                ] else
                  const Spacer(),
                _IconAction(icon: Icons.edit_outlined, tooltip: l10n.billerEdit, onTap: onEdit),
                const SizedBox(width: 8),
                _IconAction(
                  icon: Icons.delete_outline_rounded,
                  tooltip: l10n.billerDelete,
                  onTap: onDelete,
                  color: HomeColors.error(context),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Square outlined icon button beside Pay (Edit Biller / Delete Biller).
class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.tooltip, required this.onTap, this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? HomeColors.brand(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: c),
          ),
        ),
      ),
    );
  }
}

/// Label on the left, value on the right, a divider between rows.
class _Rows extends StatelessWidget {
  const _Rows(this.rows);

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (label, value)) in rows.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: i == rows.length - 1 ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(label, style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
