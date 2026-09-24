import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_detail_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_providers.dart';
import 'package:ubci_bank/src/view/providers/common/payee_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/recent_transactions_widget_providers.dart';

/// Invalidates all Riverpod state that belongs to the authenticated user.
///
/// Authentication storage and Riverpod memory are deliberately reset
/// together. Providers that are autoDispose are harmless here; invalidating
/// them makes the logout boundary explicit and prevents stale user data from
/// surviving into the next session.
void resetUserSessionState(Ref ref) {
  ref.invalidate(casaAccountsProvider);
  ref.invalidate(casaAccountDetailProvider);
  ref.invalidate(casaTransactionsProvider);

  ref.invalidate(loanAccountsProvider);
  ref.invalidate(selectedLoanCurrencyProvider);
  ref.invalidate(loanAccountDetailProvider);

  ref.invalidate(payeesProvider);
  ref.invalidate(recentTransactionsWidgetProvider);
}
