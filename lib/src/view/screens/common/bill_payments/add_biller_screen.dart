import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/billers_screen.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/widgets/bills_help_panel.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';

/// Add Billers — OBDX `flows/add-biller` (Payment Type **Manual** only so
/// far). Details → Review → Done, like OBDX's two stages plus its confirm
/// screen: pick a biller, fill its reference fields (one per biller
/// specification), nickname and customer name; Confirm sends
/// `POST registeredBillers`. The Details step follows the designer's form
/// (UI designs 2026-10-27): boxed fields in two columns on web, "Required"
/// tags, a note naming what is still empty, Submit / Cancel.
/// Evidence: docs/obdx/features/bill-payments.md §4.
class AddBillerScreen extends ConsumerStatefulWidget {
  const AddBillerScreen({super.key, required this.onExit, required this.onAdded});

  /// Leaves without adding.
  final VoidCallback onExit;

  /// After "Back to Billers" on the Done step.
  final ValueChanged<BillerAddOutcome> onAdded;

  @override
  ConsumerState<AddBillerScreen> createState() => _AddBillerScreenState();
}

class _AddBillerScreenState extends ConsumerState<AddBillerScreen> {
  int _step = 0;
  bool _busy = false;
  bool _showErrors = false;

  BillerInfo? _biller;
  final _nickname = TextEditingController();
  final _customerName = TextEditingController();
  final _specs = <String, TextEditingController>{};
  BillerAddOutcome? _outcome;

