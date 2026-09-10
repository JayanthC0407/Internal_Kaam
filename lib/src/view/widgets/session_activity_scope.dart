import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/utils/user_type_resolver.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/infra/service/navigation_service.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/corporate_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/home_dashboard_screen.dart';

/// Records user activity and enforces idle session timeout on resume.
class SessionActivityScope extends ConsumerStatefulWidget {
  const SessionActivityScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionActivityScope> createState() =>
      _SessionActivityScopeState();
}

class _SessionActivityScopeState extends ConsumerState<SessionActivityScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock only on paused (true backgrounding). BiometricPrompt and
    // FLAG_SECURE toggles fire `inactive` without leaving the app.
    if (state == AppLifecycleState.paused) {
      _maybeLockForBiometrics();
    }
    if (state == AppLifecycleState.resumed) {
      _validateSessionOnResume();
    }
  }

  Future<void> _maybeLockForBiometrics() async {
    if (kIsWeb) return;
    // System biometric dialog can briefly pause the activity; do not re-lock.
    if (BiometricService.isAuthInProgress) return;
    final session = ref.read(sessionManagerProvider);
    final preferences = ref.read(preferenceHelperProvider);
    if (!await preferences.isBiometricEnabled()) return;
    if (!await session.isAuthenticated()) return;
    if (await session.isSessionExpired()) return;
    if (BiometricService.isAuthInProgress) return;
    ref.read(biometricLockProvider.notifier).state = true;
  }

  Future<void> _validateSessionOnResume() async {
    final session = ref.read(sessionManagerProvider);
    if (!await session.isAuthenticated()) return;

    if (await session.isSessionExpired()) {
      await session.logout();
      _navigateToLogin();
    } else {
      await session.recordActivity();
    }
  }

  void _navigateToLogin() {
    final nav = NavigationService.globalAppNav.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil(
      RoutesConst.loginScreen,
      (route) => false,
    );
  }

  void _onUserInteraction() {
    ref.read(sessionManagerProvider).recordActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserInteraction(),
      child: widget.child,
    );
  }
}

/// Ensures only authenticated users can view the home dashboard.
class AuthenticatedHomeGate extends ConsumerStatefulWidget {
  const AuthenticatedHomeGate({super.key, required this.args});

  final HomeDashboardArgs args;

  @override
  ConsumerState<AuthenticatedHomeGate> createState() =>
      _AuthenticatedHomeGateState();
}

class _AuthenticatedHomeGateState extends ConsumerState<AuthenticatedHomeGate> {
  @override
  Widget build(BuildContext context) {
    return AuthenticatedSessionGate(
      child: _resolveDashboard(),
    );
  }

  /// Picks Retail vs Corporate dashboard from the `me` response captured on
  /// login: matches `dashboardResponse.dashboardDTOs[].dashboardClassValue`
  /// against `userProfile.roles` (not just `dashboardDTOs[0]` — a user can
  /// have multiple dashboard DTOs, e.g. a factory `Customer` dashboard
  /// alongside `retailuser`), falling back to `userProfile.roles` directly
  /// only when `dashboardDTOs` is empty. See API Flow & Implementation doc,
  /// §6 "Dashboard Selection Logic" and §19–20 "Critical Dashboard Selection
  /// Rule" / "Updated User-Type Resolution Algorithm".
  ///
  /// Username/email is never used to decide the dashboard. When resolution
  /// is unavailable or the type is unrecognized, this falls back to the
  /// existing Retail dashboard so current behavior is preserved.
  Widget _resolveDashboard() {
    final profileResponse =
        widget.args.loginTrace?['profileResponse'] as Map<String, dynamic>?;
    final userType = resolveUserType(profileResponse);

    if (userType == UserType.corporate) {
      return CorporateDashboardScreen(args: widget.args);
    }
    return HomeDashboardScreen(args: widget.args);
  }
}

/// Blocks protected screens until the session is authenticated and not idle-expired.
class AuthenticatedSessionGate extends ConsumerStatefulWidget {
  const AuthenticatedSessionGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthenticatedSessionGate> createState() =>
      _AuthenticatedSessionGateState();
}

class _AuthenticatedSessionGateState
    extends ConsumerState<AuthenticatedSessionGate> {
  bool _checking = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final session = ref.read(sessionManagerProvider);
    final authed = await session.isAuthenticated();
    final expired = authed && await session.isSessionExpired();

    if (!mounted) return;

    if (!authed || expired) {
      if (expired) await session.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(RoutesConst.loginScreen);
      return;
    }

    await session.recordActivity();
    setState(() {
      _checking = false;
      _allowed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_allowed) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return widget.child;
  }
}
