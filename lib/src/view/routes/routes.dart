import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/infra/security/device_security_models.dart';
import 'package:ubci_bank/src/view/screens/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/casa_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_repayment_screen.dart';
import 'package:ubci_bank/src/view/screens/biometric_setup_screen.dart';
import 'package:ubci_bank/src/view/screens/biometric_unlock_screen.dart';
import 'package:ubci_bank/src/view/screens/device_blocked_screen.dart';
import 'package:ubci_bank/src/view/screens/forgot_credentials_screen.dart';
import 'package:ubci_bank/src/view/screens/home_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/login_screen.dart';
import 'package:ubci_bank/src/view/screens/otp_login_screen.dart';
import 'package:ubci_bank/src/view/screens/payees/add_bank_account_payee_screen.dart';
import 'package:ubci_bank/src/view/screens/payees/payees_screen.dart';
import 'package:ubci_bank/src/view/screens/registration_screen.dart';
import 'package:ubci_bank/src/view/screens/splash_screen.dart';
import 'package:ubci_bank/src/view/widgets/session_activity_scope.dart';

class Routes {
  Routes._();

  static const Duration pageAnimDuration = Duration(milliseconds: 300);

  /// Splash fallback for web reload / deep links that land on a route which
  /// requires arguments (e.g. `/home_screen`) but has none. Splash re-resolves
  /// auth state and navigates to the correct screen, avoiding a null route
  /// (which would fall back to `/` and crash the widget tree).
  static Route<dynamic> _splashFallback(RouteSettings routeSettings) {
    return PageTransition(
      settings: const RouteSettings(name: RoutesConst.splashScreen),
      child: const SplashScreen(),
      type: PageTransitionType.fade,
      duration: pageAnimDuration,
    );
  }

  /// Handles routes with no matching generator (web unknown/`/` fallback).
  static Route<dynamic> onUnknownRoute(RouteSettings routeSettings) =>
      _splashFallback(routeSettings);

  static Route<dynamic>? onGenerateRoutes(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/':
      case RoutesConst.splashScreen:
        return PageTransition(
          settings: routeSettings,
          child: const SplashScreen(),
          type: PageTransitionType.fade,
          duration: pageAnimDuration,
        );
      case RoutesConst.loginScreen:
        return PageTransition(
          settings: routeSettings,
          child: const LoginScreen(),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.registrationScreen:
        return PageTransition(
          settings: routeSettings,
          child: const RegistrationScreen(),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.forgotCredentialsScreen:
        final forgotArgs = routeSettings.arguments;
        if (forgotArgs is ForgotCredentialsArgs) {
          return PageTransition(
            settings: routeSettings,
            child: ForgotCredentialsScreen(kind: forgotArgs.kind),
            type: PageTransitionType.rightToLeft,
            duration: pageAnimDuration,
          );
        }
        return _splashFallback(routeSettings);
      case RoutesConst.otpLoginScreen:
        final args = routeSettings.arguments;
        if (args is OtpLoginArgs) {
          return PageTransition(
            settings: routeSettings,
            child: OtpLoginScreen(pending: args.pending),
            type: PageTransitionType.rightToLeft,
            duration: pageAnimDuration,
          );
        }
        return _splashFallback(routeSettings);
      case RoutesConst.biometricSetupScreen:
        // Biometrics / quick access are mobile-only (Phase 1).
        if (kIsWeb) return _splashFallback(routeSettings);
        return PageTransition(
          settings: routeSettings,
          child: const BiometricSetupScreen(),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.biometricUnlockScreen:
        if (kIsWeb) return _splashFallback(routeSettings);
        final unlockArgs = routeSettings.arguments;
        if (unlockArgs is BiometricUnlockArgs) {
          return PageTransition(
            settings: routeSettings,
            child: BiometricUnlockScreen(args: unlockArgs),
            type: PageTransitionType.fade,
            duration: pageAnimDuration,
          );
        }
        return _splashFallback(routeSettings);
      case RoutesConst.homeScreen:
        final args = routeSettings.arguments;
        if (args is HomeDashboardArgs) {
          return PageTransition(
            settings: routeSettings,
            child: AuthenticatedHomeGate(args: args),
            type: PageTransitionType.rightToLeft,
            duration: pageAnimDuration,
          );
        }
        // Web reload / deep link with no args → resolve auth via splash.
        return _splashFallback(routeSettings);
      case RoutesConst.casaAccountDetailsScreen:
        final detailsArgs = routeSettings.arguments;
        if (detailsArgs is CasaAccountDetailsArgs) {
          return PageTransition(
            settings: routeSettings,
            child: AuthenticatedSessionGate(
              child: CasaAccountDetailsScreen(
                accountId: detailsArgs.accountId,
              ),
            ),
            type: PageTransitionType.rightToLeft,
            duration: pageAnimDuration,
          );
        }
        return _splashFallback(routeSettings);
      case RoutesConst.casaTransactionsScreen:
        final txArgs = routeSettings.arguments;
        if (txArgs is CasaTransactionsArgs) {
          return PageTransition(
            settings: routeSettings,
            child: AuthenticatedSessionGate(
              child: CasaTransactionsScreen(accountId: txArgs.accountId),
            ),
            type: PageTransitionType.rightToLeft,
            duration: pageAnimDuration,
          );
        }
        return _splashFallback(routeSettings);
      case RoutesConst.payeesScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: PayeesScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.addBankAccountPayeeScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: AddBankAccountPayeeScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.loanAccountsListScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: LoanAccountsListScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.loanAccountDetailsScreen:
        final loanArgs = routeSettings.arguments;
        if (loanArgs is LoanAccountDetailsArgs) {
          return PageTransition(
            settings: routeSettings,
            child: AuthenticatedSessionGate(
              child: LoanAccountDetailsScreen(args: loanArgs),
            ),
            type: PageTransitionType.rightToLeft,
            duration: pageAnimDuration,
          );
        }
        return _splashFallback(routeSettings);
      case RoutesConst.loanRepaymentScreen:
        final repaymentArgs = routeSettings.arguments;
        if (repaymentArgs is LoanRepaymentArgs) {
          return PageTransition(
            settings: routeSettings,
            child: AuthenticatedSessionGate(
              child: LoanRepaymentScreen(args: repaymentArgs),
            ),
            type: PageTransitionType.rightToLeft,
            duration: pageAnimDuration,
          );
        }
        return _splashFallback(routeSettings);
      case RoutesConst.deviceBlockedScreen:
        final threat = routeSettings.arguments;
        if (threat is DeviceThreatType) {
          return PageTransition(
            settings: routeSettings,
            child: DeviceBlockedScreen(threatType: threat),
            type: PageTransitionType.fade,
            duration: pageAnimDuration,
          );
        }
        return PageTransition(
          settings: routeSettings,
          child: const DeviceBlockedScreen(
            threatType: DeviceThreatType.compromisedDevice,
          ),
          type: PageTransitionType.fade,
          duration: pageAnimDuration,
        );
      default:
        return _splashFallback(routeSettings);
    }
  }
}
