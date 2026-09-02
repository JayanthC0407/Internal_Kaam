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
import 'package:ubci_bank/src/view/widgets/payment_otp_sheet_view.dart';
import 'package:ubci_bank/src/view/widgets/settlement_account_picker_sheet.dart';
import 'package:ubci_bank/src/view/widgets/simple_option_picker_sheet.dart';

/// Beneficiary is not chosen from the saved payee list — details are
/// typed in directly, for one of three destinations:
///
/// - **Internal**: same-bank account (settles like Existing Payee).
/// - **Domestic**: another local bank (still settles in local currency).
/// - **International**: cross-border, with destination country,
///   settlement currency, live exchange rate and charges.
///
/// This screen is the actual "international transfer" capability —
/// distinct from the "International Low Value Payment" product reachable
/// from the Transfers module, which is a separate, narrower OBDX product
/// and must not be conflated or relabelled as "International Transfer"
/// anywhere else in the app.
///
/// Internal/Domestic submit through [internalPaymentSubmissionProvider]
/// (same request shape as Existing Payee); International submits through
/// [internationalPaymentSubmissionProvider], reusing the same
/// country/currency/rate/charges machinery as the low-value-payment
/// screen, since the underlying fields are identical even though the
/// product and entry point differ.
enum AdhocBeneficiaryType { internal, domestic, international }

class AdhocPayeeTransferScreen extends ConsumerStatefulWidget {
  const AdhocPayeeTransferScreen({super.key});

  @override
  ConsumerState<AdhocPayeeTransferScreen> createState() =>
      _AdhocPayeeTransferScreenState();
}

