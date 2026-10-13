import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/export_bill_detail_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/export_lc_detail_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_acceptance_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_amend_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_detail_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_initiate_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_transfer_screen.dart';
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
    final args = routeSettings.arguments;
    switch (routeSettings.name) {
      case CorpRoutesConst.corpDashboardScreen:
        if (args is! CorpDashboardArgs) return null;
        return _page(routeSettings, CorpDashboardScreen(args: args));

      case CorpRoutesConst.lcDetailScreen:
        if (args is! LcDetailArgs) return null;
        return _page(routeSettings, LcDetailScreen(args: args));

      case CorpRoutesConst.exportLcDetailScreen:
        if (args is! LcDetailArgs) return null;
        return _page(routeSettings, ExportLcDetailScreen(args: args));

      case CorpRoutesConst.exportBillDetailScreen:
        if (args is! ExportBillArgs) return null;
        return _page(routeSettings, ExportBillDetailScreen(args: args));

      case CorpRoutesConst.lcInitiateScreen:
        return _page(
          routeSettings,
          LcInitiateScreen(
            args: args is LcInitiateArgs ? args : const LcInitiateArgs(),
          ),
        );

      case CorpRoutesConst.lcAmendScreen:
        if (args is! LcAmendArgs) return null;
        return _page(routeSettings, LcAmendScreen(args: args));

      case CorpRoutesConst.lcAcceptanceScreen:
        if (args is! LcAcceptanceArgs) return null;
        return _page(routeSettings, LcAcceptanceScreen(args: args));

      case CorpRoutesConst.lcTransferScreen:
        if (args is! LcTransferArgs) return null;
        return _page(routeSettings, LcTransferScreen(args: args));

      default:
        return null;
    }
  }

  /// Every corporate page sits behind [AuthenticatedSessionGate], so a
  /// reload or deep link without a live session lands on login instead.
  static Route<dynamic> _page(RouteSettings settings, Widget child) {
    return PageTransition(
      settings: settings,
      child: AuthenticatedSessionGate(child: child),
      type: PageTransitionType.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );
  }
}
