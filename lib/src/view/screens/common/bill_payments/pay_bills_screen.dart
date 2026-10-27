import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_pay_models.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/pay_bill_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/widgets/bill_pay_fields.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/obdx_write_runner.dart';

/// Pay Bills — OBDX `flows/initiate-multiple-bill-payments`, for two or
/// more presented bills ticked on Billers: a card per bill (each Saved on
/// its own, the first opened) → Review → Multiple Bill Payment Status.
/// Confirm sends one `POST /digx-payments/batch` with a part per bill.
/// No late payment / Auto Pay / Scheduled Pay checks, as OBDX.
///
/// Where OBDX has a bug the app follows its intent (bill-payments.md
/// §8.5): every bill must have its account and valid fields before
/// Review (OBDX marks bills 2..N saved untouched); results are matched by
/// `sequenceId`; Review shows each bill's own details; Back keeps what was
/// entered. Corporate-only parts of the status screen (Assign, Group
/// Transactions, e-Receipts) are not built.
/// Evidence: docs/obdx/features/bill-payments.md §8.
class PayBillsScreen extends ConsumerStatefulWidget {
  const PayBillsScreen({
    super.key,
    required this.billers,
    required this.onExit,
    required this.onPayAnother,
    this.onAddBiller,
  });

  /// The ticked billers (list rows), in Billers' order.
  final List<RegisteredBiller> billers;
  final VoidCallback onExit;

  /// "Pay Another Bill": back to Billers (the list reloads).
  final VoidCallback onPayAnother;
  final VoidCallback? onAddBiller;

  @override
  ConsumerState<PayBillsScreen> createState() => _PayBillsScreenState();
}

/// One bill of the flow: its row, its answers and its card state.
class _Bill {
  _Bill(this.registration, {required this.expanded, required this.saved, required int year})
      // OBDX starts Expiry Month / Year on "01" and this year
      // (stage1/hooks.js:717-718).
      : draft = BillPayDraft(multiple: true, expiryMonth: 1, expiryYear: year);

  final RegisteredBiller registration;
  final BillPayDraft draft;
  bool expanded;

  /// OBDX marks bills 2..N saved from the start (stage1/hooks.js:701-712);
  /// the app still checks them on Submit.
  bool saved;
  bool initialised = false;
}

class _PayBillsScreenState extends ConsumerState<PayBillsScreen> {
  int _step = 0;
  bool _busy = false;
  late final List<_Bill> _bills = [
    for (final (i, b) in widget.billers.indexed)
      _Bill(b, expanded: i == 0, saved: i != 0, year: DateTime.now().year),
  ];

