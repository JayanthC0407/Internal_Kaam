import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/screens/common/auth/auth_colors.dart';
// Passcode / pattern temporarily hidden from quick-access setup.
// import 'package:ubci_bank/src/view/screens/common/auth/passcode_setup_screen.dart';
// import 'package:ubci_bank/src/view/screens/common/auth/pattern_setup_screen.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_shell.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_quick_access_option.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_secondary_button.dart';
import 'package:ubci_bank/src/view/widgets/biometric_enrollment_prompt.dart';
import 'package:ubci_bank/src/view/widgets/biometric_ui_copy.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

/// Full-screen quick-access setup matching the corporate banking design.
class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() =>
      _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  bool _loading = false;
  BiometricPresentation _presentation = BiometricPresentation.android;

  @override
  void initState() {
    super.initState();
    _loadPresentation();
  }

  Future<void> _loadPresentation() async {
    final presentation =
        await ref.read(biometricServiceProvider).presentation();
    if (!mounted) return;
    setState(() => _presentation = presentation);
  }

  /// Same steps as the "Enable Alternate Login" sheet — see
  /// [BiometricEnrollmentPrompt.enableNow].
  Future<void> _enableBiometric() async {
    if (_loading) return;
    setState(() => _loading = true);
    final enrolled = await BiometricEnrollmentPrompt.enableNow(context, ref);
    if (!mounted) return;
    setState(() => _loading = false);
    if (enrolled) Navigator.of(context).pop(true);
  }

  // Future<void> _enablePasscode() async {
  //   if (_loading) return;
  //   final ok = await Navigator.of(context).push<bool>(
  //     MaterialPageRoute(builder: (_) => const PasscodeSetupScreen()),
  //   );
  //   if (!mounted) return;
  //   if (ok == true) Navigator.of(context).pop(true);
  // }

  // Future<void> _enablePattern() async {
  //   if (_loading) return;
  //   final ok = await Navigator.of(context).push<bool>(
  //     MaterialPageRoute(builder: (_) => const PatternSetupScreen()),
  //   );
  //   if (!mounted) return;
  //   if (ok == true) Navigator.of(context).pop(true);
  // }

  void _skip() {
    if (_loading) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = Responsive.of(context).isCompactHeight;

    return SecureScreen(
      child: Scaffold(
        backgroundColor: AuthColors.screenBackground(context),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AuthFormShell(
                onBack: _skip,
                title: l10n.biometricSetupTitle,
                subtitle: l10n.biometricSetupSubtitle,
                bottomInset: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AuthColors.surfaceLevel0(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          AuthQuickAccessOption(
                            icon: BiometricUiCopy.icon(_presentation),
                            label: BiometricUiCopy.enableLabel(
                              l10n,
                              _presentation,
                            ),
                            subtitle: BiometricUiCopy.helperText(
                              l10n,
                              _presentation,
                            ),
                            onTap: _loading ? () {} : _enableBiometric,
                            showDivider: false,
                          ),
                          // AuthQuickAccessOption(
                          //   icon: Icons.pattern_rounded,
                          //   label: l10n.biometricOptionPattern,
                          //   onTap: _loading ? () {} : _enablePattern,
                          //   showDivider: false,
                          // ),
                        ],
                      ),
                    ),
                    if (_loading) ...[
                      SizedBox(height: compact ? 16 : 24),
                      Center(
                        child: CircularProgressIndicator(
                          color: AuthColors.brand(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.of(context).formHorizontalPadding,
                  0,
                  Responsive.of(context).formHorizontalPadding,
                  16,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: Responsive.of(context).formMaxWidth,
                    ),
                    child: AuthSecondaryButton(
                      label: l10n.biometricSkipForNow,
                      onPressed: _loading ? null : _skip,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
