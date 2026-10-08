import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit_actions.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/retail/term_deposit_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/td_route_args.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/widgets/td_shared_widgets.dart';

/// Top up a deposit — OBDX's `td-topup` flow: amount + source account,
/// then `POST .../topUps?simulation=true` for the review (revised
/// principal, maturity amount and rate), then the same `topUpDetail`
/// posted for real. Pops `true` once done.
class TdTopUpScreen extends ConsumerStatefulWidget {
  const TdTopUpScreen({super.key, required this.args});

  final TdActionArgs args;

  @override
  ConsumerState<TdTopUpScreen> createState() => _TdTopUpScreenState();
}

class _TdTopUpScreenState extends ConsumerState<TdTopUpScreen> {
  final _amount = TextEditingController();
  int _step = 0;
  TdPayAccount? _source;
  String? _amountError;
  String? _sourceError;
  bool _simulating = false;
  TdTopUpQuote? _quote;
  TdSubmitted? _result;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final l10n = AppLocalizations.of(context);
    final amount = tdParseAmount(_amount.text);
    final source = _source;
    setState(() {
      _amountError = amount == null || amount <= 0 ? l10n.tdEnterAmount : null;
      _sourceError = source == null ? l10n.tdSelectAccountError : null;
      if (_amountError == null &&
          source != null &&
          source.currencyCode == widget.args.deposit.currencyCode &&
          source.balance != null &&
          amount! > source.balance!.amount) {
        _amountError = l10n.tdInsufficientBalance;
      }
    });
    if (_amountError != null || _sourceError != null) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => _simulating = true);
    final result = await ref.read(termDepositRepositoryProvider).simulateTopUp(
          deposit: widget.args.deposit,
          amount: amount!,
          source: source!,
        );
    if (!mounted) return;
    setState(() => _simulating = false);
    if (result is Success<TdTopUpQuote> && result.data != null) {
      setState(() {
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
    final quote = _quote;
    if (quote == null) return;
    final repository = ref.read(termDepositRepositoryProvider);
    ref.read(tdSubmissionProvider.notifier).submit(
          (otp, challenge) => repository.confirmTopUp(
            depositId: widget.args.deposit.id,
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
    final submission = ref.watch(tdSubmissionProvider);
    tdListenToSubmission(
      ref,
      context,
      onDone: (r) => setState(() {
        _result = r;
        _step = 2;
      }),
    );
    final amountText =
        tdAmount(tdParseAmount(_amount.text), deposit.currencyCode);

    final Widget child = switch (_step) {
      0 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TdSectionLabel(l10n.tdTopUpTitle),
            const SizedBox(height: 16),
            TdFieldLabel(l10n.tdTopUpAmount),
            TdAmountField(
              controller: _amount,
              currency: deposit.currencyCode,
              error: _amountError,
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
            ),
            const SizedBox(height: 18),
            TdFieldLabel(l10n.tdPayFrom),
            TdPayAccountField(
              taskCode: TdTask.topUp,
              selected: _source,
              error: _sourceError,
              onSelected: (a) => setState(() {
                _source = a;
                _sourceError = null;
              }),
            ),
            const SizedBox(height: 24),
            TdPrimaryButton(
              label: l10n.tdContinue,
              loading: _simulating,
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
              label: l10n.tdDepositAccount,
              value: deposit.displayNumber,
            ),
            TdReviewRow(
              label: l10n.tdCurrentBalance,
              value:
                  tdMoney(deposit.currentValue, currency: deposit.currencyCode),
            ),
            TdReviewRow(label: l10n.tdTopUpAmount, value: amountText),
            TdReviewRow(
                label: l10n.tdPayFrom, value: _source?.displayNumber ?? '—'),
            TdReviewRow(
              label: l10n.tdRevisedPrincipal,
              value: tdMoney(_quote?.revisedPrincipal,
                  currency: deposit.currencyCode),
            ),
            TdReviewRow(
              label: l10n.tdRevisedMaturityAmount,
              value: tdMoney(_quote?.revisedMaturity,
                  currency: deposit.currencyCode),
              emphasize: true,
            ),
            if (deposit.module != 'ISL')
              TdReviewRow(
                label: l10n.tdRevisedInterestRate,
                value: tdRate(_quote?.revisedInterestRate),
              ),
            const SizedBox(height: 24),
            TdPrimaryButton(
              label: l10n.tdConfirmTopUp,
              loading: submission.isSubmitting,
              onPressed: _confirm,
            ),
          ],
        ),
      _ => TdResultView(
          title: l10n.tdTopUpDone,
          message: l10n.tdTopUpDoneMessage,
          reference: _result?.reference,
          rows: [
            (l10n.tdDepositAccount, deposit.displayNumber),
            (l10n.tdTopUpAmount, amountText),
            (l10n.tdPayFrom, _source?.displayNumber ?? '—'),
          ],
          onDone: () => Navigator.of(context).pop(true),
        ),
    };

    return TdFlowScaffold(
      title: l10n.tdTopUpTitle,
      step: _step,
      onBackStep: () => setState(() => _step = 0),
      summary: TdDepositSummaryCard(deposit: deposit),
      child: child,
    );
  }
}
