import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/models/loan_account_details.dart';
import 'package:ubci_bank/src/core/models/loan_repayment.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/providers/loan_detail_providers.dart';
import 'package:ubci_bank/src/view/providers/loan_repayment_providers.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
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

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: Text(l10n.loanRepaymentTitle),
        backgroundColor: HomeColors.bg(context),
        foregroundColor: HomeColors.textPrimary(context),
        elevation: 0,
        automaticallyImplyLeading: _step != 2,
        leading: _step == 1
            ? IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _step = 0),
        )
            : null,
      ),
      body: SafeArea(
        child: switch (_step) {
          1 => _buildReviewStep(context, l10n),
          2 => _buildResultStep(context, l10n),
          _ => _buildFormStep(context, l10n),
        },
      ),
    );
  }

  Widget _buildFormStep(BuildContext context, AppLocalizations l10n) {
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
        data: (accounts) => _buildForm(context, l10n, outstanding, accounts),
      ),
    );
  }

  Widget _buildForm(
      BuildContext context,
      AppLocalizations l10n,
      LoanOutstanding outstanding,
      List<CasaAccount> accounts,
      ) {
    final currency = outstanding.outstandingAmount?.currency ??
        widget.args.loan.currencyCode;
    final outstandingValue = outstanding.outstandingAmount?.amount;

    if (!_amountPrefilled && outstandingValue != null) {
      _amountController.text = outstandingValue.toStringAsFixed(2);
      _amountPrefilled = true;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.loanOutstandingAmountLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: HomeColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                outstandingValue == null
                    ? '—'
                    : MoneyFormat.format(
                  outstandingValue,
                  currencyCode: currency,
                ),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.loanRepaymentAmountLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HomeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: InputDecoration(
            prefixText: currency.isNotEmpty ? '$currency  ' : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            errorText: _amountError,
          ),
          onChanged: (_) {
            if (_amountError != null) {
              setState(() => _amountError = null);
            }
          },
        ),
        const SizedBox(height: 20),
        Text(
          l10n.loanRepaymentFromAccountLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HomeColors.textPrimary(context),
          ),
        ),
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
        FilledButton(
          onPressed:
          accounts.isEmpty ? null : () => _validateAndContinue(l10n, outstandingValue),
          style: FilledButton.styleFrom(
            backgroundColor: HomeColors.brand(context),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(l10n.loanRepaymentContinueButton),
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

  Widget _buildReviewStep(BuildContext context, AppLocalizations l10n) {
    final submission = ref.watch(loanRepaymentSubmissionProvider);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final outstandingAsync = ref.watch(loanRepaymentOutstandingProvider(_key));
    final currency =
        outstandingAsync.valueOrNull?.outstandingAmount?.currency ??
            widget.args.loan.currencyCode;
    final account = _selectedAccount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        const SizedBox(height: 32),
        FilledButton(
          onPressed: submission.isSubmitting
              ? null
              : () => _confirmAndSubmit(currency, amount),
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
              : Text(l10n.loanRepaymentConfirmButton),
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

  Widget _buildResultStep(BuildContext context, AppLocalizations l10n) {
    final submission = ref.watch(loanRepaymentSubmissionProvider);
    final result = submission.result;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.teal50,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.successColor,
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
          if (result?.amount != null) ...[
            const SizedBox(height: 20),
            Text(
              MoneyFormat.format(
                result!.amount!.amount,
                currencyCode: result.amount!.currency ?? '',
              ),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ],
          if (result?.referenceKey != null) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.loanRepaymentReferenceLabel}: ${result!.referenceKey}',
              style: TextStyle(color: HomeColors.textSecondary(context)),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.brand(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(l10n.loanRepaymentDoneButton),
            ),
          ),
        ],
      ),
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
  String? _localError;
  bool _poppedForSuccess = false;

  @override
  void dispose() {
    _otpController.dispose();
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
            TextField(
              controller: _otpController,
              autofocus: true,
              obscureText: true,
              obscuringCharacter: '●',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                color: HomeColors.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: l10n.loanRepaymentOtpHint,
                errorText: inlineError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) {
                if (_localError != null) {
                  setState(() => _localError = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? AppColors.errorColor
                    : HomeColors.divider(context),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    account == null
                        ? hint
                        : '${account!.title} · ${account!.maskedNumber}',
                    style: TextStyle(
                      color: account == null
                          ? HomeColors.textSecondary(context)
                          : HomeColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
              style: const TextStyle(
                color: AppColors.errorColor,
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