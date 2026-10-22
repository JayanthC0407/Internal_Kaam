import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Edit Biller — OBDX `modify-biller` → `modify-biller-review`, for a
/// **Manual** biller (Auto Pay / Scheduled Pay billers are refused before
/// this opens). Details (read-only biller facts + the editable nickname) →
/// Review → Done; Confirm sends `PUT registeredBillers/{id}`.
/// Evidence: docs/obdx/features/bill-payments.md §6.
class EditBillerScreen extends ConsumerStatefulWidget {
  const EditBillerScreen({
    super.key,
    required this.biller,
    required this.onExit,
    required this.onUpdated,
  });

  final RegisteredBiller biller;

  /// Leaves without changing anything.
  final VoidCallback onExit;

  /// After "Back to Billers" on the Done step.
  final ValueChanged<BillerEditOutcome> onUpdated;

  @override
  ConsumerState<EditBillerScreen> createState() => _EditBillerScreenState();
}

/// Edit Biller's own Biller Type labels (nls/modify-biller.js:67-71).
String billerEditTypeLabel(AppLocalizations l10n, BillerType type) => switch (type) {
      BillerType.presentmentPayment => l10n.billerEditTypePresentmentPayment,
      BillerType.presentment => l10n.billerEditTypePresentment,
      BillerType.payment => l10n.billerDetailsTypePayment,
      BillerType.recharge => l10n.billerTypeRecharge,
      BillerType.unknown => '',
    };

class _EditBillerScreenState extends ConsumerState<EditBillerScreen> {
  int _step = 0;
  bool _busy = false;
  bool _showErrors = false;
  late final _nickname = TextEditingController(text: widget.biller.nickname);
  BillerEditOutcome? _outcome;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  String? _nicknameError(AppLocalizations l10n) {
    if (!_showErrors) return null;
    return switch (BillerFieldRules.editNickname(_nickname.text)) {
      null => null,
      BillerFieldError.required => l10n.addBillerFieldRequired(l10n.billerNickname),
      BillerFieldError.tooLong => l10n.addBillerFieldTooLong(l10n.billerNickname, BillerFieldRules.nicknameMaxLength),
      _ => l10n.addBillerNicknameError,
    };
  }

  void _submit() {
    if (BillerFieldRules.editNickname(_nickname.text) != null) {
      setState(() => _showErrors = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  /// Confirm → `PUT registeredBillers/{id}`, with the same OTP loop as
  /// add and delete (OBDX handles 417 on every call).
  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(billPaymentsRepositoryProvider);
    final request = EditBillerRequest(biller: widget.biller, nickname: _nickname.text);
    setState(() => _busy = true);
    var result = await repository.updateBiller(request);
    while (mounted && result is Success<BillerEditOutcome> && result.data?.challenge != null) {
      final outcome = result.data!;
      setState(() => _busy = false);
      if (!mounted) return;
      final otp = await showPayOtpPrompt(
        context,
        title: l10n.editBillerOtpTitle(widget.biller.nickname),
        error: outcome.invalidOtp ? l10n.billerOtpInvalid : null,
        attemptsLeft: outcome.challenge!.attemptsLeft,
      );
      // Cancelled: nothing changed; stay on Review.
      if (!mounted || otp == null) return;
      setState(() => _busy = true);
      result = await repository.updateBiller(request, challenge: outcome.challenge, otp: otp);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result is Success<BillerEditOutcome> && result.data != null) {
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
          content: Text(result.resolveUserMessage(l10n: l10n, fallback: l10n.editBillerFailed)),
        ));
    }
  }

  /// The biller facts OBDX shows read-only (modify-biller.html).
  List<(String, String)> _facts(AppLocalizations l10n) {
    final b = widget.biller;
    final location = b.location;
    return [
      (l10n.addBillerCategory, b.category?.name ?? b.biller?.categoryName ?? ''),
      (l10n.billerLocation, [location?.areaName, location?.city].whereType<String>().join(', ')),
      (l10n.billerName, b.displayBillerName),
      (l10n.billerType, billerEditTypeLabel(l10n, b.type)),
      (l10n.billerCustomerName, b.customerName ?? ''),
    ].where((r) => r.$2.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reviewRows = [
      ..._facts(l10n),
      (l10n.billerNickname, _nickname.text.trim()),
      (l10n.billerPaymentType, l10n.billerTypeManual),
    ];
    final Widget child = switch (_step) {
      0 => _details(l10n),
      1 => PaySummaryCard(
          icon: Icons.fact_check_outlined,
          title: l10n.addBillerReview,
          subtitle: l10n.editBillerReviewMessage,
          rows: reviewRows,
        ),
      _ => PaySummaryCard(
          icon: _outcome?.pendingApproval == true ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded,
          // OBDX: "Biller updated successfully." or "Pending Approval".
          title: _outcome?.pendingApproval == true ? l10n.addBillerPendingApproval : l10n.editBillerSuccess,
          subtitle: _nickname.text.trim(),
          rows: reviewRows,
          note: _outcome?.reference == null ? null : l10n.billerReferenceNumber(_outcome!.reference!),
        ),
    };

    return PayFlowScaffold(
      title: l10n.billerEdit,
      subtitle: _step == 1 ? l10n.editBillerReviewMessage : widget.biller.nickname,
      step: _step,
      onBackStep: _busy ? null : () => setState(() => _step = 0),
      onExit: _busy ? null : widget.onExit,
      action: switch (_step) {
        0 => PayPrimaryButton(label: l10n.addBillerSubmit, onPressed: _submit),
        1 => PayPrimaryButton(label: l10n.addBillerConfirm, loading: _busy, onPressed: _busy ? null : _confirm),
        _ => PayPrimaryButton(label: l10n.addBillerBackToBillers, onPressed: () => widget.onUpdated(_outcome!)),
      },
      child: child,
    );
  }

  Widget _details(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySection(
          title: l10n.billerDetailsTitle,
          icon: Icons.storefront_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (label, value) in _facts(l10n)) _ReadOnlyRow(label: label, value: value),
              const SizedBox(height: 14),
              PayTextField(
                label: l10n.editBillerNicknameLabel,
                required: true,
                controller: _nickname,
                inputFormatters: [LengthLimitingTextInputFormatter(BillerFieldRules.nicknameMaxLength)],
                onChanged: (_) => setState(() {}),
                error: _nicknameError(l10n),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: HomeColors.divider(context)))),
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
    );
  }
}
