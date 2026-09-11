import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/models/loan_account_details.dart';
import 'package:ubci_bank/src/core/models/loan_repayment.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/loan_detail_providers.dart';
import 'package:ubci_bank/src/view/providers/loan_repayment_providers.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_pin_input.dart';
import 'package:ubci_bank/src/view/widgets/settlement_account_picker_sheet.dart';

/// Route arguments for [LoanRepaymentScreen].
class LoanRepaymentArgs {
  const LoanRepaymentArgs({required this.loan});

  final LoanAccount loan;
}

/// "Repay Now" — a 3-step flow (amount + account → review → result) backed
/// by `POST /digx-common/loan/v1/loan/{id}/repayments`.
///
/// The settlement account is chosen from a native bottom sheet showing
/// each account's balance, matching payment-app conventions rather than a
/// plain web-style list.
///
/// Layout: on phones this is a single scrolling column with a compact
/// horizontal step tracker under the header. From the tablet breakpoint up
/// it switches to a two-pane "checkout" shell — a sticky brand summary +
/// vertical stepper on the left, the active step's card centered on the
/// right — instead of just stretching the phone column to a wider,
/// oddly-empty canvas.
///
/// The submitted `typeOfSettlement` is `'P'`, the only value observed in
/// the OBDX capture this flow is built from (a partial/principal
/// repayment against the loan's outstanding balance). If your host also
/// exposes a distinct "pay next installment" or "full settlement" code,
/// that would need its own request variant — this covers the general
/// "pay an amount toward the loan" case.
class LoanRepaymentScreen extends ConsumerStatefulWidget {
  const LoanRepaymentScreen({super.key, required this.args});

  final LoanRepaymentArgs args;

  @override
  ConsumerState<LoanRepaymentScreen> createState() =>
      _LoanRepaymentScreenState();
}

class _LoanRepaymentScreenState extends ConsumerState<LoanRepaymentScreen> {
  final _amountController = TextEditingController();
  late final LoanDetailKey _key;

  int _step = 0; // 0 = form, 1 = review, 2 = result
  CasaAccount? _selectedAccount;
  String? _amountError;
  String? _accountError;
  bool _amountPrefilled = false;

