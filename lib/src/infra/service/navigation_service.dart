import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home_dashboard_screen.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> globalAppNav =
      GlobalKey<NavigatorState>();

  /// Drops login / OTP / splash from the stack so browser Back cannot
  /// return to a credential form after a successful sign-in.
  ///
  /// Ported from vendor branch — used by [LoginWizardScreen] once the
  /// first-time setup wizard completes.
  static void openHomeAndClearStack(
    BuildContext context, {
    required HomeDashboardArgs args,
  }) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      RoutesConst.homeScreen,
      (route) => false,
      arguments: args,
    );
  }
}