  /// What was sent and what came back (the status screen).
  List<(_Bill, PayBillContext)>? _sent;
  BillBatchOutcome? _outcome;

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    for (final b in _bills) {
      b.draft.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Each bill's biller data, watched on every step (Review and the status
  /// page build no cards, and the autoDispose providers would go).
  final _masters = <_Bill, AsyncValue<PayBillContext>>{};

  PayBillContext? _data(_Bill bill) => _masters[bill]?.valueOrNull;

  /// Uploads the bill's attachment if it has a new one; false when that
  /// failed or the OTP was cancelled.
  Future<bool> _upload(_Bill bill) async {
    final file = bill.draft.pendingUpload;
    if (file == null) return true;
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(billPaymentsRepositoryProvider);
    setState(() => _busy = true);
    final result = await runWithOtp<BillAttachmentOutcome>(
      context,
      (challenge, otp) => repository.uploadAttachment(file, challenge: challenge, otp: otp),
    );
    if (!mounted) return false;
    setState(() => _busy = false);
    if (!obdxWriteDone(result)) {
      if (result is! Success<BillAttachmentOutcome>) {
        _snack(result.resolveUserMessage(l10n: l10n, fallback: l10n.payBillUploadFailed));
      }
      return false;
    }
    bill.draft.attachmentId = (result as Success<BillAttachmentOutcome>).data!.contentId;
    return true;
  }

  /// A bill's field checks: OBDX's Save needs an account ("Select an
  /// account to proceed"); the other rules are OBDX's Submit checks.
  bool _check(_Bill bill) {
    final l10n = AppLocalizations.of(context);
    final draft = bill.draft;
    if (draft.account == null) {
      _snack(l10n.payBillsSelectAccount);
      setState(() => draft.showErrors = true);
      return false;
    }
    if (!draft.complete) {
      setState(() => draft.showErrors = true);
      return false;
    }
    if (!draft.expiryValid(_today)) {
      _snack(l10n.payBillInvalidExpiry);
      return false;
    }
    return true;
  }

  /// OBDX `onClickSavePayment` (stage1/hooks.js:950-980): upload the file,
  /// then collapse the card.
  Future<void> _save(_Bill bill) async {
    if (!_check(bill)) return;
    FocusScope.of(context).unfocus();
    if (!await _upload(bill)) return;
    setState(() {
      bill.expanded = false;
      bill.saved = true;
    });
  }

  /// "Default this account for all the bill payments records": the first
  /// bill's Payment Type and account to every bill whose biller takes that
  /// type (OBDX means this check, but its filter always passes;
  /// stage1/hooks.js:924-939).
  void _copyAccount() {
    final first = _bills.first.draft;
    if (first.account == null || first.type == null) return;
    setState(() {
      for (final bill in _bills.skip(1)) {
        final data = _data(bill);
        if (data == null || !BillPayType.supportedBy(data.biller).contains(first.type)) continue;
        bill.draft
          ..type = first.type
          ..typePicked = first.typePicked
          ..account = first.account;
      }
    });
  }

  /// "Default this date for all the bill payments records" (hooks.js:941-948).
  void _copyDate() {
    final first = _bills.first.draft;
    setState(() {
      for (final bill in _bills.skip(1)) {
        bill.draft
          ..payLater = first.payLater
          ..scheduled = first.scheduled;
      }
    });
  }

  /// "Delete Bill Payment": nothing when only one bill is left (hooks.js:902-910).
  void _delete(_Bill bill) {
    if (_bills.length <= 1) return;
    setState(() => _bills.remove(bill));
    bill.draft.dispose();
  }

  /// OBDX Submit (stage1.js:569-685): every card saved; then (the app's
  /// fix) every bill complete — the first that is not opens with its errors.
  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_bills.any((b) => b.expanded && !b.saved)) return _snack(l10n.payBillsSaveAll);
    for (final bill in _bills) {
      if (_data(bill) == null) return;
      final draft = bill.draft;
      if (draft.complete && draft.expiryValid(_today)) continue;
      setState(() {
        bill.expanded = true;
        bill.saved = false;
        draft.showErrors = true;
      });
      if (draft.account == null) _snack(l10n.payBillsSelectAccount);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(billPaymentsRepositoryProvider);
    final sent = [
      for (final b in _bills)
        if (_data(b) case final data?) (b, data),
    ];
    final requests = [for (final (b, data) in sent) b.draft.request(data, _today)];
    setState(() => _busy = true);
    final result = await runWithOtp<BillBatchOutcome>(
      context,
      (challenge, otp) => repository.payBills(requests, challenge: challenge, otp: otp),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (obdxWriteDone(result)) {
      HapticFeedback.mediumImpact();
      ref.invalidate(registeredBillersProvider);
      ref.invalidate(billPaymentHistoryProvider);
      setState(() {
        _sent = sent;
        _outcome = (result as Success<BillBatchOutcome>).data;
        _step = 2;
      });
    } else if (result is! Success<BillBatchOutcome>) {
      _snack(result.resolveUserMessage(l10n: l10n, fallback: l10n.payBillsSendFailed));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _masters
      ..clear()
      ..addAll({for (final b in _bills) b: ref.watch(billPayMasterProvider(b.registration))});
    final Widget child = switch (_step) {
      0 => _form(l10n),
      1 => _review(l10n),
      _ => _status(l10n),
    };
    return PayFlowScaffold(
      title: l10n.payBillsTitle,
      subtitle: switch (_step) {
        1 => l10n.payBillsReviewMessage(_bills.length),
        2 => l10n.payBillsStatusTitle,
        _ => null,
      },
      step: _step,
      // OBDX hides Back on the first stage; Review's Back returns to it.
      onBackStep: _busy ? null : () => setState(() => _step = 0),
      onExit: _busy ? null : widget.onExit,
      action: switch (_step) {
        0 => Row(
            children: [
              Expanded(child: PayPrimaryButton(label: l10n.addBillerSubmit, onPressed: _busy ? null : _submit)),
              const SizedBox(width: 12),
              Expanded(child: PaySecondaryButton(label: l10n.cancel, onPressed: _busy ? null : widget.onExit)),
            ],
          ),
        1 => PayPrimaryButton(label: l10n.addBillerConfirm, loading: _busy, onPressed: _busy ? null : _confirm),
        _ => PayPrimaryButton(label: l10n.payBillPayAnother, onPressed: widget.onPayAnother),
      },
      child: child,
    );
  }

  // ── Stage 1: a card per bill ───────────────────────────────────────────

  Widget _form(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, bill) in _bills.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          _card(l10n, i, bill),
        ],
      ],
    );
  }

  Widget _card(AppLocalizations l10n, int index, _Bill bill) {
    final async = _masters[bill]!;
    final data = async.valueOrNull;
    if (data != null && !bill.initialised) {
      bill.initialised = true;
      bill.draft.startFrom(data);
    }
    final primary = HomeColors.textPrimary(context);
    final reg = bill.registration;
    final many = _bills.length > 1;

    final header = Row(
      children: [
        Expanded(
          child: Text(reg.nickname, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primary)),
        ),
        if (!bill.expanded)
          IconButton(
            tooltip: l10n.payBillsEdit,
            onPressed: _busy || data == null
                ? null
                : () => setState(() {
                      bill.expanded = true;
                      bill.saved = false;
                    }),
            icon: Icon(Icons.edit_outlined, color: HomeColors.brand(context)),
          ),
        if (many)
          IconButton(
            tooltip: l10n.payBillsDelete,
            onPressed: _busy ? null : () => _delete(bill),
            icon: Icon(Icons.delete_outline_rounded, color: HomeColors.error(context)),
          ),
      ],
    );

    final Widget body;
    if (async.hasError) {
      body = PayErrorRetry(
        message: async.error is BillPaymentsLoadError && (async.error as BillPaymentsLoadError).message != null
            ? (async.error as BillPaymentsLoadError).message!
            : l10n.payBillLoadFailed,
        onRetry: () => ref.invalidate(billPayMasterProvider(reg)),
      );
    } else if (data == null) {
      body = const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    } else if (!bill.expanded) {
      // Collapsed: Biller Name, Location, Customer Name (stage1.html:21-31).
      body = BillInfoGrid(
        rows: [
          (l10n.billerName, data.biller.name ?? reg.displayBillerName),
          (l10n.billerLocation, data.location ?? ''),
          (l10n.billerCustomerName, reg.customerName ?? ''),
        ].where((r) => r.$2.isNotEmpty).toList(),
      );
    } else {
      final first = index == 0 && many;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BillInfoGrid(rows: billSummaryRows(l10n, data)),
          const SizedBox(height: 14),
          BillPayFields(
            draft: bill.draft,
            data: data,
            onChanged: _refresh,
            busy: _busy,
            accountAction: first
                ? IconButton(
                    tooltip: l10n.payBillsCopyAccount,
                    onPressed: _busy ? null : _copyAccount,
                    icon: Icon(Icons.copy_all_rounded, color: HomeColors.brand(context)),
                  )
                : null,
            dateAction: first
                ? IconButton(
                    tooltip: l10n.payBillsCopyDate,
                    onPressed: _busy ? null : _copyDate,
                    icon: Icon(Icons.copy_all_rounded, color: HomeColors.brand(context)),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PaySecondaryButton(
              label: l10n.payBillsSave,
              icon: Icons.check_rounded,
              onPressed: _busy ? null : () => _save(bill),
            ),
          ),
        ],
      );
    }
    return PayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, const SizedBox(height: 6), body],
      ),
    );
  }

  // ── Review: a section per bill ─────────────────────────────────────────

  Widget _review(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, bill) in _bills.indexed)
          if (_data(bill) case final data?) ...[
            if (i > 0) const SizedBox(height: 14),
            PaySummaryCard(
              icon: Icons.receipt_long_outlined,
              title: bill.registration.nickname,
              subtitle: data.biller.name ?? bill.registration.displayBillerName,
              rows: billReviewRows(l10n, data, bill.draft, _today),
            ),
            if (bill.registration.ebill != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => showDetailedBill(context, data),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(l10n.payBillDetailedBill),
                ),
              ),
          ],
      ],
    );
  }

  // ── Multiple Bill Payment Status ───────────────────────────────────────

  Widget _status(AppLocalizations l10n) {
    final outcome = _outcome!;
    final rows = outcome.rows ?? const <BillBatchRow>[];
    final sent = _sent!;
    final referenceLabel = outcome.anyPending ? l10n.payBillsReference : l10n.payBillsHostReference;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final entries = [
          for (final (i, (bill, data)) in sent.indexed)
            _StatusEntry(
              billerName: data.biller.name ?? bill.registration.displayBillerName,
              category: data.biller.categoryName ?? '',
              fromAccount: bill.draft.account!.label,
              amount: billAmountLabel(data, bill.draft, _today),
              reference: i < rows.length ? _reference(rows[i], outcome.anyPending) : '',
              row: i < rows.length ? rows[i] : const BillBatchRow(status: 0),
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              PayCard(
                padding: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PayTableHeader(cells: [
                      (l10n.billerName, 3),
                      (l10n.addBillerCategory, 2),
                      (l10n.payBillsFromAccount, 3),
                      (l10n.payBillAmount, 2),
                      (referenceLabel, 3),
                      (l10n.payBillsStatus, 3),
                    ]),
                    for (final (i, e) in entries.indexed) _StatusTableRow(entry: e, last: i == entries.length - 1),
                  ],
                ),
              )
            else
              for (final (i, e) in entries.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                PayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BillInfoGrid(
                        columns: 1,
                        rows: [
                          (l10n.billerName, e.billerName),
                          (l10n.addBillerCategory, e.category),
                          (l10n.payBillsFromAccount, e.fromAccount),
                          (l10n.payBillAmount, e.amount),
                          (referenceLabel, e.reference),
                        ].where((r) => r.$2.isNotEmpty).toList(),
                      ),
                      const SizedBox(height: 6),
                      _StatusCell(row: e.row),
                    ],
                  ),
                ),
              ],
            BillNextActions(onAddBiller: widget.onAddBiller),
          ],
        );
      },
    );
  }

  /// The reference cell (status.html:34-40): with any bill for approval,
  /// `status.referenceNumber`; otherwise `status.externalReferenceNumber`
  /// and, for non-corporate users, `billPayment.id`.
  String _reference(BillBatchRow row, bool anyPending) => anyPending
      ? row.referenceNumber ?? ''
      : [row.externalReference, row.paymentId].whereType<String>().join('\n');
}

