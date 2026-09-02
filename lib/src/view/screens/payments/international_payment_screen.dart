import 'dart:async';

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
import 'package:ubci_bank/src/view/widgets/simple_option_picker_sheet.dart';

/// International (cross-border) payment — functional flow doc §11-§18:
/// Source Account → Beneficiary → Beneficiary Bank → Destination Country →
/// Currency → Amount → Exchange Rate → Charges → Purpose → Review →
/// Authentication → Submit → Processing/Success/Failure → Confirmation.
///
/// Reuses the common components (account picker, beneficiary picker, OTP
/// sheet) established by [InternalPaymentScreen] per §19, adding the
/// destination-country / currency / exchange-rate / charges / purpose
/// fields that are specific to cross-border transfers.
class InternationalPaymentScreen extends ConsumerStatefulWidget {
  const InternationalPaymentScreen({super.key});

  @override
  ConsumerState<InternationalPaymentScreen> createState() =>
      _InternationalPaymentScreenState();
}

class _InternationalPaymentScreenState
    extends ConsumerState<InternationalPaymentScreen> {
  final _amountController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  Timer? _debounce;

  int _step = 0; // 0 = form, 1 = review, 2 = result
  CasaAccount? _sourceAccount;
  TransferBeneficiary? _beneficiary;
  PaymentCountry? _country;
  PaymentCurrency? _currency;
  PaymentPurpose? _purpose;
  double _debouncedAmount = 0;

  String? _accountError;
  String? _beneficiaryError;
  String? _countryError;
  String? _currencyError;
  String? _amountError;
  String? _purposeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(casaAccountsProvider.notifier).ensureLoaded();
    });
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final parsed = double.tryParse(_amountController.text.trim()) ?? 0;
      if (parsed != _debouncedAmount) {
        setState(() => _debouncedAmount = parsed);
      }
    });
  }

  void _showOtpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InternationalOtpSheet(),
    );
  }

  bool _validateForm() {
    var ok = true;
    setState(() {
      _accountError = _sourceAccount == null ? 'Select a source account.' : null;
      _beneficiaryError = _beneficiary == null ? 'Select a beneficiary.' : null;
      _countryError = _country == null ? 'Select a destination country.' : null;
      _currencyError = _currency == null ? 'Select a currency.' : null;
      _purposeError = _purpose == null ? 'Select a purpose.' : null;
      final amount = double.tryParse(_amountController.text.trim());
      _amountError = (amount == null || amount <= 0)
          ? 'Enter a valid amount.'
          : null;
      ok = _accountError == null &&
          _beneficiaryError == null &&
          _countryError == null &&
          _currencyError == null &&
          _amountError == null &&
          _purposeError == null;
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

  InternationalQuoteKey? get _quoteKey {
    final account = _sourceAccount;
    final currency = _currency;
    if (account == null || currency == null || _debouncedAmount <= 0) {
      return null;
    }
    return InternationalQuoteKey(
      sourceCurrency: account.currencyCode,
      targetCurrency: currency.code,
      amount: _debouncedAmount,
    );
  }

  void _confirmAndSubmit(InternationalQuote quote) {
    final account = _sourceAccount;
    final beneficiary = _beneficiary;
    final country = _country;
    final currency = _currency;
    final amount = double.tryParse(_amountController.text.trim());
    if (account == null ||
        beneficiary == null ||
        country == null ||
        currency == null ||
        amount == null) {
      return;
    }

    final request = InternationalPaymentRequest(
      sourceAccount: account,
      beneficiary: beneficiary,
      destinationCountry: country,
      currency: currency,
      amount: amount,
      exchangeRate: quote.rate,
      charges: quote.charges,
      purpose: _purpose,
      additionalInformation: _additionalInfoController.text.trim().isEmpty
          ? null
          : _additionalInfoController.text.trim(),
    );

    ref.read(internationalPaymentSubmissionProvider.notifier).submit(request);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PaymentSubmissionState>(internationalPaymentSubmissionProvider,
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
        title: const Text('International Low Value Payment'),
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
    final beneficiariesAsync = ref.watch(internationalBeneficiariesProvider);
    final countriesAsync = ref.watch(paymentCountriesProvider);
    final currenciesAsync = ref.watch(paymentCurrenciesProvider);
    final purposesAsync = ref.watch(paymentPurposesProvider);

    final accounts = accountsState.summary?.accounts
            .where((a) => a.isActive)
            .toList() ??
        const <CasaAccount>[];

    final key = _quoteKey;
    final quoteAsync =
        key == null ? null : ref.watch(internationalQuoteProvider(key));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Label('From Account'),
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
        const SizedBox(height: 20),
        _Label('Beneficiary'),
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
              if (picked == null) return;
              setState(() {
                _beneficiary = picked;
                _beneficiaryError = null;
              });
            },
          ),
        ),
        if (_beneficiary != null) ...[
          const SizedBox(height: 10),
          _BeneficiaryBankCard(beneficiary: _beneficiary!),
        ],
        const SizedBox(height: 20),
        _Label('Destination Country'),
        const SizedBox(height: 8),
        countriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) =>
              Text('Unable to load countries.', style: TextStyle(color: AppColors.errorColor)),
          data: (countries) => _PickerTile(
            label: _country?.name ?? 'Select country',
            hasValue: _country != null,
            errorText: _countryError,
            onTap: () async {
              final picked = await SimpleOptionPickerSheet.show<PaymentCountry>(
                context,
                title: 'Destination Country',
                options: countries,
                labelBuilder: (c) => c.name,
                selected: _country,
              );
              if (picked == null) return;
              setState(() {
                _country = picked;
                _countryError = null;
              });
            },
          ),
        ),
        const SizedBox(height: 20),
        _Label('Currency'),
        const SizedBox(height: 8),
        currenciesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) =>
              Text('Unable to load currencies.', style: TextStyle(color: AppColors.errorColor)),
          data: (currencies) => _PickerTile(
            label: _currency == null
                ? 'Select currency'
                : '${_currency!.code} — ${_currency!.name}',
            hasValue: _currency != null,
            errorText: _currencyError,
            onTap: () async {
              final picked = await SimpleOptionPickerSheet.show<PaymentCurrency>(
                context,
                title: 'Currency',
                options: currencies,
                labelBuilder: (c) => '${c.code} — ${c.name}',
                selected: _currency,
              );
              if (picked == null) return;
              setState(() {
                _currency = picked;
                _currencyError = null;
              });
            },
          ),
        ),
        const SizedBox(height: 20),
        _Label('Amount to Send'),
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
        if (quoteAsync != null) ...[
          const SizedBox(height: 12),
          quoteAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, _) => Text(
              'Unable to fetch exchange rate.',
              style: TextStyle(color: AppColors.errorColor, fontSize: 12),
            ),
            data: (quote) => _QuoteCard(
              quote: quote,
              sourceCurrency: _sourceAccount?.currencyCode ?? '',
            ),
          ),
        ],
        const SizedBox(height: 20),
        _Label('Purpose of Payment'),
        const SizedBox(height: 8),
        purposesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) =>
              Text('Unable to load purposes.', style: TextStyle(color: AppColors.errorColor)),
          data: (purposes) => _PickerTile(
            label: _purpose?.description ?? 'Select purpose',
            hasValue: _purpose != null,
            errorText: _purposeError,
            onTap: () async {
              final picked = await SimpleOptionPickerSheet.show<PaymentPurpose>(
                context,
                title: 'Purpose of Payment',
                options: purposes,
                labelBuilder: (p) => p.description,
                selected: _purpose,
              );
              if (picked == null) return;
              setState(() {
                _purpose = picked;
                _purposeError = null;
              });
            },
          ),
        ),
        const SizedBox(height: 20),
        _Label('Additional Information (optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _additionalInfoController,
          maxLength: 140,
          maxLines: 2,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: 'Any extra detail for the beneficiary bank',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final key = _quoteKey;
    if (key == null) {
      // Shouldn't happen (form validated before entering review), but
      // fail safe back to the form rather than crash on a null quote.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _step = 0);
      });
      return const SizedBox.shrink();
    }
    final quoteAsync = ref.watch(internationalQuoteProvider(key));

    return quoteAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Unable to fetch exchange rate.', style: TextStyle(color: AppColors.errorColor)),
      ),
      data: (quote) => _buildReviewContent(context, quote),
    );
  }

  Widget _buildReviewContent(BuildContext context, InternationalQuote quote) {
    final submission = ref.watch(internationalPaymentSubmissionProvider);
    final account = _sourceAccount!;
    final beneficiary = _beneficiary!;
    final country = _country!;
    final currency = _currency!;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final total = amount + quote.charges.amount;

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
              _ReviewRow(label: 'Beneficiary', value: beneficiary.nickname),
              if (beneficiary.bankName != null)
                _ReviewRow(label: 'Beneficiary Bank', value: beneficiary.bankName!),
              _ReviewRow(label: 'Destination', value: country.name),
              _ReviewRow(label: 'Currency', value: currency.code),
              _ReviewRow(
                label: 'Amount',
                value: MoneyFormat.format(amount, currencyCode: account.currencyCode),
              ),
              _ReviewRow(
                label: 'Exchange Rate',
                value: '1 ${account.currencyCode} = ${quote.rate.rate.toStringAsFixed(4)} ${currency.code}',
              ),
              _ReviewRow(
                label: 'Equivalent',
                value: MoneyFormat.format(quote.rate.convertedAmount, currencyCode: currency.code),
              ),
              _ReviewRow(
                label: 'Charges',
                value: MoneyFormat.format(quote.charges.amount, currencyCode: account.currencyCode),
              ),
              _ReviewRow(
                label: 'Total Debit',
                value: MoneyFormat.format(total, currencyCode: account.currencyCode),
                emphasize: true,
              ),
              if (_purpose != null)
                _ReviewRow(label: 'Purpose', value: _purpose!.description),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: submission.isSubmitting
                    ? null
                    : () => _confirmAndSubmit(quote),
                style: FilledButton.styleFrom(
                  backgroundColor: HomeColors.brand(context),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: submission.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
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
    final submission = ref.watch(internationalPaymentSubmissionProvider);
    final result = submission.result;
    final status = result?.status;

    final isFailure = status == PaymentStatus.failed;
    final isProcessing = status == PaymentStatus.processing;

    final Color iconBg;
    final Color iconColor;
    final IconData icon;
    final String title;

    if (isFailure) {
      iconBg = AppColors.errorColor.withValues(alpha: 0.1);
      iconColor = AppColors.errorColor;
      icon = Icons.error_rounded;
      title = 'Payment Failed';
    } else if (isProcessing) {
      iconBg = AppColors.warningColor.withValues(alpha: 0.12);
      iconColor = AppColors.warningColor;
      icon = Icons.hourglass_top_rounded;
      title = 'Payment Submitted';
    } else {
      iconBg = AppColors.teal50;
      iconColor = AppColors.successColor;
      icon = Icons.check_circle_rounded;
      title = 'Payment Successful';
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, color: iconColor, size: 52),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
          if (isProcessing) ...[
            const SizedBox(height: 8),
            Text(
              'Your international transfer is being processed and may take 1-3 business days.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HomeColors.textSecondary(context)),
            ),
          ],
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
              'To ${result.beneficiaryName}'
              '${result.destinationCountry != null ? ' · ${result.destinationCountry}' : ''}',
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
              onPressed: () => Navigator.of(context).pop(!isFailure),
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.brand(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isFailure ? 'Try Again' : 'Go to Dashboard'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InternationalOtpSheet extends ConsumerStatefulWidget {
  const _InternationalOtpSheet();

  @override
  ConsumerState<_InternationalOtpSheet> createState() =>
      _InternationalOtpSheetState();
}

class _InternationalOtpSheetState
    extends ConsumerState<_InternationalOtpSheet> {
  bool _poppedForSuccess = false;

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(internationalPaymentSubmissionProvider);

    ref.listen<PaymentSubmissionState>(internationalPaymentSubmissionProvider,
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
      onSubmit: (otp) => ref
          .read(internationalPaymentSubmissionProvider.notifier)
          .verifyOtp(otp),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

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

class _BeneficiaryBankCard extends StatelessWidget {
  const _BeneficiaryBankCard({required this.beneficiary});

  final TransferBeneficiary beneficiary;

  @override
  Widget build(BuildContext context) {
    final rows = <String>[
      if (beneficiary.bankName != null) 'Bank: ${beneficiary.bankName}',
      if (beneficiary.bankCountry != null) 'Country: ${beneficiary.bankCountry}',
      if (beneficiary.swiftCode != null) 'SWIFT/BIC: ${beneficiary.swiftCode}',
      if (beneficiary.iban != null) 'IBAN: ${beneficiary.iban}',
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeColors.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    r,
                    style: TextStyle(
                      fontSize: 12,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.sourceCurrency});

  final InternationalQuote quote;
  final String sourceCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeColors.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1 $sourceCurrency = ${quote.rate.rate.toStringAsFixed(4)} ${quote.rate.targetCurrency}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HomeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Equivalent: ${MoneyFormat.format(quote.rate.convertedAmount, currencyCode: quote.rate.targetCurrency)}',
            style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
          ),
          Text(
            'Charges: ${MoneyFormat.format(quote.charges.amount, currencyCode: quote.charges.currency)}',
            style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
          ),
        ],
      ),
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
          Text(label, style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context))),
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
