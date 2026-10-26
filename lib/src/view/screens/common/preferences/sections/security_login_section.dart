import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/models/common/security_question.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/providers/common/preferences_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/settings_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';
import 'package:ubci_bank/src/view/widgets/biometric_enrollment_prompt.dart';
import 'package:ubci_bank/src/view/widgets/biometric_ui_copy.dart';

enum _SecurityItem { questions, softToken, smsMissedCall, smsPin, biometric, devices }

/// Preferences → Security & Login (OBDX `security-menu`): a tab bar of
/// Set Security Question, Soft Token Authentication, SMS and Missed Call
/// Banking, SMS and Chatbot Banking, and — in the mobile app — Manage
/// Touch ID / Face ID; then Devices (OBDX's registered devices and
/// wearables, plus Forget this device). OBDX lists Change Password only
/// for the ADMIN segment, so it is not offered here either.
class SecurityLoginSection extends StatefulWidget {
  const SecurityLoginSection({super.key});

  @override
  State<SecurityLoginSection> createState() => _SecurityLoginSectionState();
}

class _SecurityLoginSectionState extends State<SecurityLoginSection> {
  _SecurityItem _item = _SecurityItem.questions;

  String _label(AppLocalizations l10n, _SecurityItem item) => switch (item) {
        _SecurityItem.questions => l10n.prefSetSecurityQuestion,
        _SecurityItem.softToken => l10n.prefSoftToken,
        _SecurityItem.smsMissedCall => l10n.prefSmsMissedCall,
        _SecurityItem.smsPin => l10n.prefSmsChatbot,
        _SecurityItem.biometric => l10n.prefManageBiometric,
        _SecurityItem.devices => l10n.prefDevices,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    final items = [
      for (final i in _SecurityItem.values)
        if (i != _SecurityItem.biometric || !kIsWeb) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                ChoiceChip(
                  selected: item == _item,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _item = item),
                  selectedColor: brand.withValues(alpha: 0.14),
                  backgroundColor: HomeColors.card(context),
                  side: BorderSide(color: item == _item ? brand : HomeColors.divider(context)),
                  label: Text(
                    _label(l10n, item),
                    style: TextStyle(
                      fontWeight: item == _item ? FontWeight.w700 : FontWeight.w500,
                      color: item == _item ? brand : HomeColors.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: ValueKey(_item),
          child: switch (_item) {
            _SecurityItem.questions => const _SecurityQuestions(),
            _SecurityItem.softToken => const _SoftToken(),
            _SecurityItem.smsMissedCall => const _SmsMissedCall(),
            _SecurityItem.smsPin => const _SmsPin(),
            _SecurityItem.biometric => const _Biometric(),
            _SecurityItem.devices => const _Devices(),
          },
        ),
      ],
    );
  }
}

// ── Set Security Question (view-user-security-question + flow) ───────────

enum _QStage { view, edit, review, done }

class _SecurityQuestions extends ConsumerStatefulWidget {
  const _SecurityQuestions();

  @override
  ConsumerState<_SecurityQuestions> createState() => _SecurityQuestionsState();
}

class _SecurityQuestionsState extends ConsumerState<_SecurityQuestions> {
  _QStage _stage = _QStage.view;
  bool _create = true;
  List<SecurityQuestionOption?> _questions = [];
  List<TextEditingController> _answers = [];
  List<String?> _errors = [];
  String? _formError;
  bool _saving = false;
  String? _reference;

  static final _answerPattern = RegExp(r'^[a-zA-Z0-9]{1,100}$');

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  void _start(List<UserSecurityQuestion> current, List<SecurityQuestionOption> catalog, int count) {
    for (final c in _answers) {
      c.dispose();
    }
    setState(() {
      _create = current.isEmpty;
      _questions = List.generate(
        count,
        (i) => i < current.length ? catalog.where((q) => q.id == current[i].questionId).firstOrNull : null,
      );
      _answers = List.generate(count, (_) => TextEditingController());
      _errors = List.filled(count, null);
      _formError = null;
      _stage = _QStage.edit;
    });
  }

