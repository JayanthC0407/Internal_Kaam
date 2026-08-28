import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/alternate_login_method.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/infra/security/alternate_login_crypto.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_pattern_lock.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_screen_header.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';

/// Create + confirm a pattern for quick access.
class PatternSetupScreen extends ConsumerStatefulWidget {
  const PatternSetupScreen({super.key});

  @override
  ConsumerState<PatternSetupScreen> createState() => _PatternSetupScreenState();
}

class _PatternSetupScreenState extends ConsumerState<PatternSetupScreen> {
  final _patternKey = GlobalKey<AuthPatternLockState>();
  List<int>? _first;
  bool _confirming = false;
  bool _loading = false;
  String? _error;

  Future<void> _onPattern(List<int> dots) async {
    if (_loading) return;
    final secret = AlternateLoginCrypto.patternSecret(dots);

    if (!_confirming) {
      setState(() {
        _first = List<int>.from(dots);
        _confirming = true;
        _error = null;
      });
      _patternKey.currentState?.reset();
      return;
    }

    final firstSecret =
        AlternateLoginCrypto.patternSecret(_first ?? const <int>[]);
    if (secret != firstSecret) {
      setState(() {
        _error = AppLocalizations.of(context).patternMismatch;
        _first = null;
        _confirming = false;
      });
      _patternKey.currentState?.reset();
      return;
    }

    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context);
    final outcome =
        await ref.read(biometricEnrollmentProvider).enableWithLocalSecret(
              method: AlternateLoginMethod.pattern,
              secret: secret,
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
      _first = null;
      _confirming = false;
    });
    _patternKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title =
        _confirming ? l10n.patternConfirmTitle : l10n.patternCreateTitle;
    final subtitle = _confirming
        ? l10n.patternConfirmSubtitle
        : l10n.patternCreateSubtitle;

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
                Center(
                  child: AuthPatternLock(
                    key: _patternKey,
                    onCompleted: _onPattern,
                  ),
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
