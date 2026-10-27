import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_pay_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/widgets/bill_pay_fields.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/obdx_write_runner.dart';

/// Pay Bill — OBDX `flows/pay-bill` for one registered biller:
/// Pay Bill (biller summary + payment fields) → Review → confirmation.
/// Before the form, OBDX's `showPayBill` checks run (late payment block,
/// Auto Pay / Scheduled Pay warnings). Submit uploads the attachment, if
/// any; Confirm sends `POST ebillPayments` with the OTP loop.
/// Evidence: docs/obdx/features/bill-payments.md §7.
class PayBillScreen extends ConsumerStatefulWidget {
  const PayBillScreen({
    super.key,
    required this.registrationId,
    required this.onExit,
    required this.onPayAnother,
    this.single = true,
    this.onAddBiller,
    this.onHome,
  });

  final String registrationId;

  /// A row's Pay (OBDX `isSinglePay`); false from Select all to Pay.
  final bool single;

  /// Cancel, or a check refused before the form.
  final VoidCallback onExit;

  /// "Pay Another Bill": back to Billers (the list reloads).
  final VoidCallback onPayAnother;

  /// "Add Biller" on the confirmation.
  final VoidCallback? onAddBiller;

  /// "Home" on the confirmation; hidden when null.
  final VoidCallback? onHome;

  @override
  ConsumerState<PayBillScreen> createState() => _PayBillScreenState();
}

class _PayBillScreenState extends ConsumerState<PayBillScreen> {
  int _step = 0;
  bool _busy = false;

  /// The `showPayBill` checks are done (or not needed).
  bool _cleared = false;
  bool _checking = false;

  /// Defaults taken from the registration once it has loaded.
  bool _initialised = false;