  Future<void> _pick(int index, List<SecurityQuestionOption> catalog) async {
    final l10n = AppLocalizations.of(context);
    // A question chosen in one slot is taken out of the others.
    final taken = {
      for (final (i, q) in _questions.indexed)
        if (i != index && q != null) q.id,
    };
    final picked = await showPayPicker<String>(
      context,
      title: l10n.prefSecurityQuestion,
      selected: _questions[index]?.id,
      options: [
        for (final q in catalog)
          if (!taken.contains(q.id)) PayOption(value: q.id, title: q.text),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _questions[index] = catalog.firstWhere((q) => q.id == picked));
  }

  void _toReview() {
    final l10n = AppLocalizations.of(context);
    var ok = true;
    for (var i = 0; i < _questions.length; i++) {
      final answer = _answers[i].text.trim();
      if (_questions[i] == null) {
        _errors[i] = l10n.prefSelectQuestion;
        ok = false;
      } else if (!_answerPattern.hasMatch(answer)) {
        _errors[i] = l10n.prefInvalidAnswer;
        ok = false;
      } else {
        _errors[i] = null;
      }
    }
    final ids = [for (final q in _questions) q?.id].whereType<String>().toList();
    _formError = ids.toSet().length != ids.length ? l10n.prefDuplicateQuestions : null;
    setState(() {
      if (ok && _formError == null) _stage = _QStage.review;
    });
  }

  Future<void> _confirm() async {
    final answers = [
      for (var i = 0; i < _questions.length; i++)
        UserSecurityQuestionAnswer(questionId: _questions[i]!.id, answer: _answers[i].text.trim()),
    ];
    setState(() => _saving = true);
    final repo = ref.read(preferencesRepositoryProvider);
    final result = await runPrefWrite(context, (c, otp) => repo.saveSecurityQuestions(answers, create: _create, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => _saving = false);
    if (prefWriteDone(result)) {
      _reference = (result as Success<PrefWriteOutcome>).data!.reference;
      ref.invalidate(userSecurityQuestionsProvider);
      setState(() => _stage = _QStage.done);
    } else {
      final error = prefWriteError(context, result);
      if (error != null) prefSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_stage) {
      case _QStage.done:
        return PayResultView(
          title: l10n.prefStatusSuccessful,
          message: _reference == null ? l10n.prefRequestInitiated : l10n.prefRequestInitiatedRef(_reference!),
          reference: _reference,
          rows: const [],
          doneLabel: l10n.prefOk,
          onDone: () => setState(() => _stage = _QStage.view),
        );
      case _QStage.review:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrefReviewBanner(message: l10n.prefSecurityQuestionReview),
            const SizedBox(height: 14),
            PaySection(
              title: l10n.prefUserSecurityQuestions,
              child: Column(
                children: [
                  for (var i = 0; i < _questions.length; i++) ...[
                    PayReviewRow(label: l10n.prefQuestion, value: _questions[i]!.text),
                    PayReviewRow(label: l10n.prefAnswer, value: _answers[i].text.trim(), last: i == _questions.length - 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrefActions(children: [
              PayPrimaryButton(label: l10n.prefConfirm, loading: _saving, onPressed: _confirm),
              PaySecondaryButton(label: l10n.prefBack, onPressed: () => setState(() => _stage = _QStage.edit)),
              PaySecondaryButton(label: l10n.prefCancel, onPressed: () => setState(() => _stage = _QStage.view)),
            ]),
          ],
        );
      case _QStage.edit:
        final catalog = ref.watch(securityQuestionSetupProvider).valueOrNull?.catalog ?? const <SecurityQuestionOption>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaySection(
              title: l10n.prefUserSecurityQuestions,
              icon: Icons.quiz_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _questions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    PayFieldLabel(l10n.prefSecurityQuestion, required: true),
                    PayPickerField(
                      placeholder: l10n.prefSelectQuestion,
                      title: _questions[i]?.text,
                      icon: Icons.help_outline_rounded,
                      dense: true,
                      onTap: () => _pick(i, catalog),
                    ),
                    const SizedBox(height: 10),
                    PayTextField(
                      label: l10n.prefAnswer,
                      controller: _answers[i],
                      required: true,
                      error: _errors[i],
                      inputFormatters: [LengthLimitingTextInputFormatter(100)],
                    ),
                  ],
                  if (_formError != null) PayFieldError(_formError),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrefActions(children: [
              PayPrimaryButton(label: l10n.prefSubmit, onPressed: _toReview),
              PaySecondaryButton(label: l10n.prefCancel, onPressed: () => setState(() => _stage = _QStage.view)),
            ]),
          ],
        );
      case _QStage.view:
        final current = ref.watch(userSecurityQuestionsProvider);
        final setup = ref.watch(securityQuestionSetupProvider);
        return current.when(
          loading: () => const PrefLoading(),
          error: (e, _) => PrefFailed(error: e, onRetry: () => ref.invalidate(userSecurityQuestionsProvider)),
          data: (questions) {
            final ready = setup.valueOrNull;
            final start = ready == null ? null : () => _start(questions, ready.catalog, ready.count);
            if (setup.hasError) {
              return PrefFailed(error: setup.error!, onRetry: () => ref.invalidate(securityQuestionSetupProvider));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PaySection(
                  title: l10n.prefSetSecurityQuestion,
                  icon: Icons.quiz_outlined,
                  child: questions.isEmpty
                      ? PayMuted(l10n.prefQuestionsNotSetUp)
                      : Column(
                          children: [
                            for (final (i, q) in questions.indexed)
                              PrefLabelValue(label: l10n.prefSecurityQuestion, value: q.question, last: i == questions.length - 1),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                PrefActions(children: [
                  PayPrimaryButton(
                    label: questions.isEmpty ? l10n.prefSetUpNow : l10n.prefEdit,
                    loading: setup.isLoading,
                    onPressed: start,
                  ),
                ]),
              ],
            );
          },
        );
    }
  }
}

// ── Soft Token Authentication (soft-token-totp) ──────────────────────────

class _SoftToken extends ConsumerStatefulWidget {
  const _SoftToken();

  @override
  ConsumerState<_SoftToken> createState() => _SoftTokenState();
}

class _SoftTokenState extends ConsumerState<_SoftToken> {
  bool _oracle = true;
  bool _loading = false;
  SoftTokenSeed? _seed;
  bool _showKey = false;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _seed = null;
      _showKey = false;
    });
    final result = await ref.read(preferencesRepositoryProvider).generateSoftToken(oracleAuthenticator: _oracle);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result is Success<SoftTokenSeed> && result.data != null) {
      setState(() => _seed = result.data);
    } else {
      final message = result is Error<SoftTokenSeed> ? result.error : null;
      prefSnack(context, (message ?? '').isNotEmpty ? message! : l10n.prefSaveFailed);
    }
  }

  void _copyKey() {
    setState(() => _showKey = true);
    Clipboard.setData(ClipboardData(text: _seed!.seed));
    prefSnack(context, AppLocalizations.of(context).prefKeyCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySection(
          title: l10n.prefChooseAuthenticator,
          icon: Icons.qr_code_2_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrefRadio<bool>(value: true, group: _oracle, label: l10n.prefOracleAuthenticator, onChanged: (v) => setState(() => _oracle = v)),
              PrefRadio<bool>(value: false, group: _oracle, label: l10n.prefOtherAuthenticator, onChanged: (v) => setState(() => _oracle = v)),
              if (_seed != null) ...[
                const SizedBox(height: 16),
                if (_seed!.qrPng != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      // QR codes need a light quiet zone, also in dark mode.
                      color: Colors.white,
                      child: Image.memory(_seed!.qrPng!, width: 200, height: 200, fit: BoxFit.contain),
                    ),
                  ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _copyKey,
                    style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                    child: Text(l10n.prefCantScan),
                  ),
                ),
                if (_showKey)
                  SelectableText(
                    _seed!.seed,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: HomeColors.textPrimary(context)),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrefActions(children: [PayPrimaryButton(label: l10n.prefSubmit, loading: _loading, onPressed: _submit)]),
      ],
    );
  }
}

