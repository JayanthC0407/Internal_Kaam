import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/own_account_transfer.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/view/providers/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/transfer_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/transfer/transfer_theme.dart';
import 'package:ubci_bank/src/view/screens/transfer/widgets/transfer_account_widgets.dart';
import 'package:ubci_bank/src/view/screens/transfer/widgets/transfer_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/transfer/widgets/transfer_web_widgets.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_challenge_body.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

class OwnAccountTransferScreen extends ConsumerStatefulWidget {
  const OwnAccountTransferScreen({
    super.key,
    this.embedded = false,
    this.onClose,
  });

  /// When true, omits outer [Scaffold] app bar (used inside dashboard tab).
  final bool embedded;

  /// Called when leaving the first wizard step while [embedded] in Home.
  /// Must switch to the Home tab — do not pop, or login is revealed.
  final VoidCallback? onClose;

  @override
  ConsumerState<OwnAccountTransferScreen> createState() =>
      _OwnAccountTransferScreenState();
}

class _OwnAccountTransferScreenState
    extends ConsumerState<OwnAccountTransferScreen> {
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  final _stationaryController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _myAccountsSelected = true;
  TransferConfirmationSnapshot? _successSnapshot;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_syncNote);
    _amountController.addListener(_syncAmount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ownAccountTransferProvider.notifier).initialize();
    });
  }

  void _syncNote() {
    ref.read(ownAccountTransferProvider.notifier).setNote(_noteController.text);
  }

  void _syncAmount() {
    ref
        .read(ownAccountTransferProvider.notifier)
        .setAmountText(_amountController.text);
  }

  @override
  void dispose() {
    _noteController.removeListener(_syncNote);
    _amountController.removeListener(_syncAmount);
    _noteController.dispose();
    _amountController.dispose();
    _stationaryController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  List<CasaAccount> get _accounts {
    final eligible = ref.read(ownAccountTransferProvider).eligibleAccounts;
    if (eligible.isNotEmpty) return eligible;
    return ref.read(casaAccountsProvider).summary?.accounts ?? const [];
  }

  bool get _isOption2 =>
      kTransferDesignVariant == TransferDesignVariant.option2;

  String _accountDropdownLabel(CasaAccount account) {
    final mask = kIsWeb
        ? TransferTheme.webMask(account.displayNumber)
        : TransferTheme.maskLastFour(account.displayNumber);
    return '${TransferTheme.compactTitle(account.title)}  $mask';
  }

  List<String> _currencyCodes(OwnAccountTransferState state) {
    final seen = <String>{};
    final codes = <String>[];
    void add(String? raw) {
      final code = raw?.trim() ?? '';
      if (code.isEmpty || !seen.add(code)) return;
      codes.add(code);
    }

    for (final currency in state.currencies) {
      add(currency.code);
    }
    add(state.transferCurrency);
    add(state.creditCurrency);
    add(state.debitAccount?.currencyCode);
    add(state.creditAccount?.currencyCode);
    return codes;
  }

  Future<void> _pickAccount({
    required bool debit,
    required CasaAccount? selected,
    required List<CasaAccount> options,
  }) async {
    if (options.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final picked = await TransferAccountPicker.show(
      context: context,
      title: debit ? l10n.selectDebitAccount : l10n.selectCreditAccount,
      accounts: options,
      selected: selected,
    );
    if (picked == null || !mounted) return;
    if (debit) {
      ref.read(ownAccountTransferProvider.notifier).selectDebitAccount(picked);
    } else {
      ref.read(ownAccountTransferProvider.notifier).selectCreditAccount(picked);
    }
  }

  void _showComingSoon({bool limits = false}) {
    final l10n = AppLocalizations.of(context);
    _showError(
      limits ? l10n.transferLimitsComingSoon : l10n.featureComingSoon,
    );
  }

  Future<void> _onPrimary(OwnAccountTransferState state) async {
    final notifier = ref.read(ownAccountTransferProvider.notifier);

    if (state.step == 0) {
      final error = await notifier.validateStepAccounts();
      if (error != null) {
        _showError(error);
        return;
      }
      notifier.setStep(1);
      return;
    }

    if (state.step == 1) {
      final amountError = await notifier.validateStepAmount();
      if (amountError != null) {
        _showError(amountError);
        return;
      }
      final ok = await notifier.prepareReview();
      if (!ok && mounted) {
        final msg = ref.read(ownAccountTransferProvider).errorMessage;
        if (msg != null) _showError(msg);
      }
      return;
    }

    final result = await notifier.submit();
    if (!mounted) return;
    await _handleSubmitResult(result);
  }

  Future<void> _onSubmitWeb(OwnAccountTransferState state) async {
    final notifier = ref.read(ownAccountTransferProvider.notifier);
    if (state.step >= 2) {
      final result = await notifier.submit();
      if (!mounted) return;
      await _handleSubmitResult(result);
      return;
    }
    final accountError = await notifier.validateStepAccounts();
    if (accountError != null) {
      _showError(accountError);
      return;
    }
    final amountError = await notifier.validateStepAmount();
    if (amountError != null) {
      _showError(amountError);
      return;
    }
    final ok = await notifier.prepareReview();
    if (!ok && mounted) {
      final msg = ref.read(ownAccountTransferProvider).errorMessage;
      if (msg != null) _showError(msg);
    }
  }

  void _onWebBack(OwnAccountTransferState state) {
    if (state.requiresOtp) {
      _otpController.clear();
      ref.read(ownAccountTransferProvider.notifier).clearOtpChallenge();
      return;
    }
    if (state.step >= 2) {
      ref.read(ownAccountTransferProvider.notifier).setStep(0);
      return;
    }
    _leaveTransfer();
  }

  Future<void> _submitOtp() async {
    final l10n = AppLocalizations.of(context);
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showError(l10n.otpEnterCode);
      return;
    }
    final result =
        await ref.read(ownAccountTransferProvider.notifier).submit(otp: otp);
    if (!mounted) return;
    if (result == null) {
      _otpController.clear();
      _otpFocusNode.requestFocus();
    }
    await _handleSubmitResult(result);
  }

  Future<void> _resendOtp() async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref.read(ownAccountTransferProvider.notifier).resendOtp();
    if (!mounted) return;
    _otpController.clear();
    _otpFocusNode.requestFocus();
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.otpResendSuccess)),
      );
    } else {
      final msg = ref.read(ownAccountTransferProvider).errorMessage;
      if (msg != null) _showError(msg);
    }
  }

  Future<void> _handleSubmitResult(TransferSubmitResult? result) async {
    if (result != null && result.referenceNumber.isNotEmpty) {
      await _goSuccess(result);
      return;
    }
    final state = ref.read(ownAccountTransferProvider);
    if (state.requiresOtp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocusNode.requestFocus();
      });
      return;
    }
    if (state.errorMessage != null) {
      _showError(state.errorMessage!);
    }
  }

  Future<void> _goSuccess(TransferSubmitResult result) async {
    final snapshot = _confirmationSnapshot(result);
    _noteController.clear();
    _amountController.clear();
    _stationaryController.clear();
    _otpController.clear();
    if (!mounted) return;

    // Fire-and-forget so the success screen is not delayed by reloads.
    ref.read(ownAccountTransferProvider.notifier).resetAfterSuccess();
    ref.read(casaAccountsProvider.notifier).refresh();

    if (kIsWeb) {
      setState(() => _successSnapshot = snapshot);
      return;
    }

    // Push on top of home (embedded tab). Never replace — that uncovered the
    // leftover initial splash route and left the app stuck there.
    await Navigator.of(context).pushNamed(
      RoutesConst.transferSuccessScreen,
      arguments: snapshot,
    );
  }

  void _startNewTransfer() {
    setState(() => _successSnapshot = null);
  }

  void _finishSuccess() {
    setState(() => _successSnapshot = null);
    _leaveTransfer();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onWizardBack(OwnAccountTransferState state) {
    if (state.requiresOtp) {
      _otpController.clear();
      ref.read(ownAccountTransferProvider.notifier).clearOtpChallenge();
      return;
    }
    if (state.step > 0) {
      ref.read(ownAccountTransferProvider.notifier).setStep(state.step - 1);
      return;
    }
    _leaveTransfer();
  }

  /// Leaves transfer without popping Home, which sits on top of login.
  void _leaveTransfer() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(ownAccountTransferProvider);
    if (kIsWeb) {
      return _buildWebScaffold(context, l10n, state);
    }

    final pad = TransferTheme.horizontalPadding(context);
    final maxWidth = TransferTheme.contentMaxWidth(context);

    final body = Column(
      children: [
        if (widget.embedded)
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Material(
                      color: AppColors.of(context).secondaryButtonBg,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        onTap: () => _onWizardBack(state),
                        borderRadius: BorderRadius.circular(6),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(Icons.chevron_left_rounded, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.transferMoney,
                        style: TransferTheme.appBarTitle(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TransferProgressBar(currentStep: state.step),
              ],
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
                child: _buildStep(context, l10n, state),
              ),
            ),
          ),
        ),
        TransferBottomActions(
          onBack: () => _onWizardBack(state),
          onPrimary: state.requiresOtp ? _submitOtp : () => _onPrimary(state),
          backLabel: l10n.back,
          primaryLabel: state.requiresOtp
              ? l10n.confirm
              : (state.step == 2
                  ? l10n.submit
                  : (state.step == 1 ? l10n.review : l10n.next)),
          primaryLoading: state.isValidating || state.isSubmitting,
          showPrimary: true,
          useSafeArea: !widget.embedded,
        ),
      ],
    );

    if (widget.embedded) {
      final content = ColoredBox(
        color: HomeColors.bg(context),
        child: SafeArea(bottom: false, child: body),
      );
      if (state.step >= 2) {
        return SecureScreen(child: content);
      }
      return content;
    }

    return SecureScreen(
      child: Scaffold(
        backgroundColor: HomeColors.bg(context),
        appBar: TransferMobileAppBar(
          title: l10n.transferMoney,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TransferTheme.screenPadding,
                0,
                TransferTheme.screenPadding,
                12,
              ),
              child: TransferProgressBar(currentStep: state.step),
            ),
          ),
        ),
        body: body,
      ),
    );
  }

  Widget _buildWebScaffold(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    final showReview = !state.requiresOtp && state.step >= 2;
    final loading = state.isValidating || state.isSubmitting;
    final otpBlocked = state.requiresOtp &&
        state.otpChallenge?.attemptsLeft != null &&
        state.otpChallenge!.attemptsLeft! <= 0;
    final success = _successSnapshot;

    Widget body;
    if (success != null) {
      body = TransferSuccessContent(snapshot: success, compact: true);
    } else if (state.requiresOtp) {
      body = Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _buildOtpStep(context, l10n, state),
        ),
      );
    } else if (showReview) {
      body = _buildReviewStep(context, l10n, state);
    } else {
      body = _buildWebForm(context, l10n, state);
    }

    final content = ColoredBox(
      color: HomeColors.bg(context),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final paneWidth = constraints.maxWidth;
            final pad = paneWidth < 900 ? 20.0 : 30.0;
            final twoCol = paneWidth >= 900;
            final maxWidth = TransferTheme.webPaneMaxWidth(context);

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, 22, pad, 32),
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.transferMoney,
                        style: TransferTheme.pageTitle(context),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(twoCol ? 28 : 20),
                        decoration: BoxDecoration(
                          color: HomeColors.card(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: HomeColors.divider(context),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            body,
                            if (success == null &&
                                state.errorMessage != null &&
                                !state.requiresOtp) ...[
                              const SizedBox(height: 12),
                              Text(
                                state.errorMessage!,
                                style: TextStyle(
                                  color: AppColors.of(context).error,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (success != null)
                        TransferWebSuccessActions(
                          newTransferLabel: l10n.newTransfer,
                          doneLabel: l10n.done,
                          onNewTransfer: _startNewTransfer,
                          onDone: _finishSuccess,
                        )
                      else
                        TransferWebActionBar(
                          primaryLabel: state.requiresOtp || showReview
                              ? l10n.confirm
                              : l10n.pay,
                          cancelLabel: l10n.cancel,
                          backLabel: l10n.back,
                          loading: loading,
                          primaryEnabled: !otpBlocked,
                          onPrimary: state.requiresOtp
                              ? _submitOtp
                              : () => _onSubmitWeb(state),
                          onCancel: _leaveTransfer,
                          onBack: () => _onWebBack(state),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    if (success != null || state.requiresOtp || showReview) {
      return SecureScreen(child: content);
    }
    return content;
  }

  Widget _buildWebForm(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    const radioBlue = TransferTheme.webRadioSelected;
    final twoCol = TransferTheme.useWebTwoColumn(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.transferType, style: TransferTheme.webLabel(context)),
        const SizedBox(height: 8),
        Row(
          children: [
            TransferPlainRadio(
              label: l10n.existing,
              selected: !_myAccountsSelected,
              selectedColor: radioBlue,
              onTap: _showComingSoon,
            ),
            const SizedBox(width: 24),
            TransferPlainRadio(
              label: l10n.myAccounts,
              selected: _myAccountsSelected,
              selectedColor: radioBlue,
              onTap: () => setState(() => _myAccountsSelected = true),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ..._webAccountFields(context, l10n, state, twoCol: twoCol),
        const SizedBox(height: 24),
        ..._webAmountFields(context, l10n, state, twoCol: twoCol),
      ],
    );
  }

  Widget _webPair({
    required bool twoCol,
    required Widget left,
    required Widget right,
    double gap = 24,
  }) {
    if (!twoCol) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          SizedBox(height: gap),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: gap),
        Expanded(child: right),
      ],
    );
  }

  List<Widget> _webAccountFields(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state, {
    required bool twoCol,
  }) {
    final accounts = _accounts.where((a) => a.id.isNotEmpty).toList();
    final creditOptions =
        accounts.where((a) => a.id != state.debitAccount?.id).toList();
    final fromField = TransferWebSelect<CasaAccount>(
      label: l10n.transferFrom,
      hint: l10n.selectDebitAccount,
      items: accounts,
      value: state.debitAccount,
      helper: _debitBalanceHelper(l10n, state.debitAccount),
      labelFor: _accountDropdownLabel,
      onChanged: (a) =>
          ref.read(ownAccountTransferProvider.notifier).selectDebitAccount(a),
    );
    final toField = TransferWebSelect<CasaAccount>(
      label: l10n.transferTo,
      hint: l10n.selectCreditAccount,
      items: creditOptions,
      value: state.creditAccount,
      helper: _debitBalanceHelper(l10n, state.creditAccount),
      labelFor: _accountDropdownLabel,
      onChanged: (a) =>
          ref.read(ownAccountTransferProvider.notifier).selectCreditAccount(a),
    );
    return [
      _webPair(twoCol: twoCol, left: fromField, right: toField),
    ];
  }

  List<Widget> _webAmountFields(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state, {
    required bool twoCol,
  }) {
    final codes = _currencyCodes(state);
    final creditCurrency = state.creditCurrency ??
        state.creditAccount?.currencyCode ??
        state.debitAccount?.currencyCode ??
        codes.firstOrNull ??
        'GBP';
    final transferCurrency = state.transferCurrency ??
        state.debitAccount?.currencyCode ??
        codes.firstOrNull ??
        'GBP';
    final currencyItems = codes.isEmpty ? [transferCurrency] : codes;
    final showFx =
        state.hasCrossCurrency || state.validation?.exchangeRate != null;

    final creditCurrencyField = TransferWebSelect<String>(
      label: l10n.creditAccountCurrency,
      hint: l10n.creditAccountCurrency,
      items: currencyItems,
      value: creditCurrency,
      labelFor: (c) => c,
      onChanged: (v) =>
          ref.read(ownAccountTransferProvider.notifier).setCreditCurrency(v),
    );
    final transferCurrencyField = TransferWebSelect<String>(
      label: l10n.transferCurrencyLabel,
      hint: l10n.transferCurrencyLabel,
      items: currencyItems,
      value: transferCurrency,
      labelFor: (c) => c,
      onChanged: (v) =>
          ref.read(ownAccountTransferProvider.notifier).setTransferCurrency(v),
    );
    final amountField = TransferTextField(
      label: l10n.transferAmount,
      controller: _amountController,
      hint: '0.00',
      prefixText: '$transferCurrency ',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      webLabel: true,
    );

    return [
      creditCurrencyField,
      const SizedBox(height: 24),
      _webPair(
        twoCol: twoCol,
        left: transferCurrencyField,
        right: amountField,
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => _showComingSoon(limits: true),
          style: TextButton.styleFrom(
            foregroundColor: TransferTheme.webLink,
            padding: const EdgeInsets.only(top: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            l10n.viewLimits,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: TransferTheme.webLink,
            ),
          ),
        ),
      ),
      TransferWebExchangeBox(
        visible: showFx,
        title: l10n.exchangeRateDetailsCard,
        rateLabel: l10n.rateApplied,
        rateValue: _rateValue(state),
        calculatedLabel: l10n.calculatedAmount,
        calculatedValue: _calculatedValue(state),
        indicativeNote: l10n.currencyRatesIndicative,
      ),
      if (showFx) const SizedBox(height: 20),
      Text(l10n.transferWhen, style: TransferTheme.webLabel(context)),
      const SizedBox(height: 8),
      Row(
        children: [
          TransferPlainRadio(
            label: l10n.now,
            selected: state.transferNow,
            selectedColor: TransferTheme.webRadioSelected,
            onTap: () => ref
                .read(ownAccountTransferProvider.notifier)
                .setTransferNow(true),
          ),
          const SizedBox(width: 24),
          TransferPlainRadio(
            label: l10n.later,
            selected: !state.transferNow,
            selectedColor: TransferTheme.webRadioSelected,
            onTap: () => ref
                .read(ownAccountTransferProvider.notifier)
                .setTransferNow(false),
          ),
        ],
      ),
      if (!state.transferNow) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _scheduleDateButton(context, l10n, state),
        ),
      ],
      const SizedBox(height: 12),
      TransferChargesCheck(
        value: state.chargesFromDebitAccount,
        label: l10n.chargesDebitedFromDebitAccount,
        web: true,
        onChanged: (v) => ref
            .read(ownAccountTransferProvider.notifier)
            .setChargesFromDebitAccount(v),
      ),
      const SizedBox(height: 20),
      TransferTextField(
        label: l10n.note,
        controller: _noteController,
        hint: l10n.note,
        webLabel: true,
      ),
      const SizedBox(height: 20),
      TransferTextField(
        label: l10n.stationaryCharges,
        controller: _stationaryController,
        hint: l10n.stationaryCharges,
        webLabel: true,
      ),
    ];
  }

  Widget _buildStep(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    switch (state.step) {
      case 0:
        return _buildAccountsStep(context, l10n, state);
      case 1:
        return _buildAmountStep(context, l10n, state);
      case 2:
        if (state.requiresOtp) {
          return _buildOtpStep(context, l10n, state);
        }
        return _buildReviewStep(context, l10n, state);
      default:
        return _buildAccountsStep(context, l10n, state);
    }
  }

  Widget _buildOtpStep(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    final challenge = state.otpChallenge;
    final otp = OtpChallengeBody(
      title: l10n.otpTitle,
      subtitle: l10n.transferOtpSubtitle,
      controller: _otpController,
      focusNode: _otpFocusNode,
      isLoading: state.isSubmitting,
      attemptsLeft: challenge?.attemptsLeft,
      resendsLeft: challenge?.resendsLeft,
      referenceNumber: (challenge?.referenceNo.isEmpty ?? true)
          ? null
          : challenge!.referenceNo,
      errorMessage: state.errorMessage,
      onSubmit: _submitOtp,
      onResend: _resendOtp,
      expandToFill: false,
      compact: true,
      showSubmitButton: false,
    );
    if (kIsWeb) return otp;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: TransferTheme.elevatedCard(context),
      child: otp,
    );
  }

  String _stepTitle(AppLocalizations l10n, int step) {
    switch (step) {
      case 0:
        return l10n.selectAccountTitle;
      case 1:
        return l10n.amountAndRateTitle;
      case 2:
        return l10n.transferSummary;
      default:
        return l10n.transferMoney;
    }
  }

  Widget _buildAccountsStep(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransferStepTitle(_stepTitle(l10n, 0)),
        const SizedBox(height: 12),
        _buildTransferTypeSelector(context, l10n),
        const SizedBox(height: TransferTheme.sectionGap),
        _accountSelectors(context, l10n, state),
      ],
    );
  }

  Widget _buildTransferTypeSelector(
      BuildContext context, AppLocalizations l10n) {
    if (_isOption2) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TransferTypeTile(
              label: l10n.newPayer,
              icon: Icons.person_add_alt_1_outlined,
              selected: !_myAccountsSelected,
              onTap: _showComingSoon,
            ),
            const SizedBox(width: TransferTheme.typeTileGap),
            TransferTypeTile(
              label: l10n.myAccounts,
              icon: Icons.account_balance_wallet_outlined,
              selected: _myAccountsSelected,
              onTap: () => setState(() => _myAccountsSelected = true),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: TransferTheme.formCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TransferSectionTitle(l10n.transferType),
          Row(
            children: [
              TransferRadioOption(
                label: l10n.existingPayer,
                selected: !_myAccountsSelected,
                onTap: _showComingSoon,
              ),
              const SizedBox(width: 12),
              TransferRadioOption(
                label: l10n.myAccounts,
                selected: _myAccountsSelected,
                onTap: () => setState(() => _myAccountsSelected = true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountSelectors(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    final accounts = _accounts.where((a) => a.id.isNotEmpty).toList();
    final creditOptions =
        accounts.where((a) => a.id != state.debitAccount?.id).toList();

    if (kIsWeb) {
      final fromField = TransferWebSelect<CasaAccount>(
        label: l10n.transferFrom,
        hint: l10n.selectDebitAccount,
        items: accounts,
        value: state.debitAccount,
        helper: _debitBalanceHelper(l10n, state.debitAccount),
        labelFor: _accountDropdownLabel,
        onChanged: (a) =>
            ref.read(ownAccountTransferProvider.notifier).selectDebitAccount(a),
      );
      final toField = TransferWebSelect<CasaAccount>(
        label: l10n.transferTo,
        hint: l10n.selectCreditAccount,
        items: creditOptions,
        value: state.creditAccount,
        helper: _debitBalanceHelper(l10n, state.creditAccount),
        labelFor: _accountDropdownLabel,
        onChanged: (a) => ref
            .read(ownAccountTransferProvider.notifier)
            .selectCreditAccount(a),
      );
      if (Responsive.of(context).useWideLayout) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fromField),
            const SizedBox(width: 16),
            Expanded(child: toField),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fromField,
          const SizedBox(height: TransferTheme.sectionGap),
          toField,
        ],
      );
    }

    final fromField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransferSectionTitle(l10n.transferFrom),
        if (state.debitAccount != null)
          TransferFromAccountCard(
            account: state.debitAccount!,
            onChange: () => _pickAccount(
              debit: true,
              selected: state.debitAccount,
              options: accounts,
            ),
          )
        else
          TransferPickerField(
            hint: l10n.selectDebitAccount,
            onTap: () => _pickAccount(
              debit: true,
              selected: null,
              options: accounts,
            ),
          ),
      ],
    );
    final toField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransferSectionTitle(l10n.transferTo),
        if (state.creditAccount != null)
          TransferFromAccountCard(
            account: state.creditAccount!,
            leadingIcon: Icons.person_outline_rounded,
            showBalance: false,
            onChange: () => _pickAccount(
              debit: false,
              selected: state.creditAccount,
              options: creditOptions,
            ),
          )
        else
          TransferPickerField(
            hint: l10n.selectCreditAccount,
            onTap: () => _pickAccount(
              debit: false,
              selected: state.creditAccount,
              options: creditOptions,
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fromField,
        const SizedBox(height: TransferTheme.sectionGap),
        toField,
      ],
    );
  }

  String? _debitBalanceHelper(AppLocalizations l10n, CasaAccount? account) {
    if (account == null) return null;
    final balance = account.displayBalance;
    if (balance == null) return null;
    final text = MoneyFormat.format(
      balance.amount,
      currencyCode: balance.currency ?? account.currencyCode,
    );
    return '${l10n.balance} : $text';
  }

  Widget _buildAmountStep(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    if (state.debitAccount == null || state.creditAccount == null) {
      return _buildAccountsStep(context, l10n, state);
    }

    if (_isOption2) {
      return _buildOption2AmountStep(context, l10n, state);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransferStepTitle(_stepTitle(l10n, 1)),
        const SizedBox(height: 12),
        ..._amountFields(context, l10n, state),
      ],
    );
  }

  Widget _buildOption2AmountStep(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    final codes = _currencyCodes(state);
    final creditCurrency = state.creditCurrency ??
        state.creditAccount?.currencyCode ??
        state.debitAccount?.currencyCode ??
        codes.firstOrNull ??
        'GBP';
    final transferCurrency = state.transferCurrency ??
        state.debitAccount?.currencyCode ??
        codes.firstOrNull ??
        'GBP';
    final currencyItems = codes.isEmpty ? [transferCurrency] : codes;
    final showFx =
        state.hasCrossCurrency || state.validation?.exchangeRate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransferAccountSummaryRow(
          fromAccount: state.debitAccount!,
          toAccount: state.creditAccount!,
        ),
        const SizedBox(height: 16),
        TransferStepTitle(l10n.amountAndRateTitle),
        const SizedBox(height: 8),
        TransferSoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TransferWebSelect<String>(
                hint: l10n.creditAccountCurrency,
                items: currencyItems,
                value: creditCurrency,
                labelFor: (c) => c,
                onChanged: (v) => ref
                    .read(ownAccountTransferProvider.notifier)
                    .setCreditCurrency(v),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TransferSectionTitle(
                      l10n.transferAmount,
                      compact: true,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showComingSoon(limits: true),
                    style: TextButton.styleFrom(
                      foregroundColor: TransferTheme.webLink,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.viewLimits,
                      style: TransferTheme.caption(context).copyWith(
                        color: TransferTheme.webLink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TransferAmountInput(
                controller: _amountController,
                currency: transferCurrency,
                currencies: currencyItems,
                onCurrencyChanged: (v) => ref
                    .read(ownAccountTransferProvider.notifier)
                    .setTransferCurrency(v),
              ),
            ],
          ),
        ),
        if (showFx) ...[
          const SizedBox(height: 16),
          TransferExchangeRateBox(
            title: l10n.exchangeRateDetailsTitle,
            rateLabel: l10n.rateApplied,
            rateValue: _rateValue(state),
            calculatedLabel: l10n.calculatedAmount,
            calculatedValue: _calculatedValue(state),
            indicativeNote: l10n.currencyRatesIndicative,
          ),
        ],
        const SizedBox(height: 16),
        TransferSoftCard(
          color: TransferTheme.mutedCardBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TransferSectionTitle(l10n.transferWhen),
              TransferWhenToggle(
                nowLabel: l10n.now,
                laterLabel: l10n.later,
                transferNow: state.transferNow,
                onNow: () => ref
                    .read(ownAccountTransferProvider.notifier)
                    .setTransferNow(true),
                onLater: () => ref
                    .read(ownAccountTransferProvider.notifier)
                    .setTransferNow(false),
              ),
              if (!state.transferNow) ...[
                const SizedBox(height: 12),
                _scheduleDateButton(context, l10n, state),
              ],
              const SizedBox(height: 16),
              TransferChargesCheck(
                value: state.chargesFromDebitAccount,
                label: l10n.chargesDebitedFromDebitAccount,
                onChanged: (v) => ref
                    .read(ownAccountTransferProvider.notifier)
                    .setChargesFromDebitAccount(v),
              ),
              const SizedBox(height: 16),
              TransferTextField(
                label: l10n.note,
                controller: _noteController,
                hint: l10n.note,
                captionLabel: true,
              ),
              const SizedBox(height: 16),
              TransferTextField(
                label: l10n.stationaryCharges,
                controller: _stationaryController,
                hint: l10n.stationaryCharges,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scheduleDateButton(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    return OutlinedButton.icon(
      onPressed: () async {
        final now = state.paymentDate ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: state.scheduledDate ?? now.add(const Duration(days: 1)),
          firstDate: now,
          lastDate: now.add(const Duration(days: 365)),
        );
        if (picked != null) {
          ref
              .read(ownAccountTransferProvider.notifier)
              .setScheduledDate(picked);
        }
      },
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(
        state.scheduledDate == null
            ? l10n.transferSelectDate
            : MaterialLocalizations.of(context).formatMediumDate(
                state.scheduledDate!,
              ),
      ),
    );
  }

  List<Widget> _amountFields(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    final codes = _currencyCodes(state);
    final creditCurrency = state.creditCurrency ??
        state.creditAccount?.currencyCode ??
        state.debitAccount?.currencyCode ??
        codes.firstOrNull ??
        'GBP';
    final transferCurrency = state.transferCurrency ??
        state.debitAccount?.currencyCode ??
        codes.firstOrNull ??
        'GBP';
    final showFx =
        state.hasCrossCurrency || state.validation?.exchangeRate != null;
    final currencyItems = codes.isEmpty ? [transferCurrency] : codes;

    final fields = <Widget>[
      if (state.hasCrossCurrency) ...[
        TransferWebSelect<String>(
          label: l10n.creditAccountCurrency,
          hint: l10n.creditAccountCurrency,
          items: currencyItems,
          value: creditCurrency,
          labelFor: (c) => c,
          onChanged: (v) => ref
              .read(ownAccountTransferProvider.notifier)
              .setCreditCurrency(v),
        ),
        const SizedBox(height: TransferTheme.sectionGap),
      ],
      Row(
        children: [
          Expanded(child: TransferSectionTitle(l10n.transferAmount)),
          TextButton(
            onPressed: () => _showComingSoon(limits: true),
            style: TextButton.styleFrom(
              foregroundColor: TransferTheme.accentLink(context),
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.viewLimits,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: TransferWebSelect<String>(
              items: currencyItems,
              value: transferCurrency,
              labelFor: (c) => c,
              onChanged: (v) => ref
                  .read(ownAccountTransferProvider.notifier)
                  .setTransferCurrency(v),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              decoration: InputDecoration(
                hintText: '0.00',
                filled: true,
                fillColor: AppColors.of(context).inputBackground,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(TransferTheme.fieldRadius),
                  borderSide:
                      BorderSide(color: AppColors.of(context).inputBorder),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: TransferTheme.sectionGap),
      TransferExchangeRateBox(
        visible: showFx,
        title: l10n.exchangeRateDetailsTitle,
        rateLabel: l10n.rateApplied,
        rateValue: _rateValue(state),
        calculatedLabel: l10n.calculatedAmount,
        calculatedValue: _calculatedValue(state),
        indicativeNote: l10n.currencyRatesIndicative,
      ),
      const SizedBox(height: TransferTheme.sectionGap),
      TransferSectionTitle(l10n.transferWhen),
      Row(
        children: [
          TransferRadioOption(
            label: l10n.now,
            selected: state.transferNow,
            onTap: () => ref
                .read(ownAccountTransferProvider.notifier)
                .setTransferNow(true),
          ),
          const SizedBox(width: 12),
          TransferRadioOption(
            label: l10n.later,
            selected: !state.transferNow,
            onTap: () => ref
                .read(ownAccountTransferProvider.notifier)
                .setTransferNow(false),
          ),
        ],
      ),
      if (!state.transferNow) ...[
        const SizedBox(height: 12),
        _scheduleDateButton(context, l10n, state),
      ],
      const SizedBox(height: 12),
      TransferChargesCheck(
        value: state.chargesFromDebitAccount,
        label: l10n.chargesDebitedFromDebitAccount,
        onChanged: (v) => ref
            .read(ownAccountTransferProvider.notifier)
            .setChargesFromDebitAccount(v),
      ),
      const SizedBox(height: 16),
      TransferTextField(
        label: l10n.note,
        controller: _noteController,
        hint: l10n.note,
      ),
      const SizedBox(height: 16),
      TransferTextField(
        label: l10n.stationaryCharges,
        controller: _stationaryController,
        hint: l10n.stationaryCharges,
      ),
    ];

    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: TransferTheme.formCard(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: fields,
        ),
      ),
    ];
  }

  Widget _buildReviewStep(
    BuildContext context,
    AppLocalizations l10n,
    OwnAccountTransferState state,
  ) {
    final debit = state.debitAccount;
    final credit = state.creditAccount;
    final amount = state.parsedAmount;
    if (debit == null || credit == null || amount == null) {
      return const SizedBox.shrink();
    }

    final currency = state.transferCurrency ?? debit.currencyCode;
    final sendText = MoneyFormat.format(amount, currencyCode: currency);
    final receiveAmount = state.validation?.calculatedAmount ?? amount;
    final receiveCurrency = state.validation?.calculatedCurrency ??
        state.creditCurrency ??
        credit.currencyCode;
    final receiveText =
        MoneyFormat.format(receiveAmount, currencyCode: receiveCurrency);
    final showFx =
        state.hasCrossCurrency || state.validation?.exchangeRate != null;

    final fromMask = kIsWeb
        ? TransferTheme.webMask(debit.displayNumber)
        : TransferTheme.maskLastFour(debit.displayNumber);
    final toMask = kIsWeb
        ? TransferTheme.webMask(credit.displayNumber)
        : TransferTheme.maskLastFour(credit.displayNumber);

    final rows = Column(
      children: [
        TransferReviewRow(
          icon: Icons.account_balance_rounded,
          label: l10n.transferSummaryFrom,
          value: TransferTheme.compactTitle(debit.title),
          subValue: fromMask,
        ),
        TransferReviewRow(
          icon: Icons.person_outline_rounded,
          label: l10n.transferSummaryTo,
          value: TransferTheme.compactTitle(credit.title),
          subValue: toMask,
        ),
        TransferReviewRow(
          icon: Icons.send_rounded,
          label: l10n.youSend,
          value: sendText,
          boldValue: true,
        ),
        if (showFx) ...[
          TransferReviewRow(
            icon: Icons.sync_rounded,
            label: l10n.exchangeRate,
            value: _rateValue(state),
            subValue: '(${l10n.transferFixedRate})',
            subValueColor: TransferTheme.exchangeAccent,
          ),
          TransferReviewRow(
            icon: Icons.swap_horiz_rounded,
            label: l10n.theyReceive,
            value: receiveText,
            valueColor: TransferTheme.exchangeAccent,
          ),
        ],
        TransferReviewRow(
          icon: Icons.schedule_rounded,
          label: l10n.timing,
          value: state.transferNow ? l10n.immediate : l10n.scheduled,
          showDivider: false,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TransferStepTitle(_stepTitle(l10n, 2)),
        const SizedBox(height: 12),
        if (kIsWeb)
          rows
        else
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            decoration: TransferTheme.elevatedCard(context),
            child: rows,
          ),
      ],
    );
  }

  String _rateValue(OwnAccountTransferState state) {
    final v = state.validation;
    if (v?.exchangeRate != null &&
        v!.sourceCurrency != null &&
        v.targetCurrency != null) {
      return '${v.sourceCurrency} 1.00 = ${v.targetCurrency} ${v.exchangeRate!.toStringAsFixed(2)}';
    }
    final from =
        state.transferCurrency ?? state.debitAccount?.currencyCode ?? '';
    final to = state.creditCurrency ?? state.creditAccount?.currencyCode ?? '';
    if (from.isNotEmpty && to.isNotEmpty && from != to) {
      return '$from 1.00 = $to —';
    }
    return '—';
  }

  String _calculatedValue(OwnAccountTransferState state) {
    final amount = state.parsedAmount;
    if (amount == null) return '—';
    final from =
        state.transferCurrency ?? state.debitAccount?.currencyCode ?? '';
    final send = MoneyFormat.format(amount, currencyCode: from);
    final receiveAmount = state.validation?.calculatedAmount ?? amount;
    final receiveCurrency = state.validation?.calculatedCurrency ??
        state.creditCurrency ??
        state.creditAccount?.currencyCode ??
        from;
    final receive =
        MoneyFormat.format(receiveAmount, currencyCode: receiveCurrency);
    return '$send = $receive';
  }

  TransferConfirmationSnapshot _confirmationSnapshot(
    TransferSubmitResult result,
  ) {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(ownAccountTransferProvider);
    final debit = state.debitAccount;
    final credit = state.creditAccount;
    final amount = state.parsedAmount;
    final currency = state.transferCurrency ?? debit?.currencyCode ?? '';
    final whenDate = result.valueDate ??
        (state.transferNow
            ? (state.validation?.valueDate ??
                state.paymentDate ??
                DateTime.now())
            : (state.scheduledDate ?? state.paymentDate ?? DateTime.now()));
    final charges = state.chargesFromDebitAccount ? debit : credit;

    return TransferConfirmationSnapshot(
      result: result,
      toMask: credit == null
          ? ''
          : TransferTheme.maskLastFour(credit.displayNumber),
      toMeta: credit == null ? '' : TransferTheme.compactTitle(credit.title),
      fromMask:
          debit == null ? '' : TransferTheme.maskLastFour(debit.displayNumber),
      fromMeta: debit == null ? '' : TransferTheme.compactTitle(debit.title),
      payBy: l10n.creditAccountCurrency,
      amountText: amount == null
          ? ''
          : MoneyFormat.format(amount, currencyCode: currency),
      whenText: MaterialLocalizations.of(context).formatMediumDate(whenDate),
      chargesMask: charges == null
          ? ''
          : TransferTheme.maskLastFour(charges.displayNumber),
      chargesMeta:
          charges == null ? '' : TransferTheme.compactTitle(charges.title),
      note: state.note.trim(),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