  @override
  void initState() {
    super.initState();
    _key = LoanDetailKey(
      loanId: widget.args.loan.id,
      module: widget.args.loan.module,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showOtpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Caps the sheet's width on tablet/desktop so it reads as a centered
      // dialog-style sheet rather than stretching edge-to-edge across a
      // wide browser window; on phones this is a no-op since the viewport
      // is already narrower than the cap.
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => const _OtpVerificationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // React to submission results without threading extra state through
    // the review step's button.
    ref.listen<LoanRepaymentSubmissionState>(loanRepaymentSubmissionProvider,
        (previous, next) {
      if (next.result != null && previous?.result != next.result) {
        HapticFeedback.mediumImpact();
        setState(() => _step = 2);
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
      // Host has OTP step-up enabled for this task — open the OTP sheet
      // the first time a challenge appears. The sheet watches submission
      // state itself (attempts left, inline errors) and closes itself
      // once a result comes back, so we only need to open it once here.
      if (next.otpChallenge != null && previous?.otpChallenge == null) {
        HapticFeedback.selectionClick();
        _showOtpSheet(context);
      }
    });

    final wide = Responsive.of(context).useWideLayout;
    final outstandingAsync = ref.watch(loanRepaymentOutstandingProvider(_key));
    final currency = outstandingAsync.valueOrNull?.outstandingAmount?.currency ??
        widget.args.loan.currencyCode;

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 28 : 16,
                wide ? 16 : 12,
                wide ? 28 : 16,
                8,
              ),
              child: Row(
                children: [
                  if (_step != 2)
                    CasaBackButton(
                      onPressed:
                          _step == 1 ? () => setState(() => _step = 0) : null,
                    ),
                  if (_step != 2) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.loanRepaymentTitle,
                      style: TextStyle(
                        fontSize: wide ? 22 : 14,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.textPrimary(context),
                        letterSpacing: wide ? 0.2 : 0,
                      ),
                    ),
                  ),
                  if (wide && _step != 2) _StepProgressCompact(step: _step),
                ],
              ),
            ),
            if (!wide) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _StepProgressBar(step: _step),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: wide
                  ? _buildWideBody(context, l10n, outstandingAsync, currency)
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: double.infinity),
                        child: switch (_step) {
                          1 => _buildReviewStep(context, l10n, wide: false),
                          2 => _buildResultStep(context, l10n, wide: false),
                          _ => _buildFormStep(context, l10n, wide: false),
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tablet/desktop "checkout" shell: a sticky brand summary + vertical
  /// stepper on the left, the active step centered on the right. This is
  /// what actually makes the wide layout feel designed for the viewport,
  /// rather than a phone column stretched into empty whitespace.
  Widget _buildWideBody(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<LoanOutstanding> outstandingAsync,
    String currency,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 320,
            child: _SummaryPanel(
              loan: widget.args.loan,
              outstandingAsync: outstandingAsync,
              currency: currency,
              step: _step,
              l10n: l10n,
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: switch (_step) {
                  1 => _buildReviewStep(context, l10n, wide: true),
                  2 => _buildResultStep(context, l10n, wide: true),
                  _ => _buildFormStep(context, l10n, wide: true),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormStep(BuildContext context, AppLocalizations l10n,
      {required bool wide}) {
    final outstandingAsync = ref.watch(loanRepaymentOutstandingProvider(_key));
    final accountsAsync = ref.watch(loanRepaymentSettlementAccountsProvider);

    return outstandingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ErrorRetryView(
        message: err.toString(),
        onRetry: () => ref.invalidate(loanRepaymentOutstandingProvider(_key)),
      ),
      data: (outstanding) => accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorRetryView(
          message: err.toString(),
          onRetry: () =>
              ref.invalidate(loanRepaymentSettlementAccountsProvider),
        ),
        data: (accounts) =>
            _buildForm(context, l10n, outstanding, accounts, wide: wide),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    LoanOutstanding outstanding,
    List<CasaAccount> accounts, {
    required bool wide,
  }) {
    final currency = outstanding.outstandingAmount?.currency ??
        widget.args.loan.currencyCode;
    final outstandingValue = outstanding.outstandingAmount?.amount;

    if (!_amountPrefilled && outstandingValue != null) {
      _amountController.text = outstandingValue.toStringAsFixed(2);
      _amountPrefilled = true;
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        wide ? 0 : 16,
        wide ? 4 : 16,
        wide ? 0 : 16,
        32,
      ),
      children: [
        // The brand summary card already carries this context on wide
        // layouts, so only repeat it inline on phones where there's no
        // side panel.
        if (!wide) ...[
          _OutstandingCard(
            label: l10n.loanOutstandingAmountLabel,
            value: outstandingValue == null
                ? '—'
                : MoneyFormat.format(outstandingValue, currencyCode: currency),
            loanTitle: widget.args.loan.title,
          ),
          const SizedBox(height: 24),
        ],
        _SectionLabel(l10n.loanRepaymentAmountLabel),
        const SizedBox(height: 8),
        _AmountField(
          controller: _amountController,
          currency: currency,
          errorText: _amountError,
          onChanged: () {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
        if (outstandingValue != null && outstandingValue > 0) ...[
          const SizedBox(height: 10),
          _QuickAmountChips(
            outstandingValue: outstandingValue,
            currency: currency,
            onSelect: (value) {
              setState(() {
                _amountController.text = value.toStringAsFixed(2);
                _amountError = null;
              });
            },
          ),
        ],
        const SizedBox(height: 24),
        _SectionLabel(l10n.loanRepaymentFromAccountLabel),
        const SizedBox(height: 8),
        if (accounts.isEmpty)
          Text(
            l10n.loanRepaymentNoAccounts,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          )
        else
          _AccountPickerTile(
            account: _selectedAccount,
            errorText: _accountError,
            hint: l10n.loanRepaymentSelectAccountHint,
            onTap: () async {
              final selected = await SettlementAccountPickerSheet.show(
                context,
                title: l10n.loanRepaymentSelectAccountHint,
                accounts: accounts,
                selected: _selectedAccount,
              );
              if (selected == null) return;
              setState(() {
                _selectedAccount = selected;
                _accountError = null;
              });
            },
          ),
        const SizedBox(height: 32),
        _PrimaryButton(
          label: l10n.loanRepaymentContinueButton,
          icon: Icons.arrow_forward_rounded,
          onPressed: accounts.isEmpty
              ? null
              : () => _validateAndContinue(l10n, outstandingValue),
        ),
      ],
    );
  }

  void _validateAndContinue(AppLocalizations l10n, double? outstandingValue) {
    final amount = double.tryParse(_amountController.text.trim());
    String? amountError;
    String? accountError;

    if (amount == null || amount <= 0) {
      amountError = l10n.loanRepaymentAmountRequired;
    } else if (outstandingValue != null && amount > outstandingValue) {
      amountError = l10n.loanRepaymentAmountExceedsOutstanding;
    }

    if (_selectedAccount == null) {
      accountError = l10n.loanRepaymentSelectAccountRequired;
    }

    if (amountError != null || accountError != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _amountError = amountError;
        _accountError = accountError;
      });
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _amountError = null;
      _accountError = null;
      _step = 1;
    });
  }

  Widget _buildReviewStep(BuildContext context, AppLocalizations l10n,
      {required bool wide}) {
    final submission = ref.watch(loanRepaymentSubmissionProvider);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final outstandingAsync = ref.watch(loanRepaymentOutstandingProvider(_key));
    final currency =
        outstandingAsync.valueOrNull?.outstandingAmount?.currency ??
            widget.args.loan.currencyCode;
    final account = _selectedAccount;

    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 0 : 16, wide ? 4 : 16, wide ? 0 : 16, 16),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                l10n.loanRepaymentAmountLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: HomeColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                MoneyFormat.format(amount, currencyCode: currency),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: HomeColors.textPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _TransferPathCard(
          fromLabel: account == null
              ? '—'
              : '${account.title} · ${account.maskedNumber}',
          toLabel: widget.args.loan.title,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReviewRow(
                label: l10n.loanRepaymentFromLabel,
                value: account == null
                    ? '—'
                    : '${account.title} · ${account.maskedNumber}',
              ),
              Divider(color: HomeColors.divider(context)),
              _ReviewRow(
                label: l10n.loanRepaymentToLabel,
                value: widget.args.loan.title,
              ),
              Divider(color: HomeColors.divider(context)),
              _ReviewRow(
                label: l10n.loanRepaymentAmountLabel,
                value: MoneyFormat.format(amount, currencyCode: currency),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _PrimaryButton(
          label: l10n.loanRepaymentConfirmButton,
          icon: Icons.lock_outline_rounded,
          isLoading: submission.isSubmitting,
          onPressed: submission.isSubmitting
              ? null
              : () => _confirmAndSubmit(currency, amount),
        ),
      ],
    );
  }

  void _confirmAndSubmit(String currency, double amount) {
    final account = _selectedAccount;
    if (account == null) return;

    HapticFeedback.lightImpact();

    final outstanding =
        ref.read(loanRepaymentOutstandingProvider(_key)).valueOrNull;

    final request = LoanRepaymentRequest(
      amount: amount,
      currency: currency,
      settlementAccountId: account.id,
      settlementAccountDisplay: account.displayNumber,
      principalAmount: outstanding?.principalBalance?.amount,
      principalBalance: outstanding?.principalBalance?.amount,
    );

    ref.read(loanRepaymentSubmissionProvider.notifier).submit(
          loanId: widget.args.loan.id,
          request: request,
        );
  }

  Widget _buildResultStep(BuildContext context, AppLocalizations l10n,
      {required bool wide}) {
    final submission = ref.watch(loanRepaymentSubmissionProvider);
    final result = submission.result;
    final account = _selectedAccount;

    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 8 : 24, wide ? 24 : 24, wide ? 8 : 24, 24),
      children: [
        Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HomeColors.brand(context).withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: HomeColors.success(context),
                size: 52,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.loanRepaymentSuccessTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.loanRepaymentSuccessMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: HomeColors.textSecondary(context)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            children: [
              if (result?.amount != null) ...[
                Text(
                  MoneyFormat.format(
                    result!.amount!.amount,
                    currencyCode: result.amount!.currency ?? '',
                  ),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (account != null) ...[
                Divider(color: HomeColors.divider(context)),
                _ReviewRow(
                  label: l10n.loanRepaymentFromLabel,
                  value: '${account.title} · ${account.maskedNumber}',
                ),
              ],
              Divider(color: HomeColors.divider(context)),
              _ReviewRow(
                label: l10n.loanRepaymentToLabel,
                value: widget.args.loan.title,
              ),
              if (result?.referenceKey != null) ...[
                Divider(color: HomeColors.divider(context)),
                _ReviewRow(
                  label: l10n.loanRepaymentReferenceLabel,
                  value: result!.referenceKey!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        _PrimaryButton(
          label: l10n.loanRepaymentDoneButton,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// Compact brand summary card shown at the top of the phone-width form
/// (the wide layout gets the same context from [_SummaryPanel] instead).
class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard({
    required this.label,
    required this.value,
    required this.loanTitle,
  });

  final String label;
  final String value;
  final String loanTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: HomeColors.brand(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.request_quote_outlined,
                  color: HomeColors.brand(context),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loanTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: HomeColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: HomeColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky left-hand summary + vertical stepper for the tablet/desktop
/// checkout shell. Gives wide viewports their own purpose-built layout
/// instead of a centered, stretched phone column.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.loan,
    required this.outstandingAsync,
    required this.currency,
    required this.step,
    required this.l10n,
  });

  final LoanAccount loan;
  final AsyncValue<LoanOutstanding> outstandingAsync;
  final String currency;
  final int step;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final outstandingValue = outstandingAsync.valueOrNull?.outstandingAmount?.amount;
    final displayValue = outstandingAsync.isLoading
        ? '…'
        : outstandingValue == null
            ? '—'
            : MoneyFormat.format(outstandingValue, currencyCode: currency);

    // Driven by the live theme (not a hardcoded hex) so this tracks
    // whatever brand color + light/dark mode the app is actually running,
    // matching the button/chip colors elsewhere on this screen.
    final brand = HomeColors.brand(context);
    final brandDark = HomeColors.brandDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [brand, brandDark],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loan.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.loanOutstandingAmountLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayValue,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepListItem(
                index: 0,
                current: step,
                icon: Icons.payments_outlined,
                label: l10n.loanRepaymentAmountLabel,
              ),
              _StepConnector(done: step > 0),
              _StepListItem(
                index: 1,
                current: step,
                icon: Icons.fact_check_outlined,
                label: l10n.loanRepaymentConfirmButton,
              ),
              _StepConnector(done: step > 1),
              _StepListItem(
                index: 2,
                current: step,
                icon: Icons.check_circle_outline_rounded,
                label: l10n.loanRepaymentDoneButton,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepListItem extends StatelessWidget {
  const _StepListItem({
    required this.index,
    required this.current,
    required this.icon,
    required this.label,
    this.isLast = false,
  });

  final int index;
  final int current;
  final IconData icon;
  final String label;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final done = current > index;
    final active = current == index;
    final circleColor = done || active ? brand : HomeColors.divider(context);
    final textColor = done || active
        ? HomeColors.textPrimary(context)
        : HomeColors.textSecondary(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? brand : Colors.transparent,
            border: Border.all(color: circleColor, width: 1.6),
          ),
          child: Icon(
            done ? Icons.check_rounded : icon,
            size: 15,
            color: done ? Colors.white : circleColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14.5),
      child: Container(
        width: 1.4,
        height: 22,
        color: done
            ? HomeColors.brand(context)
            : HomeColors.divider(context),
      ),
    );
  }
}

/// Compact horizontal "Step X of 3" indicator shown next to the title on
/// wide layouts once the shell already has the vertical stepper — kept
/// tiny so it doesn't compete with the sticky panel.
class _StepProgressCompact extends StatelessWidget {
  const _StepProgressCompact({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${step + 1} / 3',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: HomeColors.textSecondary(context),
      ),
    );
  }
}

/// Phone-width step tracker — three dots joined by a fill line, matching
/// common mobile payment-flow conventions.
class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final divider = HomeColors.divider(context);

    Widget dot(int index) {
      final done = step > index;
      final active = step == index;
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done || active ? brand : Colors.transparent,
          border: Border.all(color: done || active ? brand : divider, width: 1.6),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : HomeColors.textSecondary(context),
                ),
              ),
      );
    }

    Widget line(bool filled) => Expanded(
          child: Container(
            height: 1.6,
            color: filled ? brand : divider,
          ),
        );

    return Row(
      children: [
        dot(0),
        line(step > 0),
        dot(1),
        line(step > 1),
        dot(2),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: HomeColors.textPrimary(context),
      ),
    );
  }
}