class _AdhocPayeeTransferScreenState
    extends ConsumerState<AdhocPayeeTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _beneficiaryNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _routingOrSwiftController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  Timer? _debounce;

  int _step = 0; // 0 = type, 1 = form, 2 = review, 3 = result
  AdhocBeneficiaryType? _type;
  CasaAccount? _sourceAccount;
  PaymentCountry? _country;
  PaymentCurrency? _currency;
  PaymentPurpose? _purpose;
  double _debouncedAmount = 0;

  String? _accountError;
  String? _amountError;
  String? _countryError;
  String? _currencyError;
  String? _purposeError;

  bool get _isInternational => _type == AdhocBeneficiaryType.international;

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
    _beneficiaryNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _bankNameController.dispose();
    _routingOrSwiftController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
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

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required.';
    return null;
  }

  void _selectType(AdhocBeneficiaryType type) {
    HapticFeedback.selectionClick();
    setState(() {
      _type = type;
      _step = 1;
    });
  }

  InternationalQuoteKey? get _quoteKey {
    final account = _sourceAccount;
    final currency = _currency;
    if (!_isInternational || account == null || currency == null || _debouncedAmount <= 0) {
      return null;
    }
    return InternationalQuoteKey(
      sourceCurrency: account.currencyCode,
      targetCurrency: currency.code,
      amount: _debouncedAmount,
    );
  }

  bool _validateForm() {
    final formOk = _formKey.currentState?.validate() ?? false;
    var ok = formOk &&
        _accountNumberController.text.trim() ==
            _confirmAccountNumberController.text.trim();

    setState(() {
      _accountError = _sourceAccount == null ? 'Select a source account.' : null;
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
      if (_isInternational) {
        _countryError = _country == null ? 'Select a destination country.' : null;
        _currencyError = _currency == null ? 'Select a currency.' : null;
        _purposeError = _purpose == null ? 'Select a purpose.' : null;
      } else {
        _countryError = null;
        _currencyError = null;
        _purposeError = null;
      }
      ok = ok &&
          _accountError == null &&
          _amountError == null &&
          _countryError == null &&
          _currencyError == null &&
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
    setState(() => _step = 2);
  }

  TransferBeneficiary get _beneficiary => TransferBeneficiary(
        id: _accountNumberController.text.trim(),
        nickname: _beneficiaryNameController.text.trim(),
        isInternational: _isInternational,
        accountNumber: _accountNumberController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        bankCountry: _isInternational ? _country?.name : null,
        swiftCode: _routingOrSwiftController.text.trim().isEmpty
            ? null
            : _routingOrSwiftController.text.trim(),
        currencyCode: _isInternational ? _currency?.code : null,
      );

  void _showOtpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdhocOtpSheet(isInternational: _isInternational),
    );
  }

  void _confirmAndSubmit(InternationalQuote? quote) {
    final account = _sourceAccount;
    final amount = double.tryParse(_amountController.text.trim());
    if (account == null || amount == null) return;

    if (_isInternational) {
      final currency = _currency;
      final country = _country;
      if (currency == null || country == null || quote == null) return;
      final request = InternationalPaymentRequest(
        sourceAccount: account,
        beneficiary: _beneficiary,
        destinationCountry: country,
        currency: currency,
        amount: amount,
        exchangeRate: quote.rate,
        charges: quote.charges,
        purpose: _purpose,
        additionalInformation: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
      );
      ref.read(internationalPaymentSubmissionProvider.notifier).submit(request);
      return;
    }

    final request = InternalPaymentRequest(
      sourceAccount: account,
      beneficiary: _beneficiary,
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
        (previous, next) => _handleSubmissionUpdate(previous, next));
    ref.listen<PaymentSubmissionState>(internationalPaymentSubmissionProvider,
        (previous, next) => _handleSubmissionUpdate(previous, next));

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: const Text('Adhoc Payee'),
        backgroundColor: HomeColors.bg(context),
        foregroundColor: HomeColors.textPrimary(context),
        elevation: 0,
        automaticallyImplyLeading: _step != 3,
        leading: _step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step = _step - 1),
              ),
      ),
      body: SafeArea(
        child: switch (_step) {
          1 => _buildFormStep(context),
          2 => _buildReviewStep(context),
          3 => _buildResultStep(context),
          _ => _buildTypeStep(context),
        },
      ),
    );
  }

  void _handleSubmissionUpdate(
      PaymentSubmissionState? previous, PaymentSubmissionState next) {
    if (next.result != null && previous?.result != next.result) {
      HapticFeedback.mediumImpact();
      setState(() => _step = 3);
    }
    if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next.errorMessage!)),
      );
    }
    if (next.otpChallenge != null && previous?.otpChallenge == null) {
      HapticFeedback.selectionClick();
      _showOtpSheet(context);
    }
  }

  Widget _buildTypeStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Where is the beneficiary?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HomeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a beneficiary type to enter their details.',
          style: TextStyle(color: HomeColors.textSecondary(context)),
        ),
        const SizedBox(height: 20),
        _TypeCard(
          icon: Icons.account_balance_rounded,
          title: 'Internal',
          subtitle: 'Same-bank beneficiary',
          onTap: () => _selectType(AdhocBeneficiaryType.internal),
        ),
        const SizedBox(height: 12),
        _TypeCard(
          icon: Icons.account_balance_outlined,
          title: 'Domestic',
          subtitle: 'Another local bank',
          onTap: () => _selectType(AdhocBeneficiaryType.domestic),
        ),
        const SizedBox(height: 12),
        _TypeCard(
          icon: Icons.public_rounded,
          title: 'International',
          subtitle: 'Cross-border beneficiary',
          onTap: () => _selectType(AdhocBeneficiaryType.international),
        ),
      ],
    );
  }

  Widget _buildFormStep(BuildContext context) {
    final accountsState = ref.watch(casaAccountsProvider);
    final accounts = accountsState.summary?.accounts
            .where((a) => a.isActive)
            .toList() ??
        const <CasaAccount>[];

    final countriesAsync = _isInternational ? ref.watch(paymentCountriesProvider) : null;
    final currenciesAsync = _isInternational ? ref.watch(paymentCurrenciesProvider) : null;
    final purposesAsync = _isInternational ? ref.watch(paymentPurposesProvider) : null;
    final key = _quoteKey;
    final quoteAsync = key == null ? null : ref.watch(internationalQuoteProvider(key));

    return Form(
      key: _formKey,
      child: ListView(
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
          if (_sourceAccount?.displayBalance != null) ...[
            const SizedBox(height: 6),
            Text(
              'Available: ${MoneyFormat.format(
                _sourceAccount!.displayBalance!.amount,
                currencyCode: _sourceAccount!.displayBalance!.currency ??
                    _sourceAccount!.currencyCode,
              )}',
              style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
            ),
          ],
          const SizedBox(height: 20),
          _Label('Beneficiary Details'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _beneficiaryNameController,
            validator: _required,
            decoration: InputDecoration(
              labelText: 'Beneficiary Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _accountNumberController,
            validator: _required,
            decoration: InputDecoration(
              labelText: _isInternational ? 'Account Number / IBAN' : 'Account Number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmAccountNumberController,
            validator: (value) {
              final required = _required(value);
              if (required != null) return required;
              if (value!.trim() != _accountNumberController.text.trim()) {
                return 'Account numbers do not match.';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: _isInternational ? 'Confirm Account Number / IBAN' : 'Confirm Account Number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bankNameController,
            validator: _type == AdhocBeneficiaryType.internal ? null : _required,
            decoration: InputDecoration(
              labelText: _type == AdhocBeneficiaryType.internal
                  ? 'Bank Name (optional)'
                  : 'Bank Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_type != AdhocBeneficiaryType.internal) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _routingOrSwiftController,
              validator: _isInternational ? _required : null,
              decoration: InputDecoration(
                labelText: _isInternational
                    ? 'SWIFT/BIC Code'
                    : 'Routing/IFSC Code (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          if (_isInternational) ...[
            const SizedBox(height: 20),
            _Label('Destination Country'),
            const SizedBox(height: 8),
            countriesAsync!.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Unable to load countries.', style: TextStyle(color: AppColors.errorColor)),
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
            currenciesAsync!.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Unable to load currencies.', style: TextStyle(color: AppColors.errorColor)),
              data: (currencies) => _PickerTile(
                label: _currency == null ? 'Select currency' : '${_currency!.code} — ${_currency!.name}',
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
          ],
          const SizedBox(height: 20),
          _Label('Amount'),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: _sourceAccount != null ? '${_sourceAccount!.currencyCode}  ' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorText: _amountError,
            ),
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          if (_isInternational && quoteAsync != null) ...[
            const SizedBox(height: 12),
            quoteAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
              error: (err, _) => Text('Unable to fetch exchange rate.', style: TextStyle(color: AppColors.errorColor, fontSize: 12)),
              data: (quote) => _QuoteCard(quote: quote, sourceCurrency: _sourceAccount?.currencyCode ?? ''),
            ),
          ],
          if (_isInternational) ...[
            const SizedBox(height: 20),
            _Label('Purpose of Payment'),
            const SizedBox(height: 8),
            purposesAsync!.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text('Unable to load purposes.', style: TextStyle(color: AppColors.errorColor)),
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
          ],
          const SizedBox(height: 20),
          _Label(_isInternational ? 'Additional Information (optional)' : 'Remarks (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _remarksController,
            maxLength: 140,
            maxLines: 2,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              hintText: _isInternational ? 'Any extra detail for the beneficiary bank' : 'What\'s this for?',
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
      ),
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    if (!_isInternational) {
      return _buildSimpleReview(context);
    }
    final key = _quoteKey;
    if (key == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _step = 1);
      });
      return const SizedBox.shrink();
    }
    final quoteAsync = ref.watch(internationalQuoteProvider(key));
    return quoteAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Unable to fetch exchange rate.', style: TextStyle(color: AppColors.errorColor)),
      ),
      data: (quote) => _buildInternationalReview(context, quote),
    );
  }

  Widget _buildSimpleReview(BuildContext context) {
    final submission = ref.watch(internalPaymentSubmissionProvider);
    final account = _sourceAccount!;
    final beneficiary = _beneficiary;
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
              _ReviewRow(label: 'Beneficiary', value: beneficiary.nickname),
              _ReviewRow(label: 'Account Number', value: beneficiary.maskedAccountNumber),
              if (beneficiary.bankName != null) _ReviewRow(label: 'Bank', value: beneficiary.bankName!),
              if (beneficiary.swiftCode != null) _ReviewRow(label: 'Routing/IFSC Code', value: beneficiary.swiftCode!),
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
        _ReviewActions(
          isSubmitting: submission.isSubmitting,
          onEdit: () => setState(() => _step = 1),
          onConfirm: () => _confirmAndSubmit(null),
        ),
      ],
    );
  }

  Widget _buildInternationalReview(BuildContext context, InternationalQuote quote) {
    final submission = ref.watch(internationalPaymentSubmissionProvider);
    final account = _sourceAccount!;
    final beneficiary = _beneficiary;
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
              if (beneficiary.bankName != null) _ReviewRow(label: 'Beneficiary Bank', value: beneficiary.bankName!),
              if (beneficiary.swiftCode != null) _ReviewRow(label: 'SWIFT/BIC', value: beneficiary.swiftCode!),
              _ReviewRow(label: 'Destination', value: country.name),
              _ReviewRow(label: 'Currency', value: currency.code),
              _ReviewRow(label: 'Amount', value: MoneyFormat.format(amount, currencyCode: account.currencyCode)),
              _ReviewRow(
                label: 'Exchange Rate',
                value: '1 ${account.currencyCode} = ${quote.rate.rate.toStringAsFixed(4)} ${currency.code}',
              ),
              _ReviewRow(
                label: 'Equivalent',
                value: MoneyFormat.format(quote.rate.convertedAmount, currencyCode: currency.code),
              ),
              _ReviewRow(label: 'Charges', value: MoneyFormat.format(quote.charges.amount, currencyCode: account.currencyCode)),
              _ReviewRow(
                label: 'Total Debit',
                value: MoneyFormat.format(total, currencyCode: account.currencyCode),
                emphasize: true,
              ),
              if (_purpose != null) _ReviewRow(label: 'Purpose', value: _purpose!.description),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ReviewActions(
          isSubmitting: submission.isSubmitting,
          onEdit: () => setState(() => _step = 1),
          onConfirm: () => _confirmAndSubmit(quote),
        ),
      ],
    );
  }

  Widget _buildResultStep(BuildContext context) {
    final submission = _isInternational
        ? ref.watch(internationalPaymentSubmissionProvider)
        : ref.watch(internalPaymentSubmissionProvider);
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
          ),
          if (isProcessing) ...[
            const SizedBox(height: 8),
            Text(
              'Your transfer is being processed and may take 1-3 business days.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HomeColors.textSecondary(context)),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            Text(
              MoneyFormat.format(result.amount, currencyCode: result.currency),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: HomeColors.textPrimary(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'To ${result.beneficiaryName}${result.destinationCountry != null ? ' · ${result.destinationCountry}' : ''}',
              style: TextStyle(color: HomeColors.textSecondary(context)),
            ),
            const SizedBox(height: 8),
            Text('Reference: ${result.referenceKey}', style: TextStyle(color: HomeColors.textSecondary(context))),
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

class _AdhocOtpSheet extends ConsumerStatefulWidget {
  const _AdhocOtpSheet({required this.isInternational});

  final bool isInternational;

  @override
  ConsumerState<_AdhocOtpSheet> createState() => _AdhocOtpSheetState();
}

class _AdhocOtpSheetState extends ConsumerState<_AdhocOtpSheet> {
  bool _poppedForSuccess = false;

  @override
  Widget build(BuildContext context) {
    final submission = widget.isInternational
        ? ref.watch(internationalPaymentSubmissionProvider)
        : ref.watch(internalPaymentSubmissionProvider);

    if (widget.isInternational) {
      ref.listen<PaymentSubmissionState>(internationalPaymentSubmissionProvider,
          (previous, next) {
        if (next.result != null && !_poppedForSuccess) {
          _poppedForSuccess = true;
          Navigator.of(context).pop();
        }
      });
    } else {
      ref.listen<PaymentSubmissionState>(internalPaymentSubmissionProvider,
          (previous, next) {
        if (next.result != null && !_poppedForSuccess) {
          _poppedForSuccess = true;
          Navigator.of(context).pop();
        }
      });
    }

    return PaymentOtpSheetView(
      isSubmitting: submission.isSubmitting,
      attemptsLeft: submission.otpChallenge?.attemptsLeft,
      errorText: submission.otpError,
      onSubmit: (otp) {
        if (widget.isInternational) {
          ref.read(internationalPaymentSubmissionProvider.notifier).verifyOtp(otp);
        } else {
          ref.read(internalPaymentSubmissionProvider.notifier).verifyOtp(otp);
        }
      },
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: brand.withValues(alpha: 0.1),
          child: Icon(icon, color: brand),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context))),
        subtitle: Text(subtitle, style: TextStyle(color: HomeColors.textSecondary(context))),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({
    required this.isSubmitting,
    required this.onEdit,
    required this.onConfirm,
  });

  final bool isSubmitting;
  final VoidCallback onEdit;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isSubmitting ? null : onEdit,
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
            onPressed: isSubmitting ? null : onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: HomeColors.brand(context),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Confirm'),
          ),
        ),
      ],
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
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
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
              border: Border.all(color: hasError ? AppColors.errorColor : HomeColors.divider(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: hasValue ? HomeColors.textPrimary(context) : HomeColors.textSecondary(context),
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
            child: Text(errorText!, style: const TextStyle(color: AppColors.errorColor, fontSize: 12)),
          ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value, this.emphasize = false});

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
