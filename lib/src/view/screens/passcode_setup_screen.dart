import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/alternate_login_method.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_pin_pad.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_screen_header.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

const int kPasscodeLength = 6;

/// Create + confirm a 6-digit passcode for quick access.
class PasscodeSetupScreen extends ConsumerStatefulWidget {
  const PasscodeSetupScreen({super.key});

  @override
  ConsumerState<PasscodeSetupScreen> createState() =>
      _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends ConsumerState<PasscodeSetupScreen> {
  String _first = '';
  String _current = '';
  bool _confirming = false;
  bool _loading = false;
  String? _error;

  Future<void> _onDigit(String digit) async {
    if (_loading || _current.length >= kPasscodeLength) return;
    setState(() {
      _error = null;
      _current += digit;
    });
    if (_current.length < kPasscodeLength) return;

    if (!_confirming) {
      setState(() {
        _first = _current;
        _current = '';
        _confirming = true;
      });
      return;
    }

    if (_current != _first) {
      setState(() {
        _error = AppLocalizations.of(context).passcodeMismatch;
        _current = '';
        _first = '';
        _confirming = false;
      });
      return;
    }

    await _enroll(_current);
  }

  void _onBackspace() {
    if (_loading || _current.isEmpty) return;
    setState(() => _current = _current.substring(0, _current.length - 1));
  }

  Future<void> _enroll(String pin) async {
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context);
    final outcome =
        await ref.read(biometricEnrollmentProvider).enableWithLocalSecret(
              method: AlternateLoginMethod.passcode,
              secret: pin,
              l10n: l10n,
            );
    if (!mounted) return;
    setState(() => _loading = false);

    if (outcome.success && outcome.serverEnrolled) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _error = outcome.serverError ?? l10n.biometricAuthFailed;
      _current = '';
      _first = '';
      _confirming = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title =
        _confirming ? l10n.passcodeConfirmTitle : l10n.passcodeCreateTitle;
    final subtitle = _confirming
        ? l10n.passcodeConfirmSubtitle
        : l10n.passcodeCreateSubtitle;

    return SecureScreen(
      child: Scaffold(
        backgroundColor: AuthColors.screenBackground(context),
        body: SafeArea(
          child: AuthResponsiveScrollBody(
            builder: (context, responsive, compact) => [
              AuthScreenHeader(
                onBack: () => Navigator.of(context).pop(false),
              ),
              SizedBox(height: compact ? 12 : 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 22 : 24,
                  fontWeight: FontWeight.w600,
                  color: AuthColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AuthColors.textSecondary(context),
                  height: 1.45,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AuthColors.error(context),
                  ),
                ),
              ],
              if (compact)
                const SizedBox(height: 24)
              else
                const Spacer(),
              if (_loading)
                Center(
                  child: CircularProgressIndicator(
                    color: AuthColors.brand(context),
                  ),
                )
              else
                AuthPinPad(
                  length: _current.length,
                  maxLength: kPasscodeLength,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                ),
              if (compact)
                const SizedBox(height: 16)
              else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