// ── SMS and Missed Call Banking (sms-and-missed-call-banking) ────────────

class _SmsMissedCall extends ConsumerStatefulWidget {
  const _SmsMissedCall();

  @override
  ConsumerState<_SmsMissedCall> createState() => _SmsMissedCallState();
}

class _SmsMissedCallState extends ConsumerState<_SmsMissedCall> {
  String? _busy;

  /// Each switch saves at once, sending only its own flag.
  Future<void> _toggle(String key, bool value) async {
    setState(() => _busy = key);
    final repo = ref.read(preferencesRepositoryProvider);
    final result = await runPrefWrite(context, (c, otp) => repo.updateSmsBanking({key: value}, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => _busy = null);
    prefReportWrite(context, result);
    ref.invalidate(smsBankingProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(smsBankingProvider).when(
          loading: () => const PrefLoading(),
          error: (e, _) => PrefFailed(error: e, onRetry: () => ref.invalidate(smsBankingProvider)),
          data: (reg) => PrefBlock(
            title: l10n.prefSmsMissedCall,
            icon: Icons.sms_outlined,
            children: [
              PrefSwitchRow(
                label: l10n.prefMissedCallBanking,
                value: reg.missedCallEnabled,
                busy: _busy == 'missedCallEnabled',
                onChanged: _busy == null ? (v) => _toggle('missedCallEnabled', v) : null,
              ),
              PrefSwitchRow(
                label: l10n.prefSmsBanking,
                value: reg.smsBankingEnabled,
                busy: _busy == 'smsBankingEnabled',
                onChanged: _busy == null ? (v) => _toggle('smsBankingEnabled', v) : null,
              ),
            ],
          ),
        );
  }
}

// ── SMS and Chatbot Banking (set-sms-banking-pin) ────────────────────────

class _SmsPin extends ConsumerStatefulWidget {
  const _SmsPin();

  @override
  ConsumerState<_SmsPin> createState() => _SmsPinState();
}

class _SmsPinState extends ConsumerState<_SmsPin> {
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  String? _pinError;
  String? _confirmError;
  bool _saving = false;

  static final _fourDigits = RegExp(r'^[0-9]{4}$');

  @override
  void dispose() {
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _pinError = _fourDigits.hasMatch(_pin.text) ? null : l10n.prefPinNumeric;
      _confirmError = _fourDigits.hasMatch(_confirmPin.text) ? null : l10n.prefPinNumeric;
      if (_pinError == null && _confirmError == null && _pin.text != _confirmPin.text) {
        _confirmError = l10n.prefPinMismatch;
      }
    });
    if (_pinError != null || _confirmError != null) return;
    setState(() => _saving = true);
    final repo = ref.read(preferencesRepositoryProvider);
    final result = await runPrefWrite(context, (c, otp) => repo.updateSmsBanking({'pin': _pin.text}, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => _saving = false);
    if (!prefWriteDone(result)) {
      final error = prefWriteError(context, result);
      if (error != null) prefSnack(context, error);
      return;
    }
    _pin.clear();
    _confirmPin.clear();
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: HomeColors.card(dialog),
        icon: Icon(Icons.check_circle_rounded, color: HomeColors.success(dialog), size: 40),
        title: Text(l10n.prefSuccess),
        content: Text(l10n.prefPinSetUp),
        actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.prefOk))],
      ),
    );
  }

  Widget _pinField(String label, TextEditingController c, String? error) => TextField(
        controller: c,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        decoration: payInputDecoration(context, hint: label, hasError: error != null),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySection(
          title: l10n.prefSetResetPin,
          icon: Icons.pin_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PayFieldLabel(l10n.prefSetPin, required: true),
              _pinField(l10n.prefSetPin, _pin, _pinError),
              PayFieldError(_pinError),
              const SizedBox(height: 14),
              PayFieldLabel(l10n.prefConfirmPin, required: true),
              _pinField(l10n.prefConfirmPin, _confirmPin, _confirmError),
              PayFieldError(_confirmError),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrefActions(children: [PayPrimaryButton(label: l10n.prefConfirm, loading: _saving, onPressed: _submit)]),
      ],
    );
  }
}

