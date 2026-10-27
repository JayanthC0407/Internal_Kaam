import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_pay_models.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
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
  bool _showErrors = false;

  /// The `showPayBill` checks are done (or not needed).
  bool _cleared = false;
  bool _checking = false;

  /// Defaults taken from the registration once it has loaded.
  bool _initialised = false;

  BillPayType? _type;
  BillPayAccount? _account;
  BillPlan? _plan;
  final _amount = TextEditingController();
  bool _payLater = false;
  DateTime? _scheduled;
  int? _expiryMonth;
  int? _expiryYear;
  bool _wantAttachment = false;
  BillAttachment? _file;

  /// The uploaded file's id; cleared when the file changes.
  Map<String, dynamic>? _attachmentId;
  BillPayOutcome? _outcome;

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _initialise(PayBillContext data) {
    if (_initialised) return;
    _initialised = true;
    final reg = data.registration;
    _type = BillPayType.initial(BillPayType.supportedBy(data.biller), reg.paymentType);
    _payLater = reg.payLater;
    final prefill = BillPayRules.prefill(reg.ebill);
    if (prefill != null) _amount.text = BillPayRules.amountText(prefill);
  }

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

  String _typeLabel(AppLocalizations l10n, BillPayType type) => switch (type) {
        BillPayType.casa => l10n.payBillTypeAccount,
        BillPayType.creditCard => l10n.payBillTypeCreditCards,
        BillPayType.debitCard => l10n.payBillTypeDebitCards,
      };

  // ── Submit (stage 1 → Review) ──────────────────────────────────────────

  String? _amountError(AppLocalizations l10n, String label) {
    if (!_showErrors || _plan != null) return null;
    return switch (BillPayRules.amount(_amount.text)) {
      null => null,
      BillAmountError.required => l10n.addBillerFieldRequired(label),
      BillAmountError.notPositive => l10n.payBillAmountNotPositive,
      BillAmountError.invalid => l10n.payBillAmountInvalid,
    };
  }

  double? get _amountValue => _plan?.amount ?? double.tryParse(_amount.text.trim().replaceAll(',', ''));

  Future<void> _submit(PayBillContext data) async {
    final l10n = AppLocalizations.of(context);
    final card = _type == BillPayType.creditCard;
    final amountOk = _plan?.amount != null || BillPayRules.amount(_amount.text) == null;
    final ok = _type != null &&
        _account != null &&
        amountOk &&
        (!card || (_expiryMonth != null && _expiryYear != null)) &&
        (!_payLater || _scheduled != null);
    if (!ok) {
      setState(() => _showErrors = true);
      return;
    }
    // OBDX checks the expiry after the field rules (S1/pay-bill-stage1.js:720-740).
    if (card && !BillPayRules.cardExpiryValid(_expiryMonth!, _expiryYear!, _today)) {
      return _snack(l10n.payBillInvalidExpiry);
    }
    FocusScope.of(context).unfocus();
    final file = _wantAttachment ? _file : null;
    if (file != null && _attachmentId == null) {
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
      _attachmentId = (result as Success<BillAttachmentOutcome>).data!.contentId;
    }
    setState(() => _step = 1);
  }

  PayBillRequest _request(PayBillContext data) => PayBillRequest(
        registration: data.registration,
        biller: data.biller,
        type: _type!,
        account: _account!,
        amount: _amountValue!,
        today: _today,
        payLater: _payLater,
        scheduledDate: _scheduled,
        plan: _plan,
        location: data.location,
        cardExpiry: _type == BillPayType.creditCard
            ? BillPayRules.cardExpiryLastDay(_expiryMonth!, _expiryYear!)
            : null,
        attachmentId: _wantAttachment ? _attachmentId : null,
      );

  Future<void> _confirm(PayBillContext data) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(billPaymentsRepositoryProvider);
    final request = _request(data);
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

  // ── Attachment ─────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final l10n = AppLocalizations.of(context);
    FilePickerResult? result;
    try {
      try {
        result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: BillAttachmentRules.extensions,
          withData: true,
        );
      } on PlatformException {
        // Some pickers refuse a type filter; the rules below still check.
        result = await FilePicker.pickFiles(withData: true);
      }
    } catch (_) {
      if (mounted) _snack(l10n.payBillPickFailed);
      return;
    }
    final picked = result?.files.firstOrNull;
    if (picked == null || picked.bytes == null || !mounted) return;
    if (picked.bytes!.length > BillAttachmentRules.maxBytes) return _snack(l10n.payBillFileTooLarge);
    if (!BillAttachmentRules.allowedName(picked.name)) return _snack(l10n.payBillInvalidFile);
    setState(() {
      _file = BillAttachment(name: picked.name, bytes: picked.bytes!);
      _attachmentId = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(payBillContextProvider(widget.registrationId));
    final data = async.valueOrNull;

    if (data != null) {
      _initialise(data);
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
                  onPressed: _busy ? null : () => _submit(data),
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

  // ── Stage 1: Pay Bill ──────────────────────────────────────────────────

  /// The read-only biller summary (S1/pay-bill-stage1.html:13-35).
  List<(String, String)> _summary(AppLocalizations l10n, PayBillContext data) {
    final reg = data.registration;
    final labels = data.biller.specLabels;
    final due = reg.ebill?.dueDate;
    return [
      (l10n.billerName, data.biller.name ?? reg.displayBillerName),
      (l10n.billerNickname, reg.nickname),
      (l10n.addBillerCategory, data.biller.categoryName ?? reg.category?.name ?? ''),
      (l10n.payBillSubcategory, reg.subcategory ?? ''),
      (l10n.billerLocation, data.location ?? ''),
      (l10n.billerCustomerName, reg.customerName ?? ''),
      for (final r in reg.relationships) (labels[r.labelId] ?? r.labelId ?? '', r.value ?? ''),
      if (due != null) (l10n.billerBillDueDate, payDate(due)),
    ].where((r) => r.$1.isNotEmpty && r.$2.isNotEmpty).toList();
  }

  Widget _form(AppLocalizations l10n, PayBillContext data) {
    final supported = BillPayType.supportedBy(data.biller);
    final recharge = data.registration.type == BillerType.recharge;
    final amountLabel = recharge ? l10n.payBillRechargeAmount : l10n.payBillPaymentAmount;
    final currency = data.biller.currency ?? data.registration.ebill?.totalAmount?.currency ?? '';

    final fields = <Widget>[
      if (supported.length > 1)
        PayBoxedPicker(
          label: l10n.billerPaymentType,
          value: _type == null ? null : _typeLabel(l10n, _type!),
          onTap: () async {
            final picked = await showPayPicker<BillPayType>(
              context,
              title: l10n.billerPaymentType,
              selected: _type,
              options: [for (final t in supported) PayOption(value: t, title: _typeLabel(l10n, t))],
            );
            if (picked != null && picked != _type && mounted) {
              setState(() {
                _type = picked;
                _account = null;
                _expiryMonth = null;
                _expiryYear = null;
              });
            }
          },
        )
      else
        PayBoxedPicker(label: l10n.billerPaymentType, value: _type == null ? '' : _typeLabel(l10n, _type!)),
      if (_type != null) _payFrom(l10n, data, _type!),
      if (_type == BillPayType.creditCard) ...[
        PayBoxedPicker(
          label: l10n.payBillExpiryMonth,
          required: true,
          value: _expiryMonth?.toString().padLeft(2, '0'),
          placeholder: l10n.payBillSelect,
          error: _showErrors && _expiryMonth == null ? l10n.addBillerFieldRequired(l10n.payBillExpiryMonth) : null,
          onTap: () async {
            final picked = await showPayPicker<int>(
              context,
              title: l10n.payBillExpiryMonth,
              selected: _expiryMonth,
              options: [for (var m = 1; m <= 12; m++) PayOption(value: m, title: m.toString().padLeft(2, '0'))],
            );
            if (picked != null && mounted) setState(() => _expiryMonth = picked);
          },
        ),
        PayBoxedPicker(
          label: l10n.payBillExpiryYear,
          required: true,
          value: _expiryYear?.toString(),
          placeholder: l10n.payBillSelect,
          error: _showErrors && _expiryYear == null ? l10n.addBillerFieldRequired(l10n.payBillExpiryYear) : null,
          onTap: () async {
            final picked = await showPayPicker<int>(
              context,
              title: l10n.payBillExpiryYear,
              selected: _expiryYear,
              options: [for (final y in BillPayRules.expiryYears(_today)) PayOption(value: y, title: '$y')],
            );
            if (picked != null && mounted) setState(() => _expiryYear = picked);
          },
        ),
      ],
      if (recharge && data.plans.isNotEmpty)
        PayBoxedPicker(
          label: l10n.payBillSelectPlan,
          value: _plan == null ? null : _planLabel(_plan!, currency),
          placeholder: l10n.payBillSelect,
          onTap: () async {
            // '' = no plan: the amount is typed again.
            final picked = await showPayPicker<String>(
              context,
              title: l10n.payBillPlan,
              selected: _plan?.id ?? '',
              options: [
                PayOption(value: '', title: l10n.payBillSelect),
                for (final p in data.plans) PayOption(value: p.id, title: _planLabel(p, currency)),
              ],
            );
            if (picked == null || !mounted) return;
            setState(() {
              _plan = data.plans.where((p) => p.id == picked).firstOrNull;
              _amount.text = _plan?.amount == null ? '' : BillPayRules.amountText(_plan!.amount!);
            });
          },
        ),
      PayBoxedField(
        label: amountLabel,
        required: true,
        error: _amountError(l10n, amountLabel),
        trailing: Text(currency, style: TextStyle(fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context))),
        child: TextField(
          controller: _amount,
          // A plan sets the amount and locks it (S1/hooks.js:126-142).
          readOnly: _plan != null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            LengthLimitingTextInputFormatter(20),
          ],
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
          decoration: const InputDecoration.collapsed(hintText: '0.00'),
        ),
      ),
    ];

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
              _InfoGrid(rows: _summary(l10n, data)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (supported.length > 1) ...[
                PayInfoBanner(message: l10n.payBillAcceptsVia(_joinTypes(l10n, supported))),
                const SizedBox(height: 16),
              ],
              _TwoColumns(children: fields),
              const SizedBox(height: 18),
              _payWhen(l10n),
              const SizedBox(height: 18),
              _attachment(l10n),
            ],
          ),
        ),
      ],
    );
  }

  String _planLabel(BillPlan p, String currency) {
    final amount = p.amount == null ? '' : MoneyFormat.format(p.amount!, currencyCode: p.currency ?? currency);
    return [p.description, amount].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  }

  /// "Account and Credit Cards" (nls supportedAccountNote); more than two
  /// are listed with commas before the last "and".
  String _joinTypes(AppLocalizations l10n, List<BillPayType> types) {
    final names = [for (final t in types) _typeLabel(l10n, t)];
    if (names.length == 1) return names.first;
    return l10n.payBillAcceptsJoin(names.sublist(0, names.length - 1).join(', '), names.last);
  }

  Widget _payFrom(AppLocalizations l10n, PayBillContext data, BillPayType type) {
    final accounts = ref.watch(billPayAccountsProvider(type));
    final list = accounts.valueOrNull;
    // Start on the registration's account, else the default, else the first.
    if (list != null && (_account == null || !list.any((a) => a.value == _account!.value))) {
      final start = BillPayAccount.initial(
        list,
        data.registration.paymentType == type.code ? data.registration.debitAccountValue : null,
      );
      if (start != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _type == type && _account?.value != start.value) setState(() => _account = start);
        });
      }
    }
    if (accounts.hasError) {
      return PayErrorRetry(
        message: accounts.error is BillPaymentsLoadError && (accounts.error as BillPaymentsLoadError).message != null
            ? (accounts.error as BillPaymentsLoadError).message!
            : l10n.payBillAccountsFailed,
        onRetry: () => ref.invalidate(billPayAccountsProvider(type)),
      );
    }
    return PayBoxedPicker(
      label: l10n.billerPayFrom,
      required: true,
      loading: list == null,
      value: _account?.label,
      placeholder: list != null && list.isEmpty ? l10n.payBillNoAccounts : l10n.addBillerSelect,
      error: _showErrors && _account == null ? l10n.addBillerFieldRequired(l10n.billerPayFrom) : null,
      onTap: list == null || list.isEmpty
          ? null
          : () async {
              final picked = await showPayPicker<String>(
                context,
                title: l10n.billerPayFrom,
                selected: _account?.value,
                options: [
                  for (final a in list)
                    PayOption(
                      value: a.value,
                      title: a.label,
                      subtitle: a.balance == null ? null : _money(a.balance!, a.currency),
                      icon: type == BillPayType.casa ? Icons.account_balance_outlined : Icons.credit_card_rounded,
                    ),
                ],
              );
              if (picked != null && mounted) setState(() => _account = list.firstWhere((a) => a.value == picked));
            },
    );
  }

  String _money(MoneyAmount m, String? fallback) =>
      MoneyFormat.format(m.amount, currencyCode: m.currency ?? fallback ?? '');

  /// Pay: Now / Later, and Scheduled Date for Later (tomorrow onwards).
  Widget _payWhen(AppLocalizations l10n) {
    final first = BillPayRules.earliestScheduled(_today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldTitle(l10n.billerPay),
        const SizedBox(height: 8),
        PaySegmented<bool>(
          options: [(false, l10n.now), (true, l10n.later)],
          selected: _payLater,
          onChanged: (v) => setState(() {
            _payLater = v;
            // Now clears the date (S1/hooks.js:148-152).
            if (!v) _scheduled = null;
          }),
        ),
        if (_payLater) ...[
          const SizedBox(height: 12),
          PayBoxedPicker(
            label: l10n.payBillScheduledDate,
            required: true,
            value: _scheduled == null ? null : payDate(_scheduled),
            placeholder: l10n.payBillScheduledDate,
            error: _showErrors && _scheduled == null ? l10n.addBillerFieldRequired(l10n.payBillScheduledDate) : null,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _scheduled ?? first,
                firstDate: first,
                // OBDX sets no latest date; the picker needs one.
                lastDate: DateTime(first.year + 10, first.month, first.day),
              );
              if (picked != null && mounted) setState(() => _scheduled = picked);
            },
          ),
        ],
      ],
    );
  }

  Widget _attachment(AppLocalizations l10n) {
    final file = _file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldTitle(l10n.payBillAddAttachmentQuestion),
        const SizedBox(height: 8),
        PaySegmented<bool>(
          options: [(true, l10n.billerYes), (false, l10n.billerNo)],
          selected: _wantAttachment,
          onChanged: (v) => setState(() => _wantAttachment = v),
        ),
        if (_wantAttachment) ...[
          const SizedBox(height: 12),
          if (file == null)
            PayBoxedField(
              label: l10n.billHistoryAttachment,
              onTap: _busy ? null : _pickFile,
              trailing: Icon(Icons.upload_file_rounded, color: HomeColors.brand(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.payBillChooseFile,
                    style: TextStyle(fontWeight: FontWeight.w600, color: HomeColors.brand(context)),
                  ),
                  const SizedBox(height: 4),
                  PayMuted(l10n.payBillFileSizeNote),
                  PayMuted(l10n.payBillSupportedFiles),
                ],
              ),
            )
          else
            PayBoxedField(
              label: l10n.billHistoryAttachment,
              trailing: IconButton(
                tooltip: l10n.payBillRemoveAttachment,
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _file = null;
                          _attachmentId = null;
                        }),
                icon: Icon(Icons.delete_outline_rounded, color: HomeColors.error(context)),
              ),
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
              ),
            ),
        ],
      ],
    );
  }

  // ── Review and confirmation ────────────────────────────────────────────

  String _amountLabel(PayBillContext data) {
    final request = _request(data);
    return MoneyFormat.format(request.amount, currencyCode: request.currency ?? '');
  }

  String _payWhenLabel(AppLocalizations l10n) =>
      _payLater && _scheduled != null ? payDate(_scheduled) : '${l10n.now} · ${payDate(_today)}';

  Widget _review(AppLocalizations l10n, PayBillContext data) {
    final reg = data.registration;
    final labels = data.biller.specLabels;
    final ebill = reg.ebill;
    final rows = <(String, String)>[
      (l10n.billerName, data.biller.name ?? reg.displayBillerName),
      (l10n.addBillerCategory, data.biller.categoryName ?? ''),
      (l10n.payBillSubCategory, reg.subcategory ?? ''),
      (l10n.billerLocation, data.location ?? ''),
      for (final r in reg.relationships) (labels[r.labelId] ?? r.labelId ?? '', r.value ?? ''),
      (l10n.billerCustomerName, reg.customerName ?? ''),
      (l10n.billerNickname, reg.nickname),
      (l10n.payBillPaymentMethod, _typeLabel(l10n, _type!)),
      (l10n.billerPayFrom, _account!.label),
      if (_type == BillPayType.creditCard)
        (l10n.ccExpiryDate, payDate(BillPayRules.cardExpiryLastDay(_expiryMonth!, _expiryYear!))),
      (l10n.payBillPaymentAmount, _amountLabel(data)),
      (l10n.payBillPayWhen, _payWhenLabel(l10n)),
      if (_wantAttachment && _file != null)
        (l10n.billHistoryAttachment, _file!.name)
      else
        (l10n.payBillAddAnAttachment, l10n.billerNo),
    ].where((r) => r.$1.isNotEmpty && r.$2.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySummaryCard(
          icon: Icons.fact_check_outlined,
          title: l10n.addBillerReview,
          subtitle: l10n.payBillReviewMessage,
          rows: rows,
        ),
        // With an e-bill, OBDX links the amount to "Detailed Bill".
        if (ebill != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _showDetailedBill(l10n, data),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(l10n.payBillDetailedBill),
            ),
          ),
        ],
      ],
    );
  }

  /// "Detailed Bill" (pay-bill-review.html:3, 78-155). OBDX opens it only
  /// when the biller has a logo; the app always does, from the bill it has.
  Future<void> _showDetailedBill(AppLocalizations l10n, PayBillContext data) {
    final reg = data.registration;
    final e = reg.ebill!;
    final labels = data.biller.specLabels;
    String money(MoneyAmount? m) => m == null ? '' : _money(m, data.biller.currency);
    final rows = <(String, String)>[
      (l10n.billerCustomerName, reg.customerName ?? ''),
      for (final r in reg.relationships) (labels[r.labelId] ?? r.labelId ?? '', r.value ?? ''),
      (l10n.payBillBillerNumber, e.id ?? ''),
      (l10n.payBillBillDate, e.generationDate == null ? '' : payDate(e.generationDate)),
      (l10n.billerBillDueDate, e.dueDate == null ? '' : payDate(e.dueDate)),
      (l10n.billerBillAmount, money(e.totalAmount)),
      (l10n.payBillEarlyPayDate, e.earlyPayDate == null ? '' : payDate(e.earlyPayDate)),
      (l10n.payBillEarlyPayDiscount, money(e.earlyPayDiscount)),
      (l10n.payBillEarlyPayBillAmount, money(e.earlyPayBillAmount)),
      (l10n.payBillLatePayCharges, money(e.latePayCharges)),
      (l10n.payBillLatePayBillAmount, money(e.latePayBillAmount)),
      (l10n.payBillDescription, e.description ?? ''),
    ].where((r) => r.$1.isNotEmpty && r.$2.isNotEmpty).toList();
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.payBillDetailedBill),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: _InfoGrid(rows: rows, columns: 1)),
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.payBillOk))],
      ),
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
      (l10n.billerPaymentType, _typeLabel(l10n, _type!)),
      (l10n.billerPayFrom, _account!.label),
      (l10n.payBillAmount, _amountLabel(data)),
      (l10n.payBillPayWhen, _payWhenLabel(l10n)),
      if (_wantAttachment && _file != null) (l10n.payBillAttachments, _file!.name),
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
        if (widget.onAddBiller != null || widget.onHome != null) ...[
          const SizedBox(height: 18),
          _FieldTitle(l10n.payBillNextAction),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (widget.onAddBiller != null)
                PaySecondaryButton(label: l10n.payBillAddBiller, icon: Icons.add_rounded, onPressed: widget.onAddBiller),
              if (widget.onHome != null)
                PaySecondaryButton(label: l10n.home, icon: Icons.home_outlined, onPressed: widget.onHome),
            ],
          ),
        ],
      ],
    );
  }
}

/// Label/value pairs, two columns when there is room.
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.rows, this.columns = 2});

  final List<(String, String)> rows;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final cells = [
      for (final (label, value) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
              ),
            ],
          ),
        ),
    ];
    return columns == 1 ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells) : _TwoColumns(gap: 0, children: cells);
  }
}

/// Two columns from 560 px (the design's web form), one below.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.children, this.gap = 16});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final two = constraints.maxWidth >= 560;
        final rows = <Widget>[];
        for (var k = 0; k < children.length; k += two ? 2 : 1) {
          if (rows.isNotEmpty && gap > 0) rows.add(SizedBox(height: gap));
          rows.add(two
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: children[k]),
                    const SizedBox(width: 24),
                    Expanded(child: k + 1 < children.length ? children[k + 1] : const SizedBox.shrink()),
                  ],
                )
              : children[k]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      },
    );
  }
}

class _FieldTitle extends StatelessWidget {
  const _FieldTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context)),
      );
}
