import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_dashboard_screen.dart';
import 'package:ubci_bank/src/view/widgets/session_activity_scope.dart';

/// Route generation for the Corporate (`corporateuser`) surfaces.
///
/// `Routes.onGenerateRoutes` delegates any name in
/// [CorpRoutesConst.all] here, so the corporate route table can grow on its
/// own without touching the retail one. Returning `null` lets the caller
/// apply its own splash fallback (the pattern the retail table uses for a
/// route that needs arguments but was reached without them, e.g. a web
/// reload or deep link).
class CorpRoutes {
  CorpRoutes._();

  static Route<dynamic>? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case CorpRoutesConst.corpDashboardScreen:
        final args = routeSettings.arguments;
        if (args is! CorpDashboardArgs) return null;
        return PageTransition(
          settings: routeSettings,
          child: AuthenticatedSessionGate(
            child: CorpDashboardScreen(args: args),
          ),
          type: PageTransitionType.rightToLeft,
          duration: const Duration(milliseconds: 300),
        );
      default:
        return null;
    }
  }
}
