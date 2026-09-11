import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/account_type_option.dart';
import 'package:ubci_bank/src/core/models/registration_request.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/date_of_birth_format.dart';
import 'package:ubci_bank/src/core/utils/email_validator.dart';
import 'package:ubci_bank/src/core/utils/password_policy.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';
import 'package:ubci_bank/src/view/providers/registration_providers.dart';
import 'package:ubci_bank/src/view/providers/repository_providers.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_flow_success_panel.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_shell.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_labeled_field.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_challenge_body.dart';
import 'package:ubci_bank/src/view/widgets/auth/password_policy_checklist.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';
import 'package:ubci_bank/src/view/widgets/terms_and_conditions_sheet.dart';

enum _RegistrationStep { details, verification, credentials, success }

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _detailsFormKey = GlobalKey<FormState>();

  final _customerIdController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _debitCardController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  final _credentialsFormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _RegistrationStep _step = _RegistrationStep.details;
  DateTime? _dateOfBirth;
  bool _acceptedTerms = false;
  String? _selectedAccountType;
  List<AccountTypeOption> _accountTypes = [];
  bool _loadingAccountTypes = false;

  /// Whether OTP verification is required before credentials can be
  /// created. Driven by `tokenValid` on the `startRegistration` response —
  /// when the admin disables registration OTP, OBDX returns `tokenValid:
  /// true` immediately and the verification step is skipped.
  bool _otpRequired = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _createdUsername;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAccountTypes());
  }

  Future<void> _loadAccountTypes() async {
    setState(() => _loadingAccountTypes = true);
    final result =
        await ref.read(registrationRepositoryProvider).loadAccountTypes();
    if (!mounted) return;
    if (result is Success<List<AccountTypeOption>> && result.data != null) {
      setState(() {
        _accountTypes = result.data!;
        if (_accountTypes.isNotEmpty) {
          _selectedAccountType ??= _accountTypes.first.code;
        }
      });
    } else {
      // Fallback so the form remains usable when enumeration API is empty.
      setState(() {
        _accountTypes = const [
          AccountTypeOption(code: 'CSA', label: 'Demand Deposit'),
        ];
        _selectedAccountType ??= 'CSA';
      });
    }
    setState(() => _loadingAccountTypes = false);
  }

  @override
  void dispose() {
    RegistrationSessionHolder.instance.clear();
    unawaited(PreferenceHelper.getInstance().clearSession());
    _customerIdController.dispose();
    _accountNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _debitCardController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _dateOfBirth = picked);
  }

  Future<void> _continueDetails() async {
    final l10n = AppLocalizations.of(context);
    if (!(_detailsFormKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      ref.read(registrationErrorMessageProvider.notifier).state =
          l10n.registrationTermsRequired;
      return;
    }
    if (_dateOfBirth == null) {
      ref.read(registrationErrorMessageProvider.notifier).state =
          l10n.registrationDateOfBirthRequired;
      return;
    }
    if (_selectedAccountType == null || _selectedAccountType!.isEmpty) {
      ref.read(registrationErrorMessageProvider.notifier).state =
          l10n.registrationAccountTypeRequired;
      return;
    }

    final start = await ref.read(registrationScreenVmProvider).startRegistration(
          request: RegistrationRequest(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            emailId: _emailController.text.trim(),
            partyId: _customerIdController.text.trim(),
            dateOfBirth: DateOfBirthFormat.toApi(_dateOfBirth!),
            accountType: _selectedAccountType!,
            accountNumber: _accountNumberController.text.trim(),
            debitCardNumber: () {
              final value = _debitCardController.text.trim();
              return value.isEmpty ? null : value;
            }(),
          ),
          l10n: l10n,
        );

    if (!mounted || start == null) return;
    setState(() {
      _otpRequired = !start.tokenValid;
      _step = _otpRequired
          ? _RegistrationStep.verification
          : _RegistrationStep.credentials;
      _codeController.clear();
    });
  }

  Future<void> _submitVerification() async {
    final l10n = AppLocalizations.of(context);
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ref.read(registrationErrorMessageProvider.notifier).state =
          l10n.otpEnterCode;
      return;
    }

    final ok = await ref.read(registrationScreenVmProvider).verifyCode(
          code: code,
          l10n: l10n,
        );
    if (!mounted) return;
    if (!ok) {
      // Wrong code: clear pin so the user can retry (input stays enabled while
      // attempts remain).
      _codeController.clear();
      _codeFocusNode.requestFocus();
      return;
    }
    setState(() => _step = _RegistrationStep.credentials);
  }

  Future<void> _submitCredentials() async {
    final l10n = AppLocalizations.of(context);
    if (!(_credentialsFormKey.currentState?.validate() ?? false)) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final createdUsername = await ref
        .read(registrationScreenVmProvider)
        .createCredentials(username: username, password: password, l10n: l10n);

    if (!mounted || createdUsername == null) return;
    _createdUsername = createdUsername;
    setState(() => _step = _RegistrationStep.success);
  }

  Future<void> _resendCode() async {
    final l10n = AppLocalizations.of(context);
    final result =
        await ref.read(registrationScreenVmProvider).resendCode(l10n: l10n);
    if (!mounted || result == null) return;
    _codeController.clear();
    _codeFocusNode.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.registrationResendSuccess)),
    );
  }

  Future<void> _cancelFlow() async {
    await ref.read(registrationScreenVmProvider).abandon();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _goToLogin() {
    Navigator.of(context).pop(_createdUsername);
  }

  void _onBack() {
    final isLoading = ref.read(registrationIsLoadingProvider);
    if (isLoading) return;
    if (_step == _RegistrationStep.verification) {
      setState(() => _step = _RegistrationStep.details);
      return;
    }
    if (_step == _RegistrationStep.credentials) {
      setState(() {
        _step = _otpRequired
            ? _RegistrationStep.verification
            : _RegistrationStep.details;
      });
      return;
    }
    if (_step == _RegistrationStep.success) {
      _goToLogin();
      return;
    }
    _cancelFlow();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final isLoading = ref.watch(registrationIsLoadingProvider);
    final errorMessage = ref.watch(registrationErrorMessageProvider);

    return SecureScreen(
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        body: switch (_step) {
          _RegistrationStep.details => AuthFormShell(
              onBack: isLoading ? null : _onBack,
              title: l10n.registrationTitle,
              subtitle: l10n.registrationSubtitle,
              child: _buildDetailsForm(
                l10n,
                colors,
                isLoading,
                errorMessage,
              ),
            ),
          _RegistrationStep.verification => AuthFormShell(
              onBack: isLoading ? null : _onBack,
              child: _buildVerificationBody(l10n, isLoading, errorMessage),
            ),
          _RegistrationStep.credentials => AuthFormShell(
              onBack: isLoading ? null : _onBack,
              title: l10n.registrationCredentialsTitle,
              subtitle: l10n.registrationCredentialsSubtitle,
              child: _buildCredentialsForm(l10n, colors, isLoading, errorMessage),
            ),
          _RegistrationStep.success => AuthFlowSuccessPanel(
              title: l10n.registrationSuccess,
              message: l10n.registrationSuccessMessage,
              loginLabel: l10n.registrationGoToLogin,
              onLogin: _goToLogin,
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
    final responsive = Responsive.of(context);
    final sideBySideNames = !responsive.isPhone || responsive.width >= 520;

    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingAccountTypes)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: colors.brand,
                  backgroundColor: colors.divider,
                ),
              ),
            )
          else
            AuthLabeledDropdown<String>(
              key: ValueKey(
                'accountType-${_accountTypes.length}-$_selectedAccountType',
              ),
              label: l10n.registrationAccountType,
              hint: l10n.registrationAccountTypeHint,
              required: true,
              value: _selectedAccountType,
              enabled: !isLoading,
              items: _accountTypes
                  .map(
                    (type) => DropdownMenuItem(
                      value: type.code,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedAccountType = value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.registrationAccountTypeRequired;
                }
                return null;
              },
            ),
          const SizedBox(height: 12),
          AuthLabeledField(
            label: l10n.registrationCustomerId,
            hint: l10n.registrationCustomerIdHint,
            controller: _customerIdController,
            required: true,
            enabled: !isLoading,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.registrationCustomerIdRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          AuthLabeledField(
            label: l10n.registrationAccountNumber,
            hint: l10n.registrationAccountNumberHint,
            controller: _accountNumberController,
            required: true,
            enabled: !isLoading,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.registrationAccountNumberRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          if (sideBySideNames)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AuthLabeledField(
                    label: l10n.registrationFirstName,
                    hint: l10n.registrationFirstNameHint,
                    controller: _firstNameController,
                    required: true,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.registrationFirstNameRequired;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AuthLabeledField(
                    label: l10n.registrationLastName,
                    hint: l10n.registrationLastNameHint,
                    controller: _lastNameController,
                    required: true,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.registrationLastNameRequired;
                      }
                      return null;
                    },
                  ),
                ),
              ],
            )
          else ...[
            AuthLabeledField(
              label: l10n.registrationFirstName,
              hint: l10n.registrationFirstNameHint,
              controller: _firstNameController,
              required: true,
              enabled: !isLoading,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.registrationFirstNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            AuthLabeledField(
              label: l10n.registrationLastName,
              hint: l10n.registrationLastNameHint,
              controller: _lastNameController,
              required: true,
              enabled: !isLoading,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.registrationLastNameRequired;
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),
          AuthLabeledField(
            label: l10n.registrationEmail,
            controller: _emailController,
            hint: l10n.registrationEmailHint,
            required: true,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.registrationEmailRequired;
              }
              if (!EmailValidator.isValid(value)) {
                return l10n.registrationEmailInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          AuthLabeledDateField(
            label: l10n.registrationDateOfBirth,
            required: true,
            enabled: !isLoading,
            placeholder: l10n.registrationDateOfBirthHint,
            valueText: _dateOfBirth == null
                ? ''
                : DateOfBirthFormat.toDisplay(_dateOfBirth!),
            onTap: _pickDateOfBirth,
          ),
          const SizedBox(height: 12),
          AuthLabeledField(
            label: l10n.registrationDebitCardNumber,
            hint: l10n.registrationDebitCardHint,
            controller: _debitCardController,
            enabled: !isLoading,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
            ],
          ),
          const SizedBox(height: 18),
          _TermsRow(
            accepted: _acceptedTerms,
            enabled: !isLoading,
            colors: colors,
            prefix: l10n.registrationAgreeTermsPrefix,
            link: l10n.registrationTermsAndConditions,
            onChanged: (value) => setState(() => _acceptedTerms = value),
          ),
          if (errorMessage != null && errorMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            AuthFormErrorBanner(message: errorMessage),
          ],
          const SizedBox(height: 22),
          AuthFormPrimaryButton(
            label: isLoading
                ? l10n.registrationSubmitting
                : l10n.registrationSubmit,
            isLoading: isLoading,
            enabled: _acceptedTerms,
            onPressed: _continueDetails,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBody(
    AppLocalizations l10n,
    bool isLoading,
    String? errorMessage,
  ) {
    final attemptsLeft = ref.watch(registrationAttemptsLeftProvider);
    return OtpChallengeBody(
      title: l10n.forgotOtpTitle,
      subtitle: l10n.registrationVerificationSubtitle,
      controller: _codeController,
      focusNode: _codeFocusNode,
      isLoading: isLoading,
      attemptsLeft: attemptsLeft,
      errorMessage: errorMessage,
      expandToFill: false,
      onSubmit: _submitVerification,
      onResend: _resendCode,
      submitLabel: l10n.registrationVerifySubmit,
      verifyingLabel: l10n.registrationSubmitting,
      didntReceiveLabel: l10n.registrationDidNotGetCode,
      resendLabel: l10n.registrationResendCode,
    );
  }

  Widget _buildCredentialsForm(
    AppLocalizations l10n,
    AppColors colors,
    bool isLoading,
    String? errorMessage,
  ) {
    return Form(
      key: _credentialsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthLabeledField(
            label: l10n.registrationUsername,
            hint: l10n.registrationUsernameHint,
            controller: _usernameController,
            required: true,
            enabled: !isLoading,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (_) => setState(() {}),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return l10n.registrationUsernameRequired;
              }
              if (!PasswordPolicy.isUsernameValid(trimmed)) {
                return l10n.registrationUsernameInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          AuthLabeledField(
            label: l10n.registrationPassword,
            hint: l10n.registrationPasswordHint,
            controller: _passwordController,
            required: true,
            enabled: !isLoading,
            obscureText: _obscurePassword,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (_) => setState(() {}),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: colors.textSecondary,
                size: 20,
              ),
              onPressed: isLoading
                  ? null
                  : () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              final password = value ?? '';
              if (password.isEmpty) {
                return l10n.registrationPasswordRequired;
              }
              if (!PasswordPolicy.isPasswordValid(
                password,
                username: _usernameController.text,
              )) {
                return l10n.registrationPasswordTooShort;
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          // Rebuilds on every keystroke via the setState calls above/below so
          // the checklist stays live while typing.
          PasswordPolicyChecklist(
            password: _passwordController.text,
            username: _usernameController.text,
            title: l10n.registrationPasswordPolicyTitle,
            minLengthLabel: l10n.registrationPasswordRuleMinLength,
            uppercaseLabel: l10n.registrationPasswordRuleUppercase,
            lowercaseLabel: l10n.registrationPasswordRuleLowercase,
            numberLabel: l10n.registrationPasswordRuleNumber,
            specialCharLabel: l10n.registrationPasswordRuleSpecialChar,
            noUsernameLabel: l10n.registrationPasswordRuleNoUsername,
          ),
          const SizedBox(height: 12),
          AuthLabeledField(
            label: l10n.registrationConfirmPassword,
            hint: l10n.registrationConfirmPasswordHint,
            controller: _confirmPasswordController,
            required: true,
            enabled: !isLoading,
            obscureText: _obscureConfirmPassword,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => _submitCredentials(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: colors.textSecondary,
                size: 20,
              ),
              onPressed: isLoading
                  ? null
                  : () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return l10n.registrationConfirmPasswordRequired;
              }
              if (value != _passwordController.text) {
                return l10n.registrationPasswordMismatch;
              }
              return null;
            },
          ),
          if (errorMessage != null && errorMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            AuthFormErrorBanner(message: errorMessage),
          ],
          const SizedBox(height: 22),
          AuthFormPrimaryButton(
            label: isLoading
                ? l10n.registrationCredentialsSubmitting
                : l10n.registrationCredentialsSubmit,
            isLoading: isLoading,
            onPressed: _submitCredentials,
          ),
        ],
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({
    required this.accepted,
    required this.enabled,
    required this.colors,
    required this.prefix,
    required this.link,
    required this.onChanged,
  });

  final bool accepted;
  final bool enabled;
  final AppColors colors;
  final String prefix;
  final String link;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: accepted,
            onChanged: enabled ? (value) => onChanged(value ?? false) : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: enabled ? () => onChanged(!accepted) : null,
                      child: Text(
                        prefix,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: enabled
                          ? () => TermsAndConditionsSheet.show(context)
                          : null,
                      child: Text(
                        link,
                        style: TextStyle(
                          color: colors.brand,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: colors.brand,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
