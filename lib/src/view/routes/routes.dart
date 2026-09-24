import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:ubci_bank/src/core/models/common/own_account_transfer.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/infra/security/device_security_models.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/casa_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_account_details_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_accounts_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_repayment_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/loan_transactions_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/biometric_setup_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/biometric_unlock_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/device_blocked_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/forgot_credentials_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/login_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/login_wizard_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/otp_login_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payees/add_bank_account_payee_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payees/add_demand_draft_payee_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payees/add_peer_to_peer_payee_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payees/payee_hub_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payees/payees_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/adhoc_payee_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/internal_payment_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/international_payment_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/transfer_money_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/transfers_module_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/registration_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/splash_screen.dart';
import 'package:ubci_bank/src/view/screens/common/transfer/own_account_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/common/transfer/transfer_success_screen.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';
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

  /// Routes that replace the whole app rather than open a screen inside it:
  /// sign-in and its steps, device checks, and the dashboards themselves.
  ///
  /// These always belong to the root navigator. The web dashboards host
  /// their content in a nested navigator (`SidebarContentNavigator`), and
  /// one of these opened there would put a login screen, or a second
  /// dashboard, next to the side menu.
  static const Set<String> appLevelRoutes = {
    '/',
    RoutesConst.splashScreen,
    RoutesConst.loginScreen,
    RoutesConst.registrationScreen,
    RoutesConst.forgotCredentialsScreen,
    RoutesConst.otpLoginScreen,
    RoutesConst.loginWizardScreen,
    RoutesConst.biometricSetupScreen,
    RoutesConst.biometricUnlockScreen,
    RoutesConst.deviceBlockedScreen,
    RoutesConst.homeScreen,
    CorpRoutesConst.corpDashboardScreen,
  };

  /// Handles routes with no matching generator (web unknown/`/` fallback).
  static Route<dynamic> onUnknownRoute(RouteSettings routeSettings) =>
      _splashFallback(routeSettings);

  static Route<dynamic>? onGenerateRoutes(RouteSettings routeSettings) {
    // Corporate routes live in their own table (see [CorpRoutes]); a null
    // result there means "needs arguments it wasn't given", which gets the
    // same splash fallback every argument-taking route below uses.
    final name = routeSettings.name;
    if (name != null && CorpRoutesConst.all.contains(name)) {
      return CorpRoutes.onGenerateRoute(routeSettings) ??
          _splashFallback(routeSettings);
    }

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
      case RoutesConst.loginWizardScreen:
        // First-time Login Flow Wizard (LFW) — ported from vendor branch.
        final wizardArgs = routeSettings.arguments;
        if (wizardArgs is LoginWizardArgs) {
          return PageTransition(
            settings: routeSettings,
            child: LoginWizardScreen(args: wizardArgs),
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
      case RoutesConst.casaAccountsListScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: CasaAccountsListScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
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
      case RoutesConst.loanTransactionsScreen:
        final loanTxArgs = routeSettings.arguments;
        if (loanTxArgs is LoanTransactionsArgs) {
          return PageTransition(
            settings: routeSettings,
            child: AuthenticatedSessionGate(
              child: LoanTransactionsScreen(args: loanTxArgs),
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
      case RoutesConst.addDemandDraftPayeeScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: AddDemandDraftPayeeScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.addPeerToPeerPayeeScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: AddPeerToPeerPayeeScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.payeeHubScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: PayeeHubScreen(),
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
      case RoutesConst.internalPaymentScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: InternalPaymentScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.internationalPaymentScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: InternationalPaymentScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.transfersModuleScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: TransfersModuleScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.transferMoneyScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: TransferMoneyScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.adhocPayeeTransferScreen:
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: AdhocPayeeTransferScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.ownAccountTransferScreen:
        // Own-account transfer — ported from vendor branch. Distinct from
        // the Payments module above (transfersModuleScreen/transferMoneyScreen).
        return PageTransition(
          settings: routeSettings,
          child: const AuthenticatedSessionGate(
            child: OwnAccountTransferScreen(),
          ),
          type: PageTransitionType.rightToLeft,
          duration: pageAnimDuration,
        );
      case RoutesConst.transferSuccessScreen:
        final successArgs = routeSettings.arguments;
        if (successArgs is TransferConfirmationSnapshot) {
          return PageTransition(
            settings: routeSettings,
            child: AuthenticatedSessionGate(
              child: SecureScreen(
                child: TransferSuccessScreen(snapshot: successArgs),
              ),
            ),
            type: PageTransitionType.fade,
            duration: pageAnimDuration,
          );
        }
        if (successArgs is TransferSubmitResult) {
          return PageTransition(
            settings: routeSettings,
            child: AuthenticatedSessionGate(
              child: SecureScreen(
                child: TransferSuccessScreen(
                  snapshot: TransferConfirmationSnapshot(
                    result: successArgs,
                    toMask: '',
                    toMeta: '',
                    fromMask: '',
                    fromMeta: '',
                    payBy: '',
                    amountText: '',
                    whenText: '',
                    chargesMask: '',
                    chargesMeta: '',
                  ),
                ),
              ),
            ),
            type: PageTransitionType.fade,
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
