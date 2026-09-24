import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_detail_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_providers.dart';
import 'package:ubci_bank/src/view/providers/common/payee_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/recent_transactions_widget_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_cash_management_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';

/// Invalidates all Riverpod state that belongs to the authenticated user.
///
/// Authentication storage and Riverpod memory are deliberately reset
/// together. Providers that are autoDispose are harmless here; invalidating
/// them makes the logout boundary explicit and prevents stale user data from
/// surviving into the next session.
///
/// Covers both user types — a device can sign out of a Retail session and
/// straight into a Corporate one (or back), so both trees must be cleared on
/// every logout regardless of which one was active.
void resetUserSessionState(Ref ref) {
  ref.invalidate(casaAccountsProvider);
  ref.invalidate(casaAccountDetailProvider);
  ref.invalidate(casaTransactionsProvider);

  ref.invalidate(loanAccountsProvider);
  ref.invalidate(selectedLoanCurrencyProvider);
  ref.invalidate(loanAccountDetailProvider);

  ref.invalidate(payeesProvider);
  ref.invalidate(recentTransactionsWidgetProvider);

  ref.invalidate(corpAccountsProvider);
  ref.invalidate(corpPickupPointsProvider);
  ref.invalidate(corpProfileProvider);

  // Shared by both dashboards — one user's saved widget selection must
  // never be visible, even briefly, on the next user's dashboard.
  ref.invalidate(personalizationProvider);
}