/// Large, payment-app-style amount entry field with an inline currency
/// badge instead of a plain `prefixText`.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.currency,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String currency;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final field = Container(
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError ? HomeColors.error(context) : HomeColors.divider(context),
          width: hasError ? 1.4 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (currency.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: HomeColors.brand(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currency,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.brand(context),
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );

    if (!hasError) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            errorText!,
            style: TextStyle(color: HomeColors.error(context), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _QuickAmountChips extends StatelessWidget {
  const _QuickAmountChips({
    required this.outstandingValue,
    required this.currency,
    required this.onSelect,
  });

  final double outstandingValue;
  final String currency;
  final ValueChanged<double> onSelect;

  @override
  Widget build(BuildContext context) {
    final options = <(String, double)>[
      ('100%', outstandingValue),
      ('75%', outstandingValue * 0.75),
      ('50%', outstandingValue * 0.5),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _Chip(
            label: option.$1,
            onTap: () => onSelect(option.$2),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.brand(context).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: HomeColors.brand(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: HomeColors.brand(context),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}

/// From → To visual used on the review step — two labeled avatars joined
/// by an arrow, so the direction of money movement reads at a glance
/// instead of only appearing in a label/value table.
class _TransferPathCard extends StatelessWidget {
  const _TransferPathCard({required this.fromLabel, required this.toLabel});

  final String fromLabel;
  final String toLabel;

  @override
  Widget build(BuildContext context) {
    Widget node(IconData icon, String label) {
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: HomeColors.brand(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: HomeColors.brand(context), size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: HomeColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        node(Icons.account_balance_wallet_outlined, fromLabel),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: HomeColors.textSecondary(context),
            size: 18,
          ),
        ),
        node(Icons.request_quote_outlined, toLabel),
      ],
    );
  }
}

class _AccountPickerTile extends StatelessWidget {
  const _AccountPickerTile({
    required this.account,
    required this.hint,
    required this.onTap,
    this.errorText,
  });

  final CasaAccount? account;
  final String hint;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: HomeColors.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasError
                    ? HomeColors.error(context)
                    : HomeColors.divider(context),
                width: hasError ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: HomeColors.brand(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: HomeColors.brand(context),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: account == null
                      ? Text(
                          hint,
                          style: TextStyle(
                            color: HomeColors.textSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: HomeColors.textPrimary(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              account!.maskedNumber,
                              style: TextStyle(
                                color: HomeColors.textSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
                if (account?.displayBalance != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    MoneyFormat.format(
                      account!.displayBalance!.amount,
                      currencyCode:
                          account!.displayBalance!.currency ?? account!.currencyCode,
                    ),
                    style: TextStyle(
                      color: HomeColors.textSecondary(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  Icons.expand_more_rounded,
                  color: HomeColors.textSecondary(context),
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: TextStyle(
                color: HomeColors.error(context),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: HomeColors.textSecondary(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: emphasize ? 16 : 13,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetryView extends StatelessWidget {
  const _ErrorRetryView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.error_outline_rounded,
          size: 40,
          color: HomeColors.textSecondary(context),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: HomeColors.textSecondary(context)),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: Text(l10n.accountsRetry),
          ),
        ),
      ],
    );
  }
}

class _OtpVerificationSheet extends ConsumerStatefulWidget {
  const _OtpVerificationSheet();

  @override
  ConsumerState<_OtpVerificationSheet> createState() =>
      _OtpVerificationSheetState();
}

class _OtpVerificationSheetState
    extends ConsumerState<_OtpVerificationSheet> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  String? _localError;
  bool _poppedForSuccess = false;

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      final l10n = AppLocalizations.of(context);
      HapticFeedback.mediumImpact();
      setState(() => _localError = l10n.loanRepaymentOtpEmpty);
      return;
    }
    setState(() => _localError = null);
    HapticFeedback.lightImpact();
    ref.read(loanRepaymentSubmissionProvider.notifier).verifyOtp(otp);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final submission = ref.watch(loanRepaymentSubmissionProvider);

    // Close the sheet ourselves once verification succeeds — the parent
    // screen's own listener then advances to the result step.
    ref.listen<LoanRepaymentSubmissionState>(loanRepaymentSubmissionProvider,
        (previous, next) {
      if (next.result != null && !_poppedForSuccess) {
        _poppedForSuccess = true;
        Navigator.of(context).pop();
      }
    });

    final challenge = submission.otpChallenge;
    final attemptsLeft = challenge?.attemptsLeft;
    final inlineError = submission.otpError ?? _localError;
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HomeColors.divider(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.loanRepaymentOtpTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.loanRepaymentOtpSubtitle,
              style: TextStyle(
                fontSize: 13,
                color: HomeColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            OtpPinInput(
              controller: _otpController,
              focusNode: _otpFocusNode,
              obscuringCharacter: '*',
            ),
            if (inlineError != null) ...[
              const SizedBox(height: 8),
              Text(
                inlineError,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: HomeColors.error(context),
                ),
              ),
            ],
            if (attemptsLeft != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.loanRepaymentOtpAttemptsLeft(attemptsLeft),
                style: TextStyle(
                  fontSize: 12,
                  color: HomeColors.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: submission.isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.brand(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: submission.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.loanRepaymentOtpVerifyButton),
            ),
          ],
        ),
      ),
    );
  }
}