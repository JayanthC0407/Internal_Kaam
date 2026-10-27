import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_pay_models.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// The payment fields Pay Bill and Pay Bills share (OBDX pay-bill-stage1
/// and initiate-multiple-bill-payments-stage1 ask the same things; the
/// latter once per bill). Evidence: docs/obdx/features/bill-payments.md §7-8.

/// One bill's answers while it is being filled in.
class BillPayDraft {
  BillPayDraft({this.multiple = false, this.expiryMonth, this.expiryYear});

  /// The several-bills flow: its CASA task code and debit card filter.
  final bool multiple;

  BillPayType? type;

  /// The user picked a Payment Type: the several-bills flow then lists
  /// Account without a task code (stage1/hooks.js:756).
  bool typePicked = false;
  BillPayAccount? account;
  BillPlan? plan;
  final amount = TextEditingController();
  bool payLater = false;
  DateTime? scheduled;
  int? expiryMonth;
  int? expiryYear;
  bool wantAttachment = false;
  BillAttachment? file;

  /// The uploaded file's id; cleared when the file changes.
  Map<String, dynamic>? attachmentId;
  bool showErrors = false;

  void dispose() => amount.dispose();

  BillPayAccountsQuery get accountsQuery => (
        type: type!,
        taskCode: multiple ? (typePicked ? null : billPayMultipleTaskCode) : billPayTaskCode,
        multiple: multiple,
      );

  double? get amountValue => plan?.amount ?? double.tryParse(amount.text.trim().replaceAll(',', ''));

  bool get isCard => type == BillPayType.creditCard;

  /// Every field passes OBDX's rules (card expiry checked apart, as OBDX).
  bool get complete =>
      type != null &&
      account != null &&
      (plan?.amount != null || BillPayRules.amount(amount.text) == null) &&
      (!isCard || (expiryMonth != null && expiryYear != null)) &&
      (!payLater || scheduled != null);

  bool expiryValid(DateTime today) =>
      !isCard || BillPayRules.cardExpiryValid(expiryMonth!, expiryYear!, today);

  /// The file to upload before the payment, if any.
  BillAttachment? get pendingUpload => wantAttachment && attachmentId == null ? file : null;

  void startFrom(PayBillContext data) {
    final reg = data.registration;
    type = BillPayType.initial(BillPayType.supportedBy(data.biller), multiple ? null : reg.paymentType);
    payLater = !multiple && reg.payLater;
    final prefill = BillPayRules.prefill(reg.ebill);
    if (prefill != null) amount.text = BillPayRules.amountText(prefill);
  }

  PayBillRequest request(PayBillContext data, DateTime today) => PayBillRequest(
        registration: data.registration,
        biller: data.biller,
        type: type!,
        account: account!,
        amount: amountValue!,
        today: today,
        payLater: payLater,
        scheduledDate: scheduled,
        plan: plan,
        location: data.location,
        cardExpiry: isCard ? BillPayRules.cardExpiryLastDay(expiryMonth!, expiryYear!) : null,
        attachmentId: wantAttachment ? attachmentId : null,
      );
}

String billPayTypeLabel(AppLocalizations l10n, BillPayType type) => switch (type) {
      BillPayType.casa => l10n.payBillTypeAccount,
      BillPayType.creditCard => l10n.payBillTypeCreditCards,
      BillPayType.debitCard => l10n.payBillTypeDebitCards,
    };

String billMoney(MoneyAmount m, String? fallback) =>
    MoneyFormat.format(m.amount, currencyCode: m.currency ?? fallback ?? '');

