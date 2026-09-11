import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/payment/payment_models.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/theme/app_radius.dart';
import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/email_validator.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
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
///
/// Layout follows the "Transfers - Adhoc Payee" UI redesign: a single
/// continuous form (Payment Type → [Network Type] → Payee Details →
/// [Payment Method] → Transfer Details → Schedule Transfer → Pay / Save
/// as Draft / Cancel) that lays fields out one per row on phone and in a
/// two-column grid on wide/web viewports. A handful of fields shown in
/// the new designs (BIC/NCC Verify + Lookup, Save as Draft, Correspondence
/// Charges, Transfer via Intermediary Bank) don't have a backing endpoint
/// in the supplied capture yet, so they're wired as working UI that
/// surfaces a clear "not available yet" message — the same pattern used
/// in [AddBankAccountPayeeScreen] for its Lookup actions.
enum AdhocBeneficiaryType { internal, domestic, international }

class AdhocPayeeTransferScreen extends ConsumerStatefulWidget {
  const AdhocPayeeTransferScreen({super.key});

  @override
  ConsumerState<AdhocPayeeTransferScreen> createState() =>
      _AdhocPayeeTransferScreenState();
}

class _AdhocPayeeTransferScreenState
    extends ConsumerState<AdhocPayeeTransferScreen> {
  static const _wideBreakpoint = 900.0;
  static const _networkTypeOptions = ['RTGS', 'NEFT', 'IMPS'];
  static const _correspondenceChargesOptions = [
    'OUR — Sender pays all charges',
    'SHA — Charges are shared',
    'BEN — Beneficiary pays all charges',
  ];

  final _formKey = GlobalKey<FormState>();
  final _beneficiaryNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _payeeEmailController = TextEditingController();
  final _bankDetailsController = TextEditingController();
  final _routingOrSwiftController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  final _internalNoteController = TextEditingController();
  Timer? _debounce;

  int _step = 0; // 0 = form, 1 = review, 2 = result
  AdhocBeneficiaryType _type = AdhocBeneficiaryType.internal;
  CasaAccount? _sourceAccount;
  PaymentCountry? _country;
  PaymentCurrency? _currency;
  PaymentCurrency? _creditAccountCurrency;
  PaymentPurpose? _purpose;
  double _debouncedAmount = 0;

  String? _networkType;
  String _payVia = 'NCC'; // NCC, BANK_DETAILS, SWIFT
  String _scheduleWhen = 'Now'; // Now, Later
  String _intermediaryBank = 'No'; // Yes, No
  String? _correspondenceCharges;
  bool _chargesFromDebitAccount = false;
  bool _verifyingCode = false;

  String? _accountError;
  String? _amountError;
  String? _currencyError;
  String? _creditCurrencyError;
  String? _purposeError;
  String? _networkTypeError;
  String? _codeError;
  String? _chargesError;

  bool get _isInternational => _type == AdhocBeneficiaryType.international;
  bool get _isDomestic => _type == AdhocBeneficiaryType.domestic;

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
    _payeeEmailController.dispose();
    _bankDetailsController.dispose();
    _routingOrSwiftController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    _internalNoteController.dispose();
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
    if (type == _type) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = type;
      _networkType = null;
      _networkTypeError = null;
      _codeError = null;
      _payVia = 'NCC';
      _routingOrSwiftController.clear();
      _bankDetailsController.clear();
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

  String get _payViaCode => switch (_payVia) {
        'BANK_DETAILS' => _bankDetailsController.text.trim(),
        _ => _routingOrSwiftController.text.trim(),
      };

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
      _currencyError = _currency == null ? 'Select a currency.' : null;
      _creditCurrencyError =
          _creditAccountCurrency == null ? 'Select a currency.' : null;

      _networkTypeError =
          _isDomestic && _networkType == null ? 'Select a network type.' : null;

      if (_isInternational) {
        _purposeError = _purpose == null ? 'Select a purpose.' : null;
        _codeError = _payViaCode.isEmpty ? 'Required.' : null;
      } else {
        _purposeError = null;
        _codeError = null;
      }

      _chargesError = !_isInternational && !_chargesFromDebitAccount
          ? 'Please confirm how charges are debited.'
          : null;

      ok = ok &&
          _accountError == null &&
          _amountError == null &&
          _currencyError == null &&
          _creditCurrencyError == null &&
          _networkTypeError == null &&
          _purposeError == null &&
          _codeError == null &&
          _chargesError == null;
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

  void _saveAsDraft() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Save as Draft is not available yet.')),
    );
  }

  Future<void> _verifyCode() async {
    final code = _payViaCode;
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isDomestic ? 'Enter a BIC code first.' : 'Enter a code first.'),
        ),
      );
      return;
    }
    setState(() => _verifyingCode = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _verifyingCode = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code verification is not available yet.')),
    );
  }

  void _showLookup(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label lookup is not available yet.')),
    );
  }

  TransferBeneficiary get _beneficiary => TransferBeneficiary(
        id: _accountNumberController.text.trim(),
        nickname: _beneficiaryNameController.text.trim(),
        isInternational: _isInternational,
        accountNumber: _accountNumberController.text.trim(),
        bankName: _payVia == 'BANK_DETAILS' && _bankDetailsController.text.trim().isNotEmpty
            ? _bankDetailsController.text.trim()
            : null,
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
      if (currency == null || quote == null) return;
      final request = InternationalPaymentRequest(
        sourceAccount: account,
        beneficiary: _beneficiary,
        destinationCountry: country ??
            PaymentCountry(
              code: currency.code,
              name: currency.name,
              defaultCurrencyCode: currency.code,
            ),
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
      currency: _currency?.code ?? account.currencyCode,
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
        title: const Text('Transfers - Adhoc Payee'),
        backgroundColor: HomeColors.bg(context),
        foregroundColor: HomeColors.textPrimary(context),
        elevation: 0,
        automaticallyImplyLeading: _step != 2,
        leading: _step == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step = _step - 1),
              ),
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

  void _handleSubmissionUpdate(
      PaymentSubmissionState? previous, PaymentSubmissionState next) {
    if (next.result != null && previous?.result != next.result) {
      HapticFeedback.mediumImpact();
      setState(() => _step = 2);
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

  // ---------------------------------------------------------------------
  // Form step
  // ---------------------------------------------------------------------

  Widget _buildFormStep(BuildContext context) {
    final accountsState = ref.watch(casaAccountsProvider);
    final accounts = accountsState.summary?.accounts
            .where((a) => a.isActive)
            .toList() ??
        const <CasaAccount>[];

    final currenciesAsync = ref.watch(paymentCurrenciesProvider);
    final purposesAsync = _isInternational ? ref.watch(paymentPurposesProvider) : null;
    final key = _quoteKey;
    final quoteAsync = key == null ? null : ref.watch(internationalQuoteProvider(key));

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final responsive = Responsive.of(context);

        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              responsive.isPhone ? AppSpacing.lg : AppSpacing.xxxl,
              AppSpacing.lg,
              responsive.isPhone ? AppSpacing.lg : AppSpacing.xxxl,
              AppSpacing.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Container(
                  padding: EdgeInsets.all(wide ? AppSpacing.xxl : AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: HomeColors.card(context),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: HomeColors.divider(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionHeader(
                        icon: Icons.credit_card_rounded,
                        label: 'Payment Type',
                        required: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildPaymentTypeTabs(context),

                      if (_isDomestic) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          icon: Icons.wifi_tethering_rounded,
                          label: 'Network Type',
                          required: true,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _dropdown<String>(
                          label: 'Network Type',
                          value: _networkType,
                          items: _networkTypeOptions,
                          itemLabel: (e) => e,
                          errorText: _networkTypeError,
                          onChanged: (value) => setState(() {
                            _networkType = value;
                            _networkTypeError = null;
                          }),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),
                      _SectionHeader(
                        icon: Icons.badge_rounded,
                        label: 'Payee Details',
                        required: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _fieldRow(
                        wide,
                        TextFormField(
                          controller: _accountNumberController,
                          validator: _required,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Account Number *'),
                        ),
                        TextFormField(
                          controller: _confirmAccountNumberController,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final required = _required(value);
                            if (required != null) return required;
                            if (value!.trim() != _accountNumberController.text.trim()) {
                              return 'Account numbers do not match.';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(labelText: 'Confirm Account Number *'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _fieldRow(
                        wide,
                        TextFormField(
                          controller: _beneficiaryNameController,
                          validator: _required,
                          decoration: const InputDecoration(labelText: 'Account Name *'),
                        ),
                        TextFormField(
                          controller: _payeeEmailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final required = _required(value);
                            if (required != null) return required;
                            if (!EmailValidator.isValid(value!.trim())) {
                              return 'Enter a valid email.';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(labelText: 'Payee Email Id *'),
                        ),
                      ),

                      if (_isDomestic) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _codeWithVerifyRow(label: 'BIC Code', required: false),
                        const SizedBox(height: AppSpacing.xs),
                        _lookupLink('BIC Code'),
                      ],

                      if (_isInternational) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          icon: Icons.compare_arrows_rounded,
                          label: 'Payment Method',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _fieldRow(
                          wide,
                          _payViaColumn(context),
                          _payViaCodeColumn(context),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),
                      _SectionHeader(
                        icon: Icons.sync_alt_rounded,
                        label: 'Transfer Details',
                        required: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _fieldRow(
                        wide,
                        _dropdown<PaymentCurrency>(
                          label: 'Credit Account Currency *',
                          value: _creditAccountCurrency,
                          items: currenciesAsync.value ?? const [],
                          itemLabel: (c) => '${c.code} — ${c.name}',
                          errorText: _creditCurrencyError,
                          loading: currenciesAsync.isLoading,
                          onChanged: (value) => setState(() {
                            _creditAccountCurrency = value;
                            _creditCurrencyError = null;
                          }),
                        ),
                        _dropdown<PaymentCurrency>(
                          label: 'Currency *',
                          value: _currency,
                          items: currenciesAsync.value ?? const [],
                          itemLabel: (c) => '${c.code} — ${c.name}',
                          errorText: _currencyError,
                          loading: currenciesAsync.isLoading,
                          onChanged: (value) => setState(() {
                            _currency = value;
                            _currencyError = null;
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _fieldRow(
                        wide,
                        Builder(builder: (context) {
                          if (accountsState.isLoading) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PickerTile(
                                label: _sourceAccount == null
                                    ? 'Transfer From *'
                                    : '${_sourceAccount!.title} · ${_sourceAccount!.maskedNumber}',
                                hasValue: _sourceAccount != null,
                                errorText: _accountError,
                                onTap: () async {
                                  if (accounts.isEmpty) return;
                                  final picked = await SettlementAccountPickerSheet.show(
                                    context,
                                    title: 'Transfer From',
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
                                  'Balance: ${MoneyFormat.format(
                                    _sourceAccount!.displayBalance!.amount,
                                    currencyCode: _sourceAccount!.displayBalance!.currency ??
                                        _sourceAccount!.currencyCode,
                                  )}',
                                  style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
                                ),
                              ],
                            ],
                          );
                        }),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Transfer Amount *',
                            errorText: _amountError,
                          ),
                          onChanged: (_) {
                            if (_amountError != null) setState(() => _amountError = null);
                          },
                        ),
                      ),
                      if (_isInternational && quoteAsync != null) ...[
                        const SizedBox(height: AppSpacing.md),
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

                      const SizedBox(height: AppSpacing.xl),
                      _SectionHeader(
                        icon: Icons.schedule_rounded,
                        label: 'Schedule Transfer',
                        required: !_isInternational,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_isInternational) ...[
                        Text('When *', style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context))),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      _scheduleRadioRow(context),

                      if (_isInternational) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _dropdown<String>(
                          label: 'Correspondence Charges',
                          value: _correspondenceCharges,
                          items: _correspondenceChargesOptions,
                          itemLabel: (e) => e,
                          onChanged: (value) => setState(() => _correspondenceCharges = value),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Transfer via Intermediary Bank',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.xs),
                        _intermediaryBankRadioRow(context),
                        const SizedBox(height: AppSpacing.lg),
                        purposesAsync!.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (err, _) => Text('Unable to load purposes.', style: TextStyle(color: AppColors.errorColor)),
                          data: (purposes) => _PickerTile(
                            label: _purpose?.description ?? 'Purpose *',
                            hasValue: _purpose != null,
                            errorText: _purposeError,
                            onTap: () async {
                              final picked = await SimpleOptionPickerSheet.show<PaymentPurpose>(
                                context,
                                title: 'Purpose',
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

                      const SizedBox(height: AppSpacing.lg),
                      _chargesCheckbox(context),

                      const SizedBox(height: AppSpacing.lg),
                      if (_isInternational)
                        _fieldRow(
                          wide,
                          TextField(
                            controller: _remarksController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Remittance Information',
                              alignLabelWithHint: true,
                              hintText: 'Enter note',
                            ),
                          ),
                          TextField(
                            controller: _internalNoteController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Internal Note',
                              alignLabelWithHint: true,
                              hintText: 'Enter note',
                            ),
                          ),
                        )
                      else ...[
                        Text('Note', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.xs),
                        TextField(
                          controller: _remarksController,
                          maxLength: 140,
                          maxLines: 3,
                          decoration: const InputDecoration(hintText: 'Enter note'),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),
                      _buildActions(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentTypeTabs(BuildContext context) {
    final brand = HomeColors.brand(context);
    final divider = HomeColors.divider(context);
    const entries = [
      (AdhocBeneficiaryType.internal, 'Internal'),
      (AdhocBeneficiaryType.domestic, 'Domestic'),
      (AdhocBeneficiaryType.international, 'International'),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in entries)
          _PaymentTypeChip(
            label: entry.$2,
            selected: _type == entry.$1,
            onTap: () => _selectType(entry.$1),
            brand: brand,
            divider: divider,
          ),
      ],
    );
  }

  Widget _codeWithVerifyRow({required String label, required bool required}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _routingOrSwiftController,
            textCapitalization: TextCapitalization.characters,
            validator: required ? _required : null,
            decoration: InputDecoration(labelText: required ? '$label *' : label),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(
            onPressed: _verifyingCode ? null : _verifyCode,
            child: _verifyingCode
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify'),
          ),
        ),
      ],
    );
  }

  Widget _lookupLink(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => _showLookup(label),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Text('Lookup $label'),
      ),
    );
  }

  Widget _payViaColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pay Via *', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            _radioOption(label: 'NCC', value: 'NCC', groupValue: _payVia, onChanged: _onPayViaChanged),
            _radioOption(label: 'Bank Details', value: 'BANK_DETAILS', groupValue: _payVia, onChanged: _onPayViaChanged),
            _radioOption(label: 'Swift Code', value: 'SWIFT', groupValue: _payVia, onChanged: _onPayViaChanged),
          ],
        ),
      ],
    );
  }

  void _onPayViaChanged(String? value) {
    if (value == null) return;
    setState(() {
      _payVia = value;
      _codeError = null;
    });
  }

  Widget _payViaCodeColumn(BuildContext context) {
    if (_payVia == 'BANK_DETAILS') {
      return TextFormField(
        controller: _bankDetailsController,
        validator: (value) => _required(value),
        decoration: const InputDecoration(labelText: 'Bank Details *'),
      );
    }
    final label = _payVia == 'SWIFT' ? 'Swift Code' : 'National Clearing Code';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _codeWithVerifyRow(label: label, required: true),
        if (_codeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_codeError!, style: const TextStyle(color: AppColors.errorColor, fontSize: 12)),
          ),
        const SizedBox(height: AppSpacing.xs),
        _lookupLink(label),
      ],
    );
  }

  Widget _scheduleRadioRow(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        _radioOption(
          label: 'Now',
          value: 'Now',
          groupValue: _scheduleWhen,
          onChanged: (value) => setState(() => _scheduleWhen = value!),
        ),
        _radioOption(
          label: 'Later',
          value: 'Later',
          groupValue: _scheduleWhen,
          onChanged: (value) => setState(() => _scheduleWhen = value!),
        ),
      ],
    );
  }

  Widget _intermediaryBankRadioRow(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        _radioOption(
          label: 'Yes',
          value: 'Yes',
          groupValue: _intermediaryBank,
          onChanged: (value) => setState(() => _intermediaryBank = value!),
        ),
        _radioOption(
          label: 'No',
          value: 'No',
          groupValue: _intermediaryBank,
          onChanged: (value) => setState(() => _intermediaryBank = value!),
        ),
      ],
    );
  }

  Widget _radioOption({
    required String label,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _chargesCheckbox(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            _chargesFromDebitAccount = !_chargesFromDebitAccount;
            _chargesError = null;
          }),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Row(
            children: [
              Checkbox(
                value: _chargesFromDebitAccount,
                onChanged: (value) => setState(() {
                  _chargesFromDebitAccount = value ?? false;
                  _chargesError = null;
                }),
              ),
              Expanded(
                child: Text(
                  _isInternational
                      ? 'Charges to be debited from Debit Account'
                      : 'Charges to be debited from Debit Account *',
                ),
              ),
            ],
          ),
        ),
        if (_chargesError != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Text(_chargesError!, style: const TextStyle(color: AppColors.errorColor, fontSize: 12)),
          ),
      ],
    );
  }

  /// Lays [a] and [b] side by side on wide layouts, stacked on phone.
  Widget _fieldRow(bool wide, Widget a, Widget? b) {
    if (!wide || b == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          a,
          if (b != null) ...[const SizedBox(height: AppSpacing.lg), b],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: b),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    String? errorText,
    bool loading = false,
  }) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return DropdownButtonFormField<T>(
      value: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      items: items
          .map((item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))))
          .toList(),
      onChanged: items.isEmpty ? null : onChanged,
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        FilledButton(
          onPressed: _continueToReview,
          style: FilledButton.styleFrom(
            backgroundColor: HomeColors.brand(context),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          child: const Text('Pay'),
        ),
        OutlinedButton(
          onPressed: _saveAsDraft,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          child: const Text('Save as Draft'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Review step
  // ---------------------------------------------------------------------

  Widget _buildReviewStep(BuildContext context) {
    if (!_isInternational) {
      return _buildSimpleReview(context);
    }
    final key = _quoteKey;
    if (key == null) {
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
              _ReviewRow(label: 'Payment Type', value: _isDomestic ? 'Domestic' : 'Internal'),
              if (_isDomestic && _networkType != null)
                _ReviewRow(label: 'Network Type', value: _networkType!),
              _ReviewRow(label: 'From Account', value: '${account.title} · ${account.maskedNumber}'),
              _ReviewRow(label: 'Account Name', value: beneficiary.nickname),
              _ReviewRow(label: 'Account Number', value: beneficiary.maskedAccountNumber),
              if (_payeeEmailController.text.trim().isNotEmpty)
                _ReviewRow(label: 'Payee Email Id', value: _payeeEmailController.text.trim()),
              if (beneficiary.swiftCode != null) _ReviewRow(label: 'BIC Code', value: beneficiary.swiftCode!),
              _ReviewRow(
                label: 'Amount',
                value: MoneyFormat.format(amount, currencyCode: _currency?.code ?? account.currencyCode),
                emphasize: true,
              ),
              _ReviewRow(label: 'Schedule', value: _scheduleWhen),
              if (_remarksController.text.trim().isNotEmpty)
                _ReviewRow(label: 'Note', value: _remarksController.text.trim()),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ReviewActions(
          isSubmitting: submission.isSubmitting,
          onEdit: () => setState(() => _step = 0),
          onConfirm: () => _confirmAndSubmit(null),
        ),
      ],
    );
  }

  Widget _buildInternationalReview(BuildContext context, InternationalQuote quote) {
    final submission = ref.watch(internationalPaymentSubmissionProvider);
    final account = _sourceAccount!;
    final beneficiary = _beneficiary;
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
              _ReviewRow(label: 'Account Name', value: beneficiary.nickname),
              if (_payeeEmailController.text.trim().isNotEmpty)
                _ReviewRow(label: 'Payee Email Id', value: _payeeEmailController.text.trim()),
              _ReviewRow(label: 'Pay Via', value: _payVia == 'BANK_DETAILS' ? 'Bank Details' : (_payVia == 'SWIFT' ? 'Swift Code' : 'NCC')),
              if (beneficiary.swiftCode != null) _ReviewRow(label: 'Code', value: beneficiary.swiftCode!),
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
              _ReviewRow(label: 'Schedule', value: _scheduleWhen),
              _ReviewRow(label: 'Intermediary Bank', value: _intermediaryBank),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ReviewActions(
          isSubmitting: submission.isSubmitting,
          onEdit: () => setState(() => _step = 0),
          onConfirm: () => _confirmAndSubmit(quote),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Result step
  // ---------------------------------------------------------------------

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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label, this.required = false});

  final IconData icon;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: brand),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
        ),
        if (required)
          const Text(' *', style: TextStyle(color: AppColors.errorColor, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PaymentTypeChip extends StatelessWidget {
  const _PaymentTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.brand,
    required this.divider,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color brand;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? brand : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: selected ? brand : divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : HomeColors.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
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