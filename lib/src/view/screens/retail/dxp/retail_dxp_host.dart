import 'package:flutter/widgets.dart';

import 'package:demo_bank/src/core/models/retail/casa_account.dart';
import 'package:demo_bank/src/view/screens/retail/dxp/retail_app_widgets.dart';
import 'package:demo_bank/src/sdui/dxp_runtime.dart';
import 'package:demo_bank/src/view/screens/retail/home/widgets/retail_nav.dart';

/// The Retail dashboard's half of the DXP contract: what a published
/// screen may read (CONTRACT-OBDX §6) and which existing screens it may open
/// (§7). Built by the dashboard, which owns the data and the navigation.
class RetailDxpHost implements DxpHost {
  RetailDxpHost({
    required this.loadAccounts,
    required this.openNavItem,
    required String firstName,
    required String fullName,
  }) : customer = {
          'firstName': firstName,
          'name': fullName,
          'segment': 'RETAIL',
        };

  /// The CASA accounts the dashboard already loads from OBDX.
  final Future<List<CasaAccount>> Function() loadAccounts;

  /// Selects a Retail menu item, exactly as a tap in the menu does.
  final void Function(String navId) openNavItem;

  @override
  final Map<String, dynamic> customer;

  @override
  Map<String, Widget Function()> get appWidgets => RetailAppWidgets.builders;

  /// `nativeRoute` route → Retail menu id (CONTRACT-OBDX §7). Keep in step
  /// with the platform's `NATIVE_ROUTES` (dxp-platform `src/validate.js`).
  static const routeTable = <String, String>{
    '/home': RetailNav.home,
    '/transfer': RetailNav.transfer,
    '/accounts': RetailNav.accountsCasa,
    '/accounts/loans': RetailNav.accountsLoans,
    '/accounts/term-deposits': RetailNav.accountsTermDeposits,
    '/cards/credit': RetailNav.creditCards,
    '/bills': RetailNav.billPayments,
  };

  @override
  bool openNative(String route) {
    final navId = routeTable[route];
    if (navId == null) return false;
    openNavItem(navId);
    return true;
  }

  @override
  Future<dynamic> resolveData(String source) async {
    try {
      switch (source) {
        case 'customer.profile':
          return customer;
        case 'accounts.list':
          final accounts = await loadAccounts();
          return accounts.map(accountToContract).toList();
      }
    } catch (_) {
      // Rendered empty; the runtime posts the ERROR event.
    }
    return null;
  }

  /// A CASA account in the contract's shape: `{id, name, number, type,
  /// balance, currency}`. The number is always masked to its last four
  /// digits before it reaches a published screen (CONTRACT-OBDX §6).
  static Map<String, dynamic> accountToContract(CasaAccount a) {
    final balance = a.displayBalance;
    return {
      'id': a.id,
      'name': a.title,
      'number': maskAccountNumber(a.displayNumber),
      'type': (a.accountType ?? '').toUpperCase(),
      'balance': balance?.amount ?? 0,
      'currency': balance?.currency ?? a.currencyCode,
    };
  }

  static String maskAccountNumber(String number) {
    final compact = number.replaceAll(RegExp(r'\s+'), '');
    if (compact.length <= 4) return compact;
    return '•••• ${compact.substring(compact.length - 4)}';
  }
}