/// The read-only biller summary (pay-bill-stage1.html:13-35).
List<(String, String)> billSummaryRows(AppLocalizations l10n, PayBillContext data) {
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

/// The Review rows for one bill (pay-bill-review.html; the several-bills
/// review has the same rows per bill).
List<(String, String)> billReviewRows(
  AppLocalizations l10n,
  PayBillContext data,
  BillPayDraft draft,
  DateTime today,
) {
  final reg = data.registration;
  final labels = data.biller.specLabels;
  return [
    (l10n.billerName, data.biller.name ?? reg.displayBillerName),
    (l10n.addBillerCategory, data.biller.categoryName ?? ''),
    (l10n.payBillSubCategory, reg.subcategory ?? ''),
    (l10n.billerLocation, data.location ?? ''),
    for (final r in reg.relationships) (labels[r.labelId] ?? r.labelId ?? '', r.value ?? ''),
    (l10n.billerCustomerName, reg.customerName ?? ''),
    (l10n.billerNickname, reg.nickname),
    (l10n.payBillPaymentMethod, billPayTypeLabel(l10n, draft.type!)),
    (l10n.billerPayFrom, draft.account!.label),
    if (draft.isCard)
      (l10n.ccExpiryDate, payDate(BillPayRules.cardExpiryLastDay(draft.expiryMonth!, draft.expiryYear!))),
    (l10n.payBillPaymentAmount, billAmountLabel(data, draft, today)),
    (l10n.payBillPayWhen, billPayWhenLabel(l10n, draft, today)),
    if (draft.wantAttachment && draft.file != null)
      (l10n.billHistoryAttachment, draft.file!.name)
    else
      (l10n.payBillAddAnAttachment, l10n.billerNo),
  ].where((r) => r.$1.isNotEmpty && r.$2.isNotEmpty).toList();
}

String billAmountLabel(PayBillContext data, BillPayDraft draft, DateTime today) {
  final request = draft.request(data, today);
  return MoneyFormat.format(request.amount, currencyCode: request.currency ?? '');
}

String billPayWhenLabel(AppLocalizations l10n, BillPayDraft draft, DateTime today) =>
    draft.payLater && draft.scheduled != null ? payDate(draft.scheduled) : '${l10n.now} · ${payDate(today)}';

/// "Detailed Bill" (pay-bill-review.html:3, 78-155). OBDX opens it only
/// when the biller has a logo; the app always does, from the bill it has.
Future<void> showDetailedBill(BuildContext context, PayBillContext data) {
  final l10n = AppLocalizations.of(context);
  final reg = data.registration;
  final e = reg.ebill!;
  final labels = data.biller.specLabels;
  String money(MoneyAmount? m) => m == null ? '' : billMoney(m, data.biller.currency);
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
        child: SingleChildScrollView(child: BillInfoGrid(rows: rows, columns: 1)),
      ),
      actions: [FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.payBillOk))],
    ),
  );
}

/// Picks one attachment and checks OBDX's size and type rules; null when
/// cancelled or refused (with OBDX's message).
Future<BillAttachment?> pickBillAttachment(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void snack(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
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
    snack(l10n.payBillPickFailed);
    return null;
  }
  final picked = result?.files.firstOrNull;
  if (picked == null || picked.bytes == null) return null;
  if (picked.bytes!.length > BillAttachmentRules.maxBytes) {
    snack(l10n.payBillFileTooLarge);
    return null;
  }
  if (!BillAttachmentRules.allowedName(picked.name)) {
    snack(l10n.payBillInvalidFile);
    return null;
  }
  return BillAttachment(name: picked.name, bytes: picked.bytes!);
}

/// The payment fields for one bill: the "accepts payment via" note,
/// Payment Type, Pay From, Expiry Month / Year, Select Plan, the amount,
/// Pay Now / Later and the attachment. [onChanged] repaints the owner.
/// [accountAction] / [dateAction] sit beside Pay From and Pay (the
/// several-bills flow's "Default … for all" icons).
class BillPayFields extends ConsumerWidget {
  const BillPayFields({
    super.key,
    required this.draft,
    required this.data,
    required this.onChanged,
    this.busy = false,
    this.accountAction,
    this.dateAction,
  });