// ── Devices: registered devices and Forget this device ───────────────────

class _Devices extends ConsumerWidget {
  const _Devices();

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppBottomSheet.confirm(
      context,
      title: l10n.forgetDevice,
      message: l10n.forgetDeviceConfirm,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(sessionManagerProvider).forgetDevice();
    if (!context.mounted) return;
    // Root: on web Preferences sits in the dashboard's content navigator.
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(RoutesConst.loginScreen, (route) => false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RegisteredDevicesSettings(),
        const SizedBox(height: 14),
        PrefBlock(
          title: l10n.forgetDevice,
          icon: Icons.phonelink_erase,
          note: l10n.forgetDeviceConfirm,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _forget(context, ref),
                icon: const Icon(Icons.phonelink_erase, size: 18),
                label: Text(l10n.forgetDevice),
                style: TextButton.styleFrom(foregroundColor: HomeColors.error(context)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Manage Touch ID / Face ID (security-landing, mobile app only) ────────

class _Biometric extends ConsumerStatefulWidget {
  const _Biometric();

  @override
  ConsumerState<_Biometric> createState() => _BiometricState();
}

class _BiometricState extends ConsumerState<_Biometric> {
  bool? _enabled;
  BiometricPresentation _presentation = BiometricPresentation.android;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ref.read(biometricEnrollmentProvider).isEnabled();
    final presentation = await ref.read(biometricServiceProvider).presentation();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _presentation = presentation;
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      await BiometricEnrollmentPrompt.enableFromSettings(context, ref);
    } else {
      await BiometricEnrollmentPrompt.disableFromSettings(context, ref);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_enabled == null) return const PrefLoading();
    final helper = BiometricUiCopy.helperText(l10n, _presentation);
    return PrefBlock(
      title: l10n.prefManageBiometric,
      icon: BiometricUiCopy.icon(_presentation),
      note: helper,
      children: [
        PrefSwitchRow(
          label: BiometricUiCopy.enableLabel(l10n, _presentation),
          value: _enabled!,
          onChanged: _toggle,
        ),
      ],
    );
  }
}