class _StatusEntry {
  const _StatusEntry({
    required this.billerName,
    required this.category,
    required this.fromAccount,
    required this.amount,
    required this.reference,
    required this.row,
  });

  final String billerName;
  final String category;
  final String fromAccount;
  final String amount;
  final String reference;
  final BillBatchRow row;
}

class _StatusTableRow extends StatelessWidget {
  const _StatusTableRow({required this.entry, required this.last});

  final _StatusEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: HomeColors.textPrimary(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(entry.billerName, style: style.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text(entry.category, style: style)),
          Expanded(flex: 3, child: Text(entry.fromAccount, style: style)),
          Expanded(flex: 2, child: Text(entry.amount, style: style)),
          Expanded(flex: 3, child: Text(entry.reference, style: style)),
          Expanded(flex: 3, child: _StatusCell(row: entry.row)),
        ],
      ),
    );
  }
}

/// Status (status.html:43-56): Completed; Initiated + "Pending for
/// approval"; Pending for approval; Failed + the reason.
class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.row});

  final BillBatchRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = HomeColors.textSecondary(context);
    final (String title, String? note, Color color) = switch (row) {
      BillBatchRow(completed: true) => (l10n.payBillsCompleted, null, HomeColors.brand(context)),
      BillBatchRow(pendingApproval: true, approvalInitiated: true) =>
        (l10n.payBillsInitiated, l10n.payBillsPendingApproval, HomeColors.brand(context)),
      BillBatchRow(pendingApproval: true) => (l10n.payBillsPendingApproval, null, HomeColors.brand(context)),
      BillBatchRow(status: 0) => (l10n.payBillsFailed, l10n.payBillsNoAnswer, HomeColors.error(context)),
      _ => (l10n.payBillsFailed, row.failureReason, HomeColors.error(context)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        if (note != null) Text(note, style: TextStyle(fontSize: 12.5, color: secondary)),
      ],
    );
  }
}