  final BillPayDraft draft;
  final PayBillContext data;
  final VoidCallback onChanged;
  final bool busy;
  final Widget? accountAction;
  final Widget? dateAction;

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  void _set(VoidCallback change) {
    change();
    onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final supported = BillPayType.supportedBy(data.biller);
    final recharge = data.registration.type == BillerType.recharge;
    final amountLabel = recharge ? l10n.payBillRechargeAmount : l10n.payBillPaymentAmount;
    final currency = data.biller.currency ?? data.registration.ebill?.totalAmount?.currency ?? '';
    final type = draft.type;

    String? required(bool missing, String label) =>
        draft.showErrors && missing ? l10n.addBillerFieldRequired(label) : null;

    final fields = <Widget>[
      if (supported.length > 1)
        PayBoxedPicker(
          label: l10n.billerPaymentType,
          value: type == null ? null : billPayTypeLabel(l10n, type),
          onTap: () async {
            final picked = await showPayPicker<BillPayType>(
              context,
              title: l10n.billerPaymentType,
              selected: type,
              options: [for (final t in supported) PayOption(value: t, title: billPayTypeLabel(l10n, t))],
            );
            if (picked != null && picked != draft.type) {
              _set(() {
                draft
                  ..type = picked
                  ..typePicked = true
                  ..account = null;
                if (!draft.multiple) {
                  draft
                    ..expiryMonth = null
                    ..expiryYear = null;
                }
              });
            }
          },
        )
      else
        PayBoxedPicker(label: l10n.billerPaymentType, value: type == null ? '' : billPayTypeLabel(l10n, type)),
      if (type != null) _payFrom(context, ref, l10n, type),
      if (type == BillPayType.creditCard) ...[
        PayBoxedPicker(
          label: l10n.payBillExpiryMonth,
          required: true,
          value: draft.expiryMonth?.toString().padLeft(2, '0'),
          placeholder: l10n.payBillSelect,
          error: required(draft.expiryMonth == null, l10n.payBillExpiryMonth),
          onTap: () async {
            final picked = await showPayPicker<int>(
              context,
              title: l10n.payBillExpiryMonth,
              selected: draft.expiryMonth,
              options: [for (var m = 1; m <= 12; m++) PayOption(value: m, title: m.toString().padLeft(2, '0'))],
            );
            if (picked != null) _set(() => draft.expiryMonth = picked);
          },
        ),
        PayBoxedPicker(
          label: l10n.payBillExpiryYear,
          required: true,
          value: draft.expiryYear?.toString(),
          placeholder: l10n.payBillSelect,
          error: required(draft.expiryYear == null, l10n.payBillExpiryYear),
          onTap: () async {
            final picked = await showPayPicker<int>(
              context,
              title: l10n.payBillExpiryYear,
              selected: draft.expiryYear,
              options: [for (final y in BillPayRules.expiryYears(_today)) PayOption(value: y, title: '$y')],
            );
            if (picked != null) _set(() => draft.expiryYear = picked);
          },
        ),
      ],
      if (recharge && data.plans.isNotEmpty)
        PayBoxedPicker(
          label: l10n.payBillSelectPlan,
          value: draft.plan == null ? null : _planLabel(draft.plan!, currency),
          placeholder: l10n.payBillSelect,
          onTap: () async {
            // '' = no plan: the amount is typed again.
            final picked = await showPayPicker<String>(
              context,
              title: l10n.payBillPlan,
              selected: draft.plan?.id ?? '',
              options: [
                PayOption(value: '', title: l10n.payBillSelect),
                for (final p in data.plans) PayOption(value: p.id, title: _planLabel(p, currency)),
              ],
            );
            if (picked == null) return;
            _set(() {
              draft.plan = data.plans.where((p) => p.id == picked).firstOrNull;
              draft.amount.text = draft.plan?.amount == null ? '' : BillPayRules.amountText(draft.plan!.amount!);
            });
          },
        ),
      PayBoxedField(
        label: amountLabel,
        required: true,
        error: _amountError(l10n, amountLabel),
        trailing: Text(currency, style: TextStyle(fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context))),
        child: TextField(
          controller: draft.amount,
          // A plan sets the amount and locks it (S1/hooks.js:126-142).
          readOnly: draft.plan != null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            LengthLimitingTextInputFormatter(20),
          ],
          onChanged: (_) => onChanged(),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
          decoration: const InputDecoration.collapsed(hintText: '0.00'),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (supported.length > 1) ...[
          PayInfoBanner(message: l10n.payBillAcceptsVia(_joinTypes(l10n, supported))),
          const SizedBox(height: 16),
        ],
        BillTwoColumns(children: fields),
        const SizedBox(height: 18),
        _payWhen(context, l10n),
        const SizedBox(height: 18),
        _attachment(context, l10n),
      ],
    );
  }

  String? _amountError(AppLocalizations l10n, String label) {
    if (!draft.showErrors || draft.plan != null) return null;
    return switch (BillPayRules.amount(draft.amount.text)) {
      null => null,
      BillAmountError.required => l10n.addBillerFieldRequired(label),
      BillAmountError.notPositive => l10n.payBillAmountNotPositive,
      BillAmountError.invalid => l10n.payBillAmountInvalid,
    };
  }

  String _planLabel(BillPlan p, String currency) {
    final amount = p.amount == null ? '' : MoneyFormat.format(p.amount!, currencyCode: p.currency ?? currency);
    return [p.description, amount].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  }

  /// "Account and Credit Cards" (nls supportedAccountNote); more than two
  /// are listed with commas before the last "and".
  String _joinTypes(AppLocalizations l10n, List<BillPayType> types) {
    final names = [for (final t in types) billPayTypeLabel(l10n, t)];
    if (names.length == 1) return names.first;
    return l10n.payBillAcceptsJoin(names.sublist(0, names.length - 1).join(', '), names.last);
  }

  Widget _payFrom(BuildContext context, WidgetRef ref, AppLocalizations l10n, BillPayType type) {
    final query = draft.accountsQuery;
    final accounts = ref.watch(billPayAccountsProvider(query));
    final list = accounts.valueOrNull;
    // OBDX's account-input starts on the default account, else the first;
    // pay-bill also on the registration's own (S1/hooks.js:430-437).
    if (list != null && (draft.account == null || !list.any((a) => a.value == draft.account!.value))) {
      final reg = data.registration;
      final start = BillPayAccount.initial(
        list,
        !draft.multiple && reg.paymentType == type.code ? reg.debitAccountValue : null,
      );
      if (start != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (draft.type == type && draft.account?.value != start.value) _set(() => draft.account = start);
        });
      }
    }
    if (accounts.hasError) {
      return PayErrorRetry(
        message: accounts.error is BillPaymentsLoadError && (accounts.error as BillPaymentsLoadError).message != null
            ? (accounts.error as BillPaymentsLoadError).message!
            : l10n.payBillAccountsFailed,
        onRetry: () => ref.invalidate(billPayAccountsProvider(query)),
      );
    }
    final picker = PayBoxedPicker(
      label: l10n.billerPayFrom,
      required: true,
      loading: list == null,
      value: draft.account?.label,
      placeholder: list != null && list.isEmpty ? l10n.payBillNoAccounts : l10n.addBillerSelect,
      error: draft.showErrors && draft.account == null ? l10n.addBillerFieldRequired(l10n.billerPayFrom) : null,
      onTap: list == null || list.isEmpty
          ? null
          : () async {
              final picked = await showPayPicker<String>(
                context,
                title: l10n.billerPayFrom,
                selected: draft.account?.value,
                options: [
                  for (final a in list)
                    PayOption(
                      value: a.value,
                      title: a.label,
                      subtitle: a.balance == null ? null : billMoney(a.balance!, a.currency),
                      icon: type == BillPayType.casa ? Icons.account_balance_outlined : Icons.credit_card_rounded,
                    ),
                ],
              );
              if (picked != null) _set(() => draft.account = list.firstWhere((a) => a.value == picked));
            },
    );
    final action = accountAction;
    if (action == null) return picker;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: picker), action]);
  }

  /// Pay: Now / Later, and Scheduled Date for Later (tomorrow onwards).
  Widget _payWhen(BuildContext context, AppLocalizations l10n) {
    final first = BillPayRules.earliestScheduled(_today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: BillFieldTitle(l10n.billerPay)),
            if (dateAction != null) dateAction!,
          ],
        ),
        const SizedBox(height: 8),
        PaySegmented<bool>(
          options: [(false, l10n.now), (true, l10n.later)],
          selected: draft.payLater,
          onChanged: (v) => _set(() {
            draft.payLater = v;
            // Now clears the date (S1/hooks.js:148-152).
            if (!v) draft.scheduled = null;
          }),
        ),
        if (draft.payLater) ...[
          const SizedBox(height: 12),
          PayBoxedPicker(
            label: l10n.payBillScheduledDate,
            required: true,
            value: draft.scheduled == null ? null : payDate(draft.scheduled),
            placeholder: l10n.payBillScheduledDate,
            error: draft.showErrors && draft.scheduled == null
                ? l10n.addBillerFieldRequired(l10n.payBillScheduledDate)
                : null,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: draft.scheduled ?? first,
                firstDate: first,
                // OBDX sets no latest date; the picker needs one.
                lastDate: DateTime(first.year + 10, first.month, first.day),
              );
              if (picked != null) _set(() => draft.scheduled = picked);
            },
          ),
        ],
      ],
    );
  }

  Widget _attachment(BuildContext context, AppLocalizations l10n) {
    final file = draft.file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BillFieldTitle(l10n.payBillAddAttachmentQuestion),
        const SizedBox(height: 8),
        PaySegmented<bool>(
          options: [(true, l10n.billerYes), (false, l10n.billerNo)],
          selected: draft.wantAttachment,
          onChanged: (v) => _set(() => draft.wantAttachment = v),
        ),
        if (draft.wantAttachment) ...[
          const SizedBox(height: 12),
          if (file == null)
            PayBoxedField(
              label: l10n.billHistoryAttachment,
              onTap: busy
                  ? null
                  : () async {
                      final picked = await pickBillAttachment(context);
                      if (picked != null) {
                        _set(() {
                          draft
                            ..file = picked
                            ..attachmentId = null;
                        });
                      }
                    },
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
                onPressed: busy
                    ? null
                    : () => _set(() {
                          draft
                            ..file = null
                            ..attachmentId = null;
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
}

/// Label/value pairs, two columns when there is room.
class BillInfoGrid extends StatelessWidget {
  const BillInfoGrid({super.key, required this.rows, this.columns = 2});

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
    return columns == 1
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)
        : BillTwoColumns(gap: 0, children: cells);
  }
}

/// Two columns from 560 px (the design's web form), one below.
class BillTwoColumns extends StatelessWidget {
  const BillTwoColumns({super.key, required this.children, this.gap = 16});

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

class BillFieldTitle extends StatelessWidget {
  const BillFieldTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context)),
      );
}
