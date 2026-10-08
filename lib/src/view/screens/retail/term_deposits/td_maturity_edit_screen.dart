import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit_actions.dart';
import 'package:ubci_bank/src/view/providers/retail/term_deposit_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_route_args.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/widgets/td_shared_widgets.dart';

/// Edit what happens at maturity — OBDX's `td-amend` flow: pick a
/// roll-over option, the amount for "renew a special amount", and where
/// any money paid out goes; `PUT .../deposit/{id}` saves it. Pops `true`
/// once done.
class TdMaturityEditScreen extends ConsumerStatefulWidget {
  const TdMaturityEditScreen({super.key, required this.args});

  final TdActionArgs args;

  @override
  ConsumerState<TdMaturityEditScreen> createState() =>
      _TdMaturityEditScreenState();
}

class _TdMaturityEditScreenState extends ConsumerState<TdMaturityEditScreen> {
  final _rollOverAmount = TextEditingController();
  int _step = 0;
  late String? _rollOver = widget.args.deposit.rollOverType;
  TdPayoutDraft _payout = const TdPayoutDraft();
  String? _optionError;
  String? _amountError;
  String? _payoutError;
  bool _preparing = false;
  TdMaturityUpdate? _update;
  TdSubmitted? _result;

  @override
  void dispose() {
    _rollOverAmount.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final l10n = AppLocalizations.of(context);
    final deposit = widget.args.deposit;
    final code = _rollOver;
    final special = code == TdRollOver.renewSpecialAmount;
    final amount = tdParseAmount(_rollOverAmount.text);
    final max =
        deposit.availableBalance?.amount ?? deposit.currentValue?.amount;
    setState(() {
      _optionError = code == null ? l10n.tdSelectMaturityOption : null;
      _amountError = !special
          ? null
          : amount == null || amount <= 0
              ? l10n.tdEnterAmount
              : max != null && amount > max
                  ? l10n.tdRollOverTooLarge(tdAmount(max, deposit.currencyCode))
                  : null;
      _payoutError = TdRollOver.needsPayout(code) && !_payout.isComplete
          ? l10n.tdPayoutRequired
          : null;
    });
    if (_optionError != null || _amountError != null || _payoutError != null) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => _preparing = true);
    final payout = TdRollOver.needsPayout(code)
        ? await tdResolvePayout(ref, _payout)
        : null;
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _update = TdMaturityUpdate(
        deposit: deposit,
        rollOverType: code!,
        payout: payout,
        rollOverAmount: special ? amount : null,
      );
      _step = 1;
    });
  }

  void _confirm() {
    final update = _update;
    if (update == null) return;
    final repository = ref.read(termDepositRepositoryProvider);
    ref.read(tdSubmissionProvider.notifier).submit(
          (otp, challenge) => repository.updateMaturity(
            update: update,
            otp: otp,
            challenge: challenge,
          ),
        );
  }

  /// What the payout covers for a roll-over option.
  String _payToLabel(AppLocalizations l10n, String? code) => switch (code) {
        TdRollOver.closeOnMaturity => l10n.tdPayPrincipalAndInterestTo,
        TdRollOver.renewPrincipal => l10n.tdPayInterestTo,
        _ => l10n.tdPayRemainingTo,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deposit = widget.args.deposit;
    final options = ref.watch(tdRollOverOptionsProvider);
    final labels = options.valueOrNull ?? const <TdEnumOption>[];
    final submission = ref.watch(tdSubmissionProvider);
    tdListenToSubmission(
      ref,
      context,
      onDone: (r) => setState(() {
        _result = r;
        _step = 2;
      }),
    );
    final current = tdRollOverLabel(deposit.rollOverType, labels);
    final chosen = tdRollOverLabel(_rollOver, labels);
    final reviewRows = [
      (l10n.tdDepositAccount, deposit.displayNumber),
      (l10n.tdCurrentInstruction, current),
      (l10n.tdNewInstruction, chosen),
      if (_update?.rollOverAmount != null)
        (
          l10n.tdRollOverAmount,
          tdAmount(_update!.rollOverAmount, deposit.currencyCode),
        ),
      if (_update?.payout != null)
        (_payToLabel(l10n, _rollOver), _update!.payout!.label),
    ];

    final Widget child = switch (_step) {
      0 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TdSectionLabel(l10n.tdEditMaturityTitle),
            const SizedBox(height: 4),
            Text(
              l10n.tdEditMaturityIntro,
              style: TextStyle(
                fontSize: 12.5,
                color: HomeColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            TdFieldLabel(l10n.tdMaturityInstruction),
            if (options.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final o in labels)
                _OptionTile(
                  label: o.description,
                  current: o.code == deposit.rollOverType,
                  selected: o.code == _rollOver,
                  onTap: () => setState(() {
                    _rollOver = o.code;
                    _optionError = null;
                    _payoutError = null;
                  }),
                ),
            TdFieldError(_optionError),
            if (_rollOver == TdRollOver.renewSpecialAmount) ...[
              const SizedBox(height: 14),
              TdFieldLabel(l10n.tdRollOverAmount),
              TdAmountField(
                controller: _rollOverAmount,
                currency: deposit.currencyCode,
                error: _amountError,
              ),
            ],
            if (TdRollOver.needsPayout(_rollOver)) ...[
              const SizedBox(height: 16),
              TdFieldLabel(_payToLabel(l10n, _rollOver)),
              TdPayoutEditor(
                taskCode: TdTask.amend,
                value: _payout,
                error: _payoutError,
                onChanged: (v) => setState(() {
                  _payout = v;
                  _payoutError = null;
                }),
              ),
            ],
            const SizedBox(height: 22),
            TdPrimaryButton(
              label: l10n.tdContinue,
              loading: _preparing,
              onPressed: _continue,
            ),
          ],
        ),
      1 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TdSectionLabel(l10n.tdReviewTitle),
            const SizedBox(height: 6),
            for (final (label, value) in reviewRows)
              TdReviewRow(label: label, value: value),
            const SizedBox(height: 24),
            TdPrimaryButton(
              label: l10n.tdConfirmChanges,
              loading: submission.isSubmitting,
              onPressed: _confirm,
            ),
          ],
        ),
      _ => TdResultView(
          title: l10n.tdMaturityUpdated,
          message: l10n.tdMaturityUpdatedMessage,
          reference: _result?.reference,
          rows: [
            for (final row in reviewRows)
              if (row.$1 != l10n.tdCurrentInstruction) row,
          ],
          onDone: () => Navigator.of(context).pop(true),
        ),
    };

    return TdFlowScaffold(
      title: l10n.tdEditMaturityTitle,
      step: _step,
      onBackStep: () => setState(() => _step = 0),
      summary: TdDepositSummaryCard(
        deposit: deposit,
        extra: [(l10n.tdCurrentInstruction, current)],
      ),
      child: child,
    );
  }
}

/// A radio-style choice card.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected
              ? brand.withValues(alpha: 0.06)
              : HomeColors.card(context),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? brand : HomeColors.divider(context),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: selected ? brand : HomeColors.textSecondary(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                  ),
                  if (current)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: HomeColors.divider(context),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        l10n.tdCurrent,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.textSecondary(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
