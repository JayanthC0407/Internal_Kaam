import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/forgot_credentials_pending.dart';
import 'package:ubci_bank/src/core/models/login_flow_result.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/security/biometric_unlock_policy.dart';
import 'package:ubci_bank/src/infra/security/device_security_models.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/biometric_unlock_screen.dart';
import 'package:ubci_bank/src/view/screens/forgot_credentials_screen.dart';
import 'package:ubci_bank/src/view/screens/home_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/otp_login_screen.dart';
import 'package:ubci_bank/src/view/widgets/biometric_enrollment_prompt.dart';
import 'package:ubci_bank/src/view/widgets/login_help_dialog.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';
import 'package:ubci_bank/src/view/widgets/virtual_keyboard_dialog.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _logoAsset = 'assets/images/demobank_logo.png';

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _keepSignedIn = true;
  bool _canBiometricLogin = false;

  @override
  void initState() {
    super.initState();
    _prefillLastUserName();
    _loadLoginPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDeviceSecurityWarningIfNeeded();
    });
  }

  Future<void> _loadLoginPrefs() async {
    final prefs = ref.read(preferenceHelperProvider);
    final biometrics = ref.read(biometricServiceProvider);
    final keep = await prefs.isKeepSignedIn();
    final canBio = await BiometricUnlockPolicy.canOfferQuickLogin(
      preferences: prefs,
      biometrics: biometrics,
    );
    if (!mounted) return;
    setState(() {
      _keepSignedIn = keep;
      _canBiometricLogin = canBio;
    });
  }

  Future<void> _openForgotCredentials(ForgotCredentialsKind kind) async {
    await Navigator.of(context).pushNamed(
      RoutesConst.forgotCredentialsScreen,
      arguments: ForgotCredentialsArgs(kind: kind),
    );
  }

  Future<void> _loginWithBiometrics() async {
    final session = ref.read(sessionManagerProvider);
    final homeArgs = await session.buildHomeArgs();
    if (!mounted) return;
    Navigator.of(context).pushNamed(
      RoutesConst.biometricUnlockScreen,
      arguments: BiometricUnlockArgs(
        homeArgs: homeArgs,
        performTokenLogin: true,
      ),
    );
  }

  void _showDeviceSecurityWarningIfNeeded() {
    final threat = ref.read(pendingDeviceSecurityWarningProvider);
    if (threat == null || !mounted) return;

    ref.read(pendingDeviceSecurityWarningProvider.notifier).state = null;
    final l10n = AppLocalizations.of(context);
    final message = switch (threat) {
      DeviceThreatType.emulator => l10n.deviceSecurityWarnEmulator,
      DeviceThreatType.compromisedDevice => l10n.deviceSecurityWarnCompromised,
      DeviceThreatType.none => l10n.deviceSecurityWarnCompromised,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _prefillLastUserName() async {
    final lastUser = await ref.read(sessionManagerProvider).getLastUserName();
    if (!mounted || lastUser == null || lastUser.isEmpty) return;
    _usernameController.text = lastUser;
  }

  Future<void> _openRegistration() async {
    final result = await Navigator.of(context).pushNamed(
      RoutesConst.registrationScreen,
    );
    final registeredUserName = result is String ? result : null;
    if (!mounted || registeredUserName == null || registeredUserName.isEmpty) {
      return;
    }
    _usernameController.text = registeredUserName;
  }

  Future<void> _login() async {
    final vm = ref.read(loginScreenVmProvider);
    final isLoading = ref.read(loginIsLoadingProvider);
    if (isLoading) return;

    final l10n = AppLocalizations.of(context);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ref.read(loginErrorMessageProvider.notifier).state =
          l10n.pleaseEnterCredentials;
      return;
    }

    try {
      await ref.read(preferenceHelperProvider).setKeepSignedIn(_keepSignedIn);

      final result = await vm.login(userName: username, password: password);
      if (!mounted || result == null) return;

      if (result is Success<LoginFlowResult> && result.data != null) {
        final flow = result.data!;
        if (flow.needsOtp && flow.pending != null) {
          if (!kIsWeb) {
            await ref
                .read(preferenceHelperProvider)
                .savePendingBiometricEnrollment(
                  userName: username,
                  encryptedPassword:
                      flow.pending!.partialTrace.encryptedPassword,
                  plainPassword: password,
                );
          }
          if (!mounted) return;
          Navigator.of(context).pushNamed(
            RoutesConst.otpLoginScreen,
            arguments: OtpLoginArgs(pending: flow.pending!),
          );
          return;
        }
        if (flow.isComplete && flow.trace != null) {
          final statusCode =
              flow.trace!.loginResponse['statusCode'] as int? ?? 0;
          if (statusCode >= 200 && statusCode < 300) {
            if (!kIsWeb) {
              await ref
                  .read(preferenceHelperProvider)
                  .savePendingBiometricEnrollment(
                    userName: username,
                    encryptedPassword: flow.trace!.encryptedPassword,
                    plainPassword: password,
                  );
            }
            await ref.read(sessionManagerProvider).onLoginSuccess(
                  userName: username,
                  displayName: flow.trace!.displayName,
                );
            if (!mounted) return;
            if (!kIsWeb) {
              await BiometricEnrollmentPrompt.afterPasswordLogin(context, ref);
              if (!mounted) return;
            }
            Navigator.of(context).pushReplacementNamed(
              RoutesConst.homeScreen,
              arguments: HomeDashboardArgs(
                userName: username,
                loginTrace: flow.trace!.toSafeMap(),
              ),
            );
          }
        }
      }
    } catch (_) {
      if (!mounted) return;
      ref.read(loginErrorMessageProvider.notifier).state = l10n.errorUnexpected;
    }
  }

  void _handleHelpTap() {
    LoginHelpDialog.show(context);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = ref.watch(loginIsLoadingProvider);
    final errorMessage = ref.watch(loginErrorMessageProvider);
    final responsive = Responsive.of(context);
    final colors = AppColors.of(context);

    return SecureScreen(
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        body: responsive.useWideLayout
            ? _buildDesktopLayout(
                l10n, isLoading, errorMessage, colors, responsive)
            : _buildMobileLayout(
                l10n, isLoading, errorMessage, colors, responsive),
      ),
    );
  }

  Widget _buildDesktopLayout(
    AppLocalizations l10n,
    bool isLoading,
    String? errorMessage,
    AppColors colors,
    Responsive responsive,
  ) {
    final form = _buildLoginForm(
      l10n: l10n,
      isLoading: isLoading,
      errorMessage: errorMessage,
      colors: colors,
      desktopMode: true,
      compact: responsive.isCompactHeight,
    );

    return Row(
      children: [
        if (responsive.width >= 1000)
          Expanded(
            child: Container(
decoration: BoxDecoration(
  gradient: AppGradients.primary(context),
),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    responsive.isCompactHeight ? 28 : 52,
                    responsive.isCompactHeight ? 24 : 54,
                    responsive.isCompactHeight ? 28 : 52,
                    40,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).vertical -
                          80,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDesktopBrand(),
                        SizedBox(height: responsive.isCompactHeight ? 28 : 70),
                        Text(
                          l10n.loginDesktopHeadline,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: responsive.isCompactHeight ? 34 : 50,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: Text(
                            l10n.loginDesktopSubtitle,
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(height: responsive.isCompactHeight ? 24 : 48),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 390),
                          decoration: BoxDecoration(
                            color: const Color(0x10FFFFFF),
                            border: Border.all(color: const Color(0x22FFFFFF)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.loginCashbackBadge,
                                style: const TextStyle(
                                  color: Color(0xAAFFFFFF),
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.loginCashbackDetail,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: Container(
            color: colors.scaffoldBg,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      responsive.width < 1000 ? 20 : 26,
                      responsive.isCompactHeight ? 12 : 22,
                      responsive.width < 1000 ? 20 : 26,
                      16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 38,
                        maxWidth: 410,
                      ),
                      child: Center(child: form),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    AppLocalizations l10n,
    bool isLoading,
    String? errorMessage,
    AppColors colors,
    Responsive responsive,
  ) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              responsive.isLandscape && constraints.maxHeight < 560;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              landscape ? 24 : 16,
              landscape ? 8 : 16,
              landscape ? 24 : 16,
              20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: responsive.formMaxWidth),
                child: _buildLoginForm(
                  l10n: l10n,
                  isLoading: isLoading,
                  errorMessage: errorMessage,
                  colors: colors,
                  desktopMode: false,
                  compact: landscape,
                  showTopLogo: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginForm({
    required AppLocalizations l10n,
    required bool isLoading,
    required String? errorMessage,
    required AppColors colors,
    required bool desktopMode,
    required bool compact,
    bool showTopLogo = false,
  }) {
    final brand = colors.brand;
    final textPrimary = colors.textPrimary;
    final textSecondary = colors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTopLogo) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLogo(brand),
              TextButton(
                onPressed: _handleHelpTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.help,
                  style: TextStyle(
                    fontSize: 12,
                    color: brand,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 22),
        ] else ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleHelpTap,
              style: TextButton.styleFrom(
                foregroundColor: brand,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
              child: Text(l10n.help),
            ),
          ),
          SizedBox(height: compact ? 12 : 40),
        ],
        Text(
          l10n.welcome,
          style: TextStyle(
            fontSize: desktopMode ? (compact ? 32 : 40) : (compact ? 32 : 40),
            fontWeight: desktopMode ? FontWeight.w800 : FontWeight.w600,
            color: textPrimary,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.loginSubtitle,
          style: TextStyle(
            fontSize: 14,
            color: textSecondary,
            height: 1.4,
          ),
        ),
        SizedBox(height: compact ? 14 : 24),
        _buildCredentialFields(l10n, colors, desktopMode: desktopMode),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _keepSignedIn,
                onChanged: (value) =>
                    setState(() => _keepSignedIn = value ?? true),
                activeColor: brand,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: colors.inputBorder),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: GestureDetector(
                onTap: () => setState(() => _keepSignedIn = !_keepSignedIn),
                child: Text(
                  l10n.keepMeSignedIn,
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () =>
                    _openForgotCredentials(ForgotCredentialsKind.password),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  l10n.forgotPassword,
                  style: TextStyle(
                    color: brand,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(
                '|',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openForgotCredentials(ForgotCredentialsKind.username),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  l10n.forgotUsername,
                  style: TextStyle(
                    color: brand,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: brand,
            foregroundColor: Colors.white,
            disabledBackgroundColor: brand.withValues(alpha: 0.6),
            minimumSize: Size.fromHeight(desktopMode ? 50 : 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(desktopMode ? 12 : 8),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  l10n.login,
                  style: TextStyle(
                    fontSize: desktopMode ? 15 : 16,
                    fontWeight: desktopMode ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
        ),
        if (_canBiometricLogin) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLoading ? null : _loginWithBiometrics,
            icon: Icon(Icons.fingerprint, color: brand),
            label: Text(
              l10n.loginWithBiometrics,
              style: TextStyle(color: brand, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(desktopMode ? 50 : 48),
              side: BorderSide(color: brand),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(desktopMode ? 12 : 8),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.notRegistered,
              style: TextStyle(fontSize: 13, color: textSecondary),
            ),
            TextButton(
              onPressed: _openRegistration,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.registerHere,
                style: TextStyle(
                  fontSize: 13,
                  color: brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildErrorCard(errorMessage),
        ],
        if (desktopMode) ...[
          SizedBox(height: compact ? 24 : 40),
          Center(
            child: Text(
              '(c) Demo - Secured by 256-bit TLS',
              style: TextStyle(
                fontSize: 11,
                color: colors.navInactive,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCredentialFields(
    AppLocalizations l10n,
    AppColors colors, {
    bool desktopMode = false,
  }) {
    final isLoading = ref.watch(loginIsLoadingProvider);
    final labelStyle = TextStyle(
      fontSize: desktopMode ? 13 : 12,
      fontWeight: desktopMode ? FontWeight.w600 : FontWeight.w400,
      color: colors.textPrimary,
    );
    final borderColor = colors.inputBorder;
    final fillColor = colors.inputBackground;
    final showVirtualKeyboard = kIsWeb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.username, style: labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: _usernameController,
          enabled: !isLoading,
          decoration: _inputDecoration(
            hintText: l10n.enterUsername,
            colors: colors,
            fillColor: fillColor,
            borderColor: borderColor,
            borderRadius: desktopMode ? 10 : 8,
            suffixIcon: showVirtualKeyboard
                ? VirtualKeyboardIconButton(
                    controller: _usernameController,
                    enabled: !isLoading,
                  )
                : null,
          ),
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 12),
        Text(l10n.password, style: labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          enabled: !isLoading,
          obscureText: _obscurePassword,
          decoration: _inputDecoration(
            hintText: l10n.enterPassword,
            colors: colors,
            fillColor: fillColor,
            borderColor: borderColor,
            borderRadius: desktopMode ? 10 : 8,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                  onPressed: isLoading
                      ? null
                      : () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
                if (showVirtualKeyboard)
                  VirtualKeyboardIconButton(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !isLoading,
                  ),
              ],
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
        ),
      ],
    );
  }

  Widget _buildDesktopBrand() {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        _logoAsset,
        height: 46,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(
          l10n.brandName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required AppColors colors,
    required Color fillColor,
    required Color borderColor,
    double borderRadius = 8,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: colors.inputHint,
        fontSize: 14,
      ),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(color: colors.brand),
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints:
          suffixIcon == null ? null : const BoxConstraints(minHeight: 48),
    );
  }

  Widget _buildLogo(Color brand) {
    final l10n = AppLocalizations.of(context);
    return Image.asset(
      height: 32,
      _logoAsset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        l10n.brandName,
        style: TextStyle(
          color: brand,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