  @override
  void dispose() {
    _nickname.dispose();
    _customerName.dispose();
    for (final c in _specs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBiller(List<BillerInfo> billers) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPayPicker<BillerInfo>(
      context,
      title: l10n.billerName,
      empty: l10n.addBillerNoBillers,
      selected: _biller,
      options: [
        for (final b in billers)
          PayOption(value: b, title: b.name ?? b.id, subtitle: b.pickerLabel, avatar: b.name ?? b.id),
      ],
    );
    if (picked == null || picked.id == _biller?.id || !mounted) return;
    // A new biller has its own fields; OBDX clears nickname and customer
    // name too (add-biller-stage1/hooks.js:51-56).
    setState(() {
      _biller = picked;
      for (final c in _specs.values) {
        c.dispose();
      }
      _specs
        ..clear()
        ..addEntries(picked.specifications.map((s) => MapEntry(s.id, TextEditingController())));
      _nickname.clear();
      _customerName.clear();
      _showErrors = false;
    });
  }

  String? _errorText(AppLocalizations l10n, String label, BillerFieldError? error, {int? max, String? invalid}) {
    if (!_showErrors || error == null) return null;
    return switch (error) {
      BillerFieldError.required => l10n.addBillerFieldRequired(label),
      BillerFieldError.tooLong => l10n.addBillerFieldTooLong(label, max ?? 0),
      BillerFieldError.alphanumeric => l10n.addBillerFieldAlphanumeric,
      BillerFieldError.numeric => l10n.addBillerFieldNumeric,
      BillerFieldError.text => l10n.addBillerFieldText,
      BillerFieldError.invalid => invalid ?? l10n.addBillerFieldInvalid,
    };
  }

  bool get _valid {
    final biller = _biller;
    if (biller == null) return false;
    return BillerFieldRules.nickname(_nickname.text) == null &&
        BillerFieldRules.customerName(_customerName.text) == null &&
        biller.specifications.every((s) => BillerFieldRules.spec(s, _specs[s.id]?.text ?? '') == null);
  }

  void _submit() {
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  AddBillerRequest _request() => AddBillerRequest(
        biller: _biller!,
        nickname: _nickname.text,
        customerName: _customerName.text,
        relationshipValues: {for (final e in _specs.entries) e.key: e.value.text},
      );

  /// Confirm → `POST registeredBillers`. OBDX asks for an OTP on any call
  /// that answers 417 (2fa-interrupt.js:67), so this loops like delete does.
  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(billPaymentsRepositoryProvider);
    final request = _request();
    setState(() => _busy = true);
    var result = await repository.addBiller(request);
    while (mounted && result is Success<BillerAddOutcome> && result.data?.challenge != null) {
      final outcome = result.data!;
      setState(() => _busy = false);
      if (!mounted) return;
      final otp = await showPayOtpPrompt(
        context,
        title: l10n.addBillerOtpTitle(request.nickname.trim()),
        error: outcome.invalidOtp ? l10n.billerOtpInvalid : null,
        attemptsLeft: outcome.challenge!.attemptsLeft,
      );
      // Cancelled: nothing was added; stay on Review.
      if (!mounted || otp == null) return;
      setState(() => _busy = true);
      result = await repository.addBiller(request, challenge: outcome.challenge, otp: otp);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result is Success<BillerAddOutcome> && result.data != null) {
      final outcome = result.data!;
      HapticFeedback.mediumImpact();
      setState(() {
        _outcome = outcome;
        _step = 2;
      });
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(result.resolveUserMessage(l10n: l10n, fallback: l10n.addBillerFailed)),
        ));
    }
  }

  List<(String, String)> _reviewRows(AppLocalizations l10n) {
    final biller = _biller!;
    return [
      (l10n.billerName, biller.name ?? ''),
      (l10n.addBillerCategory, biller.pickerLabel),
      (l10n.billerType, billerTypeLabel(l10n, biller.type)),
      for (final spec in biller.specifications)
        if ((_specs[spec.id]?.text ?? '').trim().isNotEmpty) (spec.label, _specs[spec.id]!.text.trim()),
      (l10n.billerNickname, _nickname.text.trim()),
      (l10n.billerCustomerName, _customerName.text.trim()),
      (l10n.billerPaymentType, l10n.billerTypeManual),
    ].where((r) => r.$2.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Widget child = switch (_step) {
      0 => _details(l10n),
      1 => PaySummaryCard(
          icon: Icons.fact_check_outlined,
          title: l10n.addBillerReview,
          subtitle: l10n.addBillerReviewMessage,
          rows: _reviewRows(l10n),
        ),
      _ => PaySummaryCard(
          icon: _outcome?.pendingApproval == true
              ? Icons.hourglass_top_rounded
              : Icons.check_circle_outline_rounded,
          // OBDX: "Biller added successfully." or "Pending Approval".
          title: _outcome?.pendingApproval == true ? l10n.addBillerPendingApproval : l10n.addBillerSuccess,
          subtitle: _nickname.text.trim(),
          rows: _reviewRows(l10n),
          note: _outcome?.reference == null ? null : l10n.billerReferenceNumber(_outcome!.reference!),
        ),
    };

    return PayFlowScaffold(
      title: l10n.billersAdd,
      subtitle: switch (_step) {
        0 => l10n.addBillerIntro,
        1 => l10n.addBillerReviewMessage,
        _ => null,
      },
      step: _step,
      onBackStep: _busy ? null : () => setState(() => _step = 0),
      onExit: _busy ? null : widget.onExit,
      action: switch (_step) {
        0 => Row(
            children: [
              Expanded(child: PayPrimaryButton(label: l10n.addBillerSubmit, onPressed: _submit)),
              const SizedBox(width: 12),
              Expanded(child: PaySecondaryButton(label: l10n.cancel, onPressed: widget.onExit)),
            ],
          ),
        1 => PayPrimaryButton(label: l10n.addBillerConfirm, loading: _busy, onPressed: _busy ? null : _confirm),
        _ => PayPrimaryButton(
            label: l10n.addBillerBackToBillers,
            onPressed: () => widget.onAdded(_outcome!),
          ),
      },
      child: child,
    );
  }

  /// The required fields still empty, by label (for the design's note).
  List<String> _missing(AppLocalizations l10n) {
    final biller = _biller;
    if (biller == null) return const [];
    return [
      for (final spec in biller.specifications)
        if (spec.required && (_specs[spec.id]?.text.trim().isEmpty ?? true)) spec.label,
      if (_nickname.text.trim().isEmpty) l10n.billerNickname,
      if (_customerName.text.trim().isEmpty) l10n.billerCustomerName,
    ];
  }

  /// "A, B and C" for the note.
  String _joinLabels(List<String> labels) => labels.length <= 1
      ? labels.join()
      : '${labels.sublist(0, labels.length - 1).join(', ')} and ${labels.last}';

  Widget _details(AppLocalizations l10n) {
    final billers = ref.watch(availableBillersProvider);
    final biller = _biller;
    final missing = _missing(l10n);

    final nameField = billers.when(
      loading: () => PayBoxedPicker(label: l10n.billerName, placeholder: l10n.addBillerSelect, required: true, loading: true),
      error: (error, _) => PayErrorRetry(
        message: error is BillPaymentsLoadError && error.message != null ? error.message! : l10n.addBillerLoadFailed,
        onRetry: () => ref.invalidate(availableBillersProvider),
      ),
      data: (list) => PayBoxedPicker(
        label: l10n.billerName,
        value: biller?.name,
        placeholder: l10n.addBillerSelect,
        required: true,
        error: _showErrors && biller == null ? l10n.addBillerFieldRequired(l10n.billerName) : null,
        onTap: () => _pickBiller(list),
      ),
    );

    final fields = <Widget>[
      nameField,
      if (biller != null) ...[
        // Read-only, from the biller picked (OBDX shows them as text).
        PayBoxedPicker(label: l10n.addBillerCategory, value: biller.pickerLabel),
        PayBoxedPicker(label: l10n.billerType, value: billerTypeLabel(l10n, biller.type)),
        PayBoxedTextField(
          label: l10n.billerNickname,
          required: true,
          controller: _nickname,
          hint: l10n.billerNickname,
          inputFormatters: [LengthLimitingTextInputFormatter(BillerFieldRules.nicknameMaxLength)],
          onChanged: (_) => setState(() {}),
          error: _errorText(
            l10n,
            l10n.billerNickname,
            BillerFieldRules.nickname(_nickname.text),
            max: BillerFieldRules.nicknameMaxLength,
            invalid: l10n.addBillerNicknameError,
          ),
        ),
        for (final spec in biller.specifications)
          PayBoxedTextField(
            label: spec.label,
            required: spec.required,
            controller: _specs[spec.id]!,
            hint: spec.label,
            keyboardType: spec.datatype == 'NUMERIC' ? TextInputType.number : TextInputType.text,
            inputFormatters: [
              if (spec.maxLength != null && spec.maxLength! > 0) LengthLimitingTextInputFormatter(spec.maxLength),
            ],
            onChanged: (_) => setState(() {}),
            error: _errorText(l10n, spec.label, BillerFieldRules.spec(spec, _specs[spec.id]!.text), max: spec.maxLength),
          ),
        PayBoxedTextField(
          label: l10n.billerCustomerName,
          required: true,
          controller: _customerName,
          hint: l10n.billerCustomerName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(BillerFieldRules.customerNameMaxLength)],
          onChanged: (_) => setState(() {}),
          error: _errorText(
            l10n,
            l10n.billerCustomerName,
            BillerFieldRules.customerName(_customerName.text),
            max: BillerFieldRules.customerNameMaxLength,
            invalid: l10n.addBillerCustomerNameError,
          ),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Two columns when there is room (the design's web form).
              final twoColumns = constraints.maxWidth >= 560;
              final rows = <Widget>[];
              for (var k = 0; k < fields.length; k += twoColumns ? 2 : 1) {
                if (rows.isNotEmpty) rows.add(const SizedBox(height: 16));
                rows.add(twoColumns
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: fields[k]),
                          const SizedBox(width: 24),
                          Expanded(child: k + 1 < fields.length ? fields[k + 1] : const SizedBox.shrink()),
                        ],
                      )
                    : fields[k]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...rows,
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    PayInfoBanner(
                      title: l10n.addBillerRequiredTitle,
                      message: l10n.addBillerRequiredBody(_joinLabels(missing)),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        // OBDX's Payment Type (Manual only so far).
        PaySection(
          title: l10n.billerPaymentType,
          icon: Icons.payments_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PayChoiceChips<String>(
                options: [('MANUAL', l10n.billerTypeManual)],
                selected: 'MANUAL',
                onChanged: (_) {},
              ),
              const SizedBox(height: 10),
              PayNote(l10n.addBillerPaymentNote),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BillsHelpPanel.add(l10n),
      ],
    );
  }
}
