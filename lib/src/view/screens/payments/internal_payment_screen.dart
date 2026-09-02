import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/payment/payment_models.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/providers/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/payment_providers.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/beneficiary_picker_sheet.dart';
import 'package:ubci_bank/src/view/widgets/payment_otp_sheet_view.dart';
import 'package:ubci_bank/src/view/widgets/settlement_account_picker_sheet.dart';

/// Internal (same-bank) payment — the functional flow doc's Phase 1
/// (§21): Source Account → Beneficiary → Amount + Details → Review →
/// Authentication → Submit → Success/Failure → Confirmation.
///
/// Follows the same single-screen, indexed-step convention as
/// [LoanRepaymentScreen] rather than a route per step.
class InternalPaymentScreen extends ConsumerStatefulWidget {
  const InternalPaymentScreen({super.key});

  @override
  ConsumerState<InternalPaymentScreen> createState() =>
      _InternalPaymentScreenState();
}

class _InternalPaymentScreenState
    extends ConsumerState<InternalPaymentScreen> {
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();

  int _step = 0; // 0 = form, 1 = review, 2 = result
  CasaAccount? _sourceAccount;
  TransferBeneficiary? _beneficiary;
  String? _accountError;
  String? _beneficiaryError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _showOtpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InternalOtpSheet(),
    );
  }

  bool _validateForm() {
    var ok = true;
    setState(() {
      _accountError = _sourceAccount == null ? 'Select a source account.' : null;
      _beneficiaryError = _beneficiary == null ? 'Select a beneficiary.' : null;
      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        _amountError = 'Enter a valid amount.';
      } else if (_sourceAccount != null &&
          _sourceAccount!.availableBalance != null &&
          amount > _sourceAccount!.availableBalance!.amount) {
        _amountError = 'Amount exceeds available balance.';
      } else {
        _amountError = null;
      }
      ok = _accountError == null &&
          _beneficiaryError == null &&
          _amountError == null;
    });
    return ok;
  }

  void _continueToReview() {
    if (!_validateForm()) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _step = 1);
  }

  void _confirmAndSubmit() {
    final account = _sourceAccount;
    final beneficiary = _beneficiary;
    final amount = double.tryParse(_amountController.text.trim());
    if (account == null || beneficiary == null || amount == null) return;

    final request = InternalPaymentRequest(
      sourceAccount: account,
      beneficiary: beneficiary,
      amount: amount,
      currency: account.currencyCode,
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
    );

    ref.read(internalPaymentSubmissionProvider.notifier).submit(request);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PaymentSubmissionState>(internalPaymentSubmissionProvider,
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
      if (next.otpChallenge != null && previous?.otpChallenge == null) {
        HapticFeedback.selectionClick();
        _showOtpSheet(context);
      }
    });

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: const Text('Internal Transfer'),
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
          1 => _buildReviewStep(context),
          2 => _buildResultStep(context),
          _ => _buildFormStep(context),
        },
      ),
    );
  }

  Widget _buildFormStep(BuildContext context) {
    final accountsState = ref.watch(casaAccountsProvider);
    final beneficiariesAsync = ref.watch(internalBeneficiariesProvider);

    final accounts = accountsState.summary?.accounts
            .where((a) => a.isActive)
            .toList() ??
        const <CasaAccount>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'From Account',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HomeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        if (accountsState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _PickerTile(
            label: _sourceAccount == null
                ? 'Select source account'
                : '${_sourceAccount!.title} · ${_sourceAccount!.maskedNumber}',
            hasValue: _sourceAccount != null,
            errorText: _accountError,
            onTap: () async {
              if (accounts.isEmpty) return;
              final picked = await SettlementAccountPickerSheet.show(
                context,
                title: 'From Account',
                accounts: accounts,
                selected: _sourceAccount,
              );
              if (picked != null) {
                setState(() {
                  _sourceAccount = picked;
                  _accountError = null;
                });
              }
            },
          ),
        if (_sourceAccount?.displayBalance != null) ...[
          const SizedBox(height: 6),
          Text(
            'Available: ${MoneyFormat.format(
              _sourceAccount!.displayBalance!.amount,
              currencyCode: _sourceAccount!.displayBalance!.currency ??
                  _sourceAccount!.currencyCode,
            )}',
            style: TextStyle(
              fontSize: 12,
              color: HomeColors.textSecondary(context),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Beneficiary',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HomeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        beneficiariesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text(
            'Unable to load beneficiaries.',
            style: TextStyle(color: AppColors.errorColor),
          ),
          data: (beneficiaries) => _PickerTile(
            label: _beneficiary?.nickname ?? 'Select beneficiary',
            hasValue: _beneficiary != null,
            errorText: _beneficiaryError,
            onTap: () async {
              final picked = await BeneficiaryPickerSheet.show(
                context,
                title: 'Select Beneficiary',
                beneficiaries: beneficiaries,
                selected: _beneficiary,
              );
              if (picked != null) {
                setState(() {
                  _beneficiary = picked;
                  _beneficiaryError = null;
                });
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Amount',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HomeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: _sourceAccount != null
                ? '${_sourceAccount!.currencyCode}  '
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: _amountError,
          ),
          onChanged: (_) {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Remarks (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HomeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _remarksController,
          maxLength: 140,
          maxLines: 2,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: 'What\'s this for?',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _continueToReview,
            style: FilledButton.styleFrom(
              backgroundColor: HomeColors.brand(context),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final submission = ref.watch(internalPaymentSubmissionProvider);
    final account = _sourceAccount!;
    final beneficiary = _beneficiary!;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            children: [
              _ReviewRow(label: 'From Account', value: '${account.title} · ${account.maskedNumber}'),
              _ReviewRow(label: 'Beneficiary', value: '${beneficiary.nickname} · ${beneficiary.maskedAccountNumber}'),
              _ReviewRow(
                label: 'Amount',
                value: MoneyFormat.format(amount, currencyCode: account.currencyCode),
                emphasize: true,
              ),
              if (_remarksController.text.trim().isNotEmpty)
                _ReviewRow(label: 'Remarks', value: _remarksController.text.trim()),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: submission.isSubmitting
                    ? null
                    : () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: submission.isSubmitting ? null : _confirmAndSubmit,
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
                    : const Text('Confirm'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultStep(BuildContext context) {
    final submission = ref.watch(internalPaymentSubmissionProvider);
    final result = submission.result;
    final isSuccess = result?.status == PaymentStatus.success;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSuccess ? AppColors.teal50 : AppColors.errorColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: isSuccess ? AppColors.successColor : AppColors.errorColor,
              size: 52,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSuccess ? 'Payment Successful' : 'Payment Failed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            Text(
              MoneyFormat.format(result.amount, currencyCode: result.currency),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To ${result.beneficiaryName}',
              style: TextStyle(color: HomeColors.textSecondary(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'Reference: ${result.referenceKey}',
              style: TextStyle(color: HomeColors.textSecondary(context)),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(isSuccess),
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.brand(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isSuccess ? 'Go to Dashboard' : 'Try Again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InternalOtpSheet extends ConsumerStatefulWidget {
  const _InternalOtpSheet();

  @override
  ConsumerState<_InternalOtpSheet> createState() => _InternalOtpSheetState();
}

class _InternalOtpSheetState extends ConsumerState<_InternalOtpSheet> {
  bool _poppedForSuccess = false;

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(internalPaymentSubmissionProvider);

    ref.listen<PaymentSubmissionState>(internalPaymentSubmissionProvider,
        (previous, next) {
      if (next.result != null && !_poppedForSuccess) {
        _poppedForSuccess = true;
        Navigator.of(context).pop();
      }
    });

    return PaymentOtpSheetView(
      isSubmitting: submission.isSubmitting,
      attemptsLeft: submission.otpChallenge?.attemptsLeft,
      errorText: submission.otpError,
      onSubmit: (otp) =>
          ref.read(internalPaymentSubmissionProvider.notifier).verifyOtp(otp),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.hasValue,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final bool hasValue;
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
                color: hasError ? AppColors.errorColor : HomeColors.divider(context),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: hasValue
                          ? HomeColors.textPrimary(context)
                          : HomeColors.textSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.expand_more_rounded, color: HomeColors.textSecondary(context)),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(color: AppColors.errorColor, fontSize: 12),
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
            style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
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
