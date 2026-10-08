import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit_actions.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/retail/term_deposit_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_route_args.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/widgets/td_shared_widgets.dart';

/// Redeem a deposit — OBDX's `td-redeem` flow: full or partial, and where
/// the money goes; `POST .../penalities` quotes the charges and the final
/// amount for the review; `POST .../redemptions` redeems with that quote.
/// Pops `true` once done.
class TdRedeemScreen extends ConsumerStatefulWidget {
  const TdRedeemScreen({super.key, required this.args});

  final TdActionArgs args;

  @override
  ConsumerState<TdRedeemScreen> createState() => _TdRedeemScreenState();
}

class _TdRedeemScreenState extends ConsumerState<TdRedeemScreen> {
  final _amount = TextEditingController();
  int _step = 0;
  TdRedemptionType _type = TdRedemptionType.full;
  TdPayoutDraft _payout = const TdPayoutDraft();
  String? _amountError;
  String? _payoutError;
  bool _quoting = false;
  TdRedeemRequest? _request;
  TdRedemptionQuote? _quote;
  TdSubmitted? _result;

  /// What a full redemption redeems: the current principal.
  double get _fullAmount {
    final d = widget.args.deposit;
    return d.currentPrincipalAmount?.amount ??
        d.availableBalance?.amount ??
        d.principalAmount?.amount ??
        0;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final l10n = AppLocalizations.of(context);
    final partial = _type == TdRedemptionType.partial;
    final typed = tdParseAmount(_amount.text);
    setState(() {
      _amountError = !partial
          ? null
          : typed == null || typed <= 0
              ? l10n.tdEnterAmount
              : typed >= _fullAmount
                  ? l10n.tdPartialTooLarge
                  : null;
      _payoutError = _payout.isComplete ? null : l10n.tdPayoutRequired;
    });
    if (_amountError != null || _payoutError != null) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => _quoting = true);
    final payout = await tdResolvePayout(ref, _payout);
    final request = TdRedeemRequest(
      deposit: widget.args.deposit,
      type: _type,
      amount: partial ? typed! : _fullAmount,
      payout: payout,
    );
    final result =
        await ref.read(termDepositRepositoryProvider).quoteRedemption(request);
    if (!mounted) return;
    setState(() => _quoting = false);
    if (result is Success<TdRedemptionQuote> && result.data != null) {
      setState(() {
        _request = request;
        _quote = result.data;
        _step = 1;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.resolveUserMessage(l10n: l10n, fallback: l10n.tdActionFailed),
        ),
      ),
    );
  }

  void _confirm() {
    final request = _request;
    final quote = _quote;
    if (request == null || quote == null) return;
    final repository = ref.read(termDepositRepositoryProvider);
    ref.read(tdSubmissionProvider.notifier).submit(
          (otp, challenge) => repository.redeem(
            request: request,
            quote: quote,
            otp: otp,
            challenge: challenge,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deposit = widget.args.deposit;
    final ccy = deposit.currencyCode;
    final submission = ref.watch(tdSubmissionProvider);
    tdListenToSubmission(
      ref,
      context,
      onDone: (r) => setState(() {
        _result = r;
        _step = 2;
      }),
    );
    final partial = _type == TdRedemptionType.partial;
    final typeLabel = partial ? l10n.tdRedeemPartial : l10n.tdRedeemFull;
    final redeemAmount = tdAmount(_request?.amount, ccy);

    final Widget child = switch (_step) {
      0 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TdSectionLabel(l10n.tdRedeemTitle),
            const SizedBox(height: 16),
            TdFieldLabel(l10n.tdRedemptionType),
            TdSegmented<TdRedemptionType>(
              options: [
                (TdRedemptionType.full, l10n.tdRedeemFull),
                (TdRedemptionType.partial, l10n.tdRedeemPartial),
              ],
              selected: _type,
              onChanged: (t) => setState(() {
                _type = t;
                _amountError = null;
              }),
            ),
            const SizedBox(height: 16),
            if (partial) ...[
              TdFieldLabel(l10n.tdRedeemAmount),
              TdAmountField(
                controller: _amount,
                currency: ccy,
                error: _amountError,
                helper: l10n.tdRedeemableAmount(tdAmount(_fullAmount, ccy)),
              ),
            ] else
              TdReviewRow(
                label: l10n.tdRedeemAmount,
                value: tdAmount(_fullAmount, ccy),
                emphasize: true,
              ),
            const SizedBox(height: 18),
            TdFieldLabel(l10n.tdPayTo),
            TdPayoutEditor(
              taskCode: TdTask.redeem,
              value: _payout,
              error: _payoutError,
              onChanged: (v) => setState(() {
                _payout = v;
                _payoutError = null;
              }),
            ),
            const SizedBox(height: 14),
            _Note(text: l10n.tdRedeemPenaltyNote),
            const SizedBox(height: 20),
            TdPrimaryButton(
              label: l10n.tdContinue,
              loading: _quoting,
              onPressed: _continue,
            ),
          ],
        ),
      1 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TdSectionLabel(l10n.tdReviewTitle),
            const SizedBox(height: 6),
            TdReviewRow(
                label: l10n.tdDepositAccount, value: deposit.displayNumber),
            TdReviewRow(
              label: l10n.tdHoldAmount,
              value: tdMoney(deposit.holdAmount, currency: ccy),
            ),
            TdReviewRow(label: l10n.tdRedemptionType, value: typeLabel),
            TdReviewRow(label: l10n.tdRedeemAmount, value: redeemAmount),
            TdReviewRow(
              label: l10n.tdChargesPenalty,
              value: tdMoney(_quote?.charges, currency: ccy),
            ),
            TdReviewRow(
              label: l10n.tdFinalRedemptionAmount,
              value: tdMoney(_quote?.netCredit, currency: ccy),
              emphasize: true,
            ),
            TdReviewRow(label: l10n.tdPayTo, value: _payout.label ?? '—'),
            if (partial) ...[
              TdReviewRow(
                label: l10n.tdRevisedMaturityAmount,
                value: tdMoney(_quote?.revisedMaturity, currency: ccy),
              ),
              TdReviewRow(
                label: l10n.tdRevisedInterestRate,
                value: tdRate(_quote?.revisedInterestRate),
              ),
            ],
            const SizedBox(height: 24),
            TdPrimaryButton(
              label: l10n.tdConfirmRedeem,
              loading: submission.isSubmitting,
              onPressed: _confirm,
            ),
          ],
        ),
      _ => TdResultView(
          title: l10n.tdRedeemDone,
          message: l10n.tdRedeemDoneMessage,
          reference: _result?.reference,
          rows: [
            (l10n.tdDepositAccount, deposit.displayNumber),
            (l10n.tdRedemptionType, typeLabel),
            (
              l10n.tdFinalRedemptionAmount,
              tdMoney(_quote?.netCredit, currency: ccy),
            ),
            (l10n.tdPayTo, _payout.label ?? '—'),
          ],
          onDone: () => Navigator.of(context).pop(true),
        ),
    };

    return TdFlowScaffold(
      title: l10n.tdRedeemTitle,
      step: _step,
      onBackStep: () => setState(() => _step = 0),
      summary: TdDepositSummaryCard(deposit: deposit),
      child: child,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HomeColors.warning(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: HomeColors.warning(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      );
}