  final _draft = BillPayDraft();
  BillPayOutcome? _outcome;

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// OBDX `showPayBill`'s modals (manage-bill-payments-list.js:116-118).
  Future<void> _runChecks(PayBillContext data) async {
    if (_checking || _cleared) return;
    _checking = true;
    final l10n = AppLocalizations.of(context);
    final gate = payBillGate(data.registration, data.biller, single: widget.single, today: _today);
    if (gate == PayBillGate.open) {
      setState(() => _cleared = true);
      return;
    }
    final blocked = gate == PayBillGate.latePaymentBlocked;
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.payBillGateTitle),
        content: Text(switch (gate) {
          PayBillGate.latePaymentBlocked => l10n.payBillLateBlocked,
          PayBillGate.autopayWarning => l10n.payBillAutopayWarning,
          _ => l10n.payBillScheduledWarning,
        }),
        actions: blocked
            ? [FilledButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.payBillOk))]
            : [
                TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
                FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.payBillContinue)),
              ],
      ),
    );
    if (!mounted) return;
    if (go == true) {
      setState(() => _cleared = true);
    } else {
      widget.onExit();
    }
  }

  // ── Submit (stage 1 → Review) ──────────────────────────────────────────

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_draft.complete) {
      setState(() => _draft.showErrors = true);
      return;
    }
    // OBDX checks the expiry after the field rules (S1/pay-bill-stage1.js:720-740).
    if (!_draft.expiryValid(_today)) return _snack(l10n.payBillInvalidExpiry);
    FocusScope.of(context).unfocus();
    final file = _draft.pendingUpload;
    if (file != null) {
      final repository = ref.read(billPaymentsRepositoryProvider);
      setState(() => _busy = true);
      final result = await runWithOtp<BillAttachmentOutcome>(
        context,
        (challenge, otp) => repository.uploadAttachment(file, challenge: challenge, otp: otp),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (!obdxWriteDone(result)) {
        // Cancelled at the OTP: stay on the form quietly.
        if (result is Success<BillAttachmentOutcome>) return;
        return _snack(result.resolveUserMessage(l10n: l10n, fallback: l10n.payBillUploadFailed));
      }
      _draft.attachmentId = (result as Success<BillAttachmentOutcome>).data!.contentId;
    }
    setState(() => _step = 1);
  }

  Future<void> _confirm(PayBillContext data) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(billPaymentsRepositoryProvider);
    final request = _draft.request(data, _today);
    setState(() => _busy = true);
    final result = await runWithOtp<BillPayOutcome>(
      context,
      (challenge, otp) => repository.payBill(request, challenge: challenge, otp: otp),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (obdxWriteDone(result)) {
      HapticFeedback.mediumImpact();
      ref.invalidate(registeredBillersProvider);
      ref.invalidate(billPaymentHistoryProvider);
      setState(() {
        _outcome = (result as Success<BillPayOutcome>).data;
        _step = 2;
      });
    } else if (result is! Success<BillPayOutcome>) {
      // OBDX shows the server's message and stays on Review.
      _snack(result.resolveUserMessage(l10n: l10n, fallback: l10n.payBillFailed));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(payBillContextProvider(widget.registrationId));
    final data = async.valueOrNull;

    if (data != null) {
      if (!_initialised) {
        _initialised = true;
        _draft.startFrom(data);
      }
      if (!_cleared && !_checking) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _runChecks(data);
        });
      }
    }

    if (data == null || !_cleared) {
      return PayFlowScaffold(
        title: l10n.payBillTitle,
        step: 0,
        onExit: widget.onExit,
        child: async.hasError
            ? PayErrorRetry(
                message: async.error is BillPaymentsLoadError && (async.error as BillPaymentsLoadError).message != null
                    ? (async.error as BillPaymentsLoadError).message!
                    : l10n.payBillLoadFailed,
                onRetry: () => ref.invalidate(payBillContextProvider(widget.registrationId)),
              )
            : data != null
                // Loaded, OBDX's question is on screen: no spinner behind it.
                ? PayCard(child: PayMuted(data.registration.nickname))
                : const PayCard(
                    child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                  ),
      );
    }

    final Widget child = switch (_step) {
      0 => _form(l10n, data),
      1 => _review(l10n, data),
      _ => _done(l10n, data),
    };
    return PayFlowScaffold(
      title: l10n.payBillTitle,
      subtitle: switch (_step) {
        0 => data.registration.nickname,
        1 => l10n.payBillReviewMessage,
        _ => null,
      },
      step: _step,
      onBackStep: _busy ? null : () => setState(() => _step = 0),
      onExit: _busy ? null : widget.onExit,
      action: switch (_step) {
        0 => Row(
            children: [
              Expanded(
                child: PayPrimaryButton(
                  label: l10n.addBillerSubmit,
                  loading: _busy,
                  onPressed: _busy ? null : _submit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: PaySecondaryButton(label: l10n.cancel, onPressed: _busy ? null : widget.onExit)),
            ],
          ),
        1 => PayPrimaryButton(
            label: l10n.addBillerConfirm,
            loading: _busy,
            onPressed: _busy ? null : () => _confirm(data),
          ),
        _ => PayPrimaryButton(label: l10n.payBillPayAnother, onPressed: widget.onPayAnother),
      },
      child: child,
    );
  }

  Widget _form(AppLocalizations l10n, PayBillContext data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                data.registration.nickname,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
              ),
              const SizedBox(height: 8),
              BillInfoGrid(rows: billSummaryRows(l10n, data)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PayCard(child: BillPayFields(draft: _draft, data: data, onChanged: _refresh, busy: _busy)),
      ],
    );
  }

  Widget _review(AppLocalizations l10n, PayBillContext data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySummaryCard(
          icon: Icons.fact_check_outlined,
          title: l10n.addBillerReview,
          subtitle: l10n.payBillReviewMessage,
          rows: billReviewRows(l10n, data, _draft, _today),
        ),
        // With an e-bill, OBDX links the amount to "Detailed Bill".
        if (data.registration.ebill != null) ...[
          const SizedBox(height: 8),
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

  /// OBDX's confirm screen: the message, Reference Number, the payment's
  /// rows and "What would you like to do next?" (RV/pay-bill-review.js:96-162).
  /// Payment Type is shown: OBDX means to, but its row is never filled
  /// (§7.6).
  Widget _done(AppLocalizations l10n, PayBillContext data) {
    final outcome = _outcome!;
    final reg = data.registration;
    final rows = <(String, String)>[
      (l10n.addBillerCategory, data.biller.categoryName ?? ''),
      (l10n.payBillSubcategory, reg.subcategory ?? ''),
      (l10n.billerName, data.biller.name ?? reg.displayBillerName),
      (l10n.billerLocation, data.location ?? ''),
      (l10n.billerCustomerName, reg.customerName ?? ''),
      (l10n.billerPaymentType, billPayTypeLabel(l10n, _draft.type!)),
      (l10n.billerPayFrom, _draft.account!.label),
      (l10n.payBillAmount, billAmountLabel(data, _draft, _today)),
      (l10n.payBillPayWhen, billPayWhenLabel(l10n, _draft, _today)),
      if (_draft.wantAttachment && _draft.file != null) (l10n.payBillAttachments, _draft.file!.name),
    ].where((r) => r.$2.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySummaryCard(
          icon: outcome.pendingApproval ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded,
          title: outcome.pendingApproval ? l10n.payBillPendingApproval : l10n.payBillSuccess,
          subtitle: reg.nickname,
          rows: [
            if (outcome.reference != null) (l10n.payBillReferenceNumber, outcome.reference!),
            ...rows,
          ],
        ),
        BillNextActions(onAddBiller: widget.onAddBiller, onHome: widget.onHome),
      ],
    );
  }
}

/// "What would you like to do next?" with Add Biller / Home (Pay Another
/// Bill is the page's main button). Nothing when neither is given.
class BillNextActions extends StatelessWidget {
  const BillNextActions({super.key, this.onAddBiller, this.onHome});

  final VoidCallback? onAddBiller;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    if (onAddBiller == null && onHome == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BillFieldTitle(l10n.payBillNextAction),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onAddBiller != null)
                PaySecondaryButton(label: l10n.payBillAddBiller, icon: Icons.add_rounded, onPressed: onAddBiller),
              if (onHome != null) PaySecondaryButton(label: l10n.home, icon: Icons.home_outlined, onPressed: onHome),
            ],
          ),
        ],
      ),
    );
  }
}
