import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/forgot_credentials_pending.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/date_of_birth_format.dart';
import 'package:ubci_bank/src/core/utils/email_validator.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';
import 'package:ubci_bank/src/view/providers/forgot_credentials_providers.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_flow_success_panel.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_shell.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_labeled_field.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_screen_header.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_challenge_body.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

class ForgotCredentialsArgs {
  const ForgotCredentialsArgs({required this.kind});

  final ForgotCredentialsKind kind;
}

enum _ForgotStep { details, otp, success }

class ForgotCredentialsScreen extends ConsumerStatefulWidget {
  const ForgotCredentialsScreen({super.key, required this.kind});

  final ForgotCredentialsKind kind;

  @override
  ConsumerState<ForgotCredentialsScreen> createState() =>
      _ForgotCredentialsScreenState();
}

class _ForgotCredentialsScreenState
    extends ConsumerState<ForgotCredentialsScreen> {
  final _detailsFormKey = GlobalKey<FormState>();
  final _emailOrUserController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  _ForgotStep _step = _ForgotStep.details;
  DateTime? _dateOfBirth;
  ForgotCredentialsPending? _pending;

  bool get _isUsername => widget.kind == ForgotCredentialsKind.username;

  @override
  void dispose() {
    RegistrationSessionHolder.instance.clear();
    _emailOrUserController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  String _formatDobApi(DateTime date) => DateOfBirthFormat.toApi(date);

  String _displayDob(DateTime date) => DateOfBirthFormat.toDisplay(date);

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _cancelFlow() async {
    await ref.read(forgotCredentialsScreenVmProvider).abandon();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _submitDetails() async {
    final l10n = AppLocalizations.of(context);
    if (!_detailsFormKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      ref.read(forgotErrorMessageProvider.notifier).state =
          l10n.forgotDateOfBirthRequired;
      return;
    }

    final vm = ref.read(forgotCredentialsScreenVmProvider);
    final dob = _formatDobApi(_dateOfBirth!);
    final result = _isUsername
        ? await vm.startForgotUsername(
            emailId: _emailOrUserController.text.trim(),
            dateOfBirth: dob,
          )
        : await vm.startForgotPassword(
            userId: _emailOrUserController.text.trim(),
            dateOfBirth: dob,
          );

    if (!mounted || result == null) return;
    _handleFlowResult(result);
  }

  Future<void> _submitOtp() async {
    final l10n = AppLocalizations.of(context);
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ref.read(forgotErrorMessageProvider.notifier).state = l10n.otpEnterCode;
      return;
    }

    final result =
        await ref.read(forgotCredentialsScreenVmProvider).submitOtp(otp: otp);
    if (!mounted || result == null) return;
    _handleFlowResult(result);
  }

  void _handleFlowResult(
    ResponseHandler<ForgotCredentialsFlowResult> result,
  ) {
    if (result is! Success<ForgotCredentialsFlowResult> ||
        result.data == null) {
      if (_step == _ForgotStep.otp) {
        _otpController.clear();
        _otpFocusNode.requestFocus();
      }
      setState(() {});
      return;
    }

    final flow = result.data!;
    if (flow is ForgotOtpRequired) {
      setState(() {
        _pending = flow.pending;
        _step = _ForgotStep.otp;
        _otpController.clear();
      });
      return;
    }

    if (flow is ForgotCredentialsComplete) {
      setState(() => _step = _ForgotStep.success);
    }
  }

  Future<void> _handleResendTap() async {
    final isLoading = ref.read(forgotIsLoadingProvider);
    if (isLoading) return;

    final l10n = AppLocalizations.of(context);
    final ok = await ref.read(forgotCredentialsScreenVmProvider).resendOtp();
    if (!mounted) return;

    if (!ok) {
      setState(() {});
      return;
    }

    _otpController.clear();
    _otpFocusNode.requestFocus();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.otpResendSuccess)),
    );
  }

  void _onBack() {
    final isLoading = ref.read(forgotIsLoadingProvider);
    if (isLoading) return;
    if (_step == _ForgotStep.otp) {
      setState(() => _step = _ForgotStep.details);
      return;
    }
    if (_step == _ForgotStep.success) {
      Navigator.of(context).pop();
      return;
    }
    _cancelFlow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final isLoading = ref.watch(forgotIsLoadingProvider);
    final errorMessage = ref.watch(forgotErrorMessageProvider);
    final title =
        _isUsername ? l10n.forgotUsernameTitle : l10n.forgotPasswordTitle;
    final subtitle = _isUsername
        ? l10n.forgotUsernameSubtitle
        : l10n.forgotPasswordSubtitle;

    return SecureScreen(
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        resizeToAvoidBottomInset: _step != _ForgotStep.otp,
        body: switch (_step) {
          _ForgotStep.details => AuthFormShell(
              onBack: isLoading ? null : _onBack,
              title: title,
              subtitle: subtitle,
              child: _buildDetailsForm(
                l10n,
                colors,
                isLoading,
                errorMessage,
              ),
            ),
          _ForgotStep.otp => _buildOtpStep(l10n, isLoading, errorMessage),
          _ForgotStep.success => AuthFlowSuccessPanel(
              title: l10n.forgotSuccessHeading,
              message: _isUsername
                  ? l10n.forgotUsernameSuccessMessage
                  : l10n.forgotPasswordSuccessMessage,
              loginLabel: l10n.forgotGoToLogin,
              onLogin: () => Navigator.of(context).pop(),
            ),
        },
      ),
    );
  }

  Widget _buildDetailsForm(
    AppLocalizations l10n,
    AppColors colors,
    bool isLoading,
    String? errorMessage,
  ) {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthLabeledField(
            label: _isUsername
                ? l10n.forgotEmailLabel
                : l10n.forgotUserNameLabel,
            hint: _isUsername
                ? l10n.forgotEmailHint
                : l10n.forgotUserNameHint,
            controller: _emailOrUserController,
            enabled: !isLoading,
            keyboardType: _isUsername
                ? TextInputType.emailAddress
                : TextInputType.text,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autovalidateMode: _isUsername
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return _isUsername
                    ? l10n.forgotEmailRequired
                    : l10n.forgotUserNameRequired;
              }
              if (_isUsername && !EmailValidator.isValid(trimmed)) {
                return l10n.registrationEmailInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          AuthLabeledDateField(
            label: l10n.forgotDateOfBirthLabel,
            enabled: !isLoading,
            placeholder: l10n.forgotDateOfBirthHint,
            valueText: _dateOfBirth == null ? '' : _displayDob(_dateOfBirth!),
            onTap: _pickDob,
          ),
          if (errorMessage != null && errorMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            AuthFormErrorBanner(message: errorMessage),
          ],
          const SizedBox(height: 24),
          AuthFormPrimaryButton(
            label: isLoading
                ? l10n.registrationSubmitting
                : l10n.forgotSubmit,
            isLoading: isLoading,
            onPressed: _submitDetails,
          ),
          const SizedBox(height: 28),
          _ForgotInfoNote(
            l10n: l10n,
            colors: colors,
            isUsername: _isUsername,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(
    AppLocalizations l10n,
    bool isLoading,
    String? errorMessage,
  ) {
    final pending = _pending;
    final responsive = Responsive.of(context);
    final compact = responsive.isCompactHeight;
    final hPad = responsive.formHorizontalPadding;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, compact ? 4 : 8, hPad, 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsive.formMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthScreenHeader(
                  onBack: isLoading
                      ? null
                      : () => setState(() => _step = _ForgotStep.details),
                ),
                SizedBox(height: compact ? 12 : 22),
                Expanded(
                  child: OtpChallengeBody(
                    title: l10n.forgotOtpTitle,
                    subtitle: l10n.forgotOtpSubtitle,
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    isLoading: isLoading,
                    attemptsLeft: pending?.challenge.attemptsLeft,
                    resendsLeft: pending?.challenge.resendsLeft,
                    referenceNumber: pending?.challenge.referenceNo,
                    errorMessage: errorMessage,
                    onSubmit: _submitOtp,
                    onResend: _handleResendTap,
                    submitLabel: l10n.forgotSubmit,
                    expandToFill: !compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotInfoNote extends StatelessWidget {
  const _ForgotInfoNote({
    required this.l10n,
    required this.colors,
    required this.isUsername,
  });

  final AppLocalizations l10n;
  final AppColors colors;
  final bool isUsername;

  @override
  Widget build(BuildContext context) {
    final question =
        isUsername ? l10n.forgotNoteQuestion : l10n.forgotPasswordNoteQuestion;
    final body =
        isUsername ? l10n.forgotNoteBody : l10n.forgotPasswordNoteBody;
    final support =
        isUsername ? l10n.forgotNoteSupport : l10n.forgotPasswordNoteSupport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.forgotNoteHeading,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          question,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          support,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
