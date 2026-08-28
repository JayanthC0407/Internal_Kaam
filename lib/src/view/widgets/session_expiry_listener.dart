import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/infra/service/navigation_service.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/widgets/session_expired_dialog.dart';

/// Listens for [SessionExpiryCoordinator] events from Dio and shows a
/// localized dialog, then routes to password login.
///
/// Biometric enrollment is kept. This dialog always goes to password login
/// (not biometric unlock). A rejected biometric setup token is cleared only
/// when OBDX rejects token login.
class SessionExpiryListener extends ConsumerStatefulWidget {
  const SessionExpiryListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionExpiryListener> createState() =>
      _SessionExpiryListenerState();
}

class _SessionExpiryListenerState extends ConsumerState<SessionExpiryListener> {
  StreamSubscription<void>? _subscription;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _subscription =
        SessionExpiryCoordinator.instance.events.listen((_) => _onExpired());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _onExpired() async {
    if (!mounted || _dialogVisible) return;

    // Drop biometric lock overlay — JWT is gone; unlock would be meaningless.
    ref.read(biometricLockProvider.notifier).state = false;

    final nav = NavigationService.globalAppNav.currentState;
    final context = nav?.context;
    if (context == null || !context.mounted) {
      await _navigateToPasswordLogin();
      return;
    }

    // Already on an auth entry screen — just ensure stack is clean.
    final routeName = ModalRoute.of(context)?.settings.name;
    if (routeName == RoutesConst.loginScreen ||
        routeName == RoutesConst.biometricUnlockScreen ||
        routeName == RoutesConst.splashScreen) {
      await _navigateToPasswordLogin();
      return;
    }

    _dialogVisible = true;
    final l10n = AppLocalizations.of(context);
    await SessionExpiredDialog.show(
      context,
      title: l10n.sessionExpiredTitle,
      message: l10n.errorSessionExpired,
      actionLabel: l10n.sessionExpiredSignIn,
    );
    _dialogVisible = false;
    await _navigateToPasswordLogin();
  }

  Future<void> _navigateToPasswordLogin() async {
    // Keep biometric enrollment. Session JWT is already cleared by the
    // interceptor; password login restores a session. Token login is only
    // invalidated when OBDX rejects the setup token (see biometric repository).
    final nav = NavigationService.globalAppNav.currentState;
    nav?.pushNamedAndRemoveUntil(
      RoutesConst.loginScreen,
      (route) => false,
    );
    SessionExpiryCoordinator.instance.reset();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
