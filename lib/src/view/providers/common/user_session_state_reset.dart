import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_detail_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_providers.dart';
import 'package:ubci_bank/src/view/providers/common/payee_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/recent_transactions_widget_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_cash_management_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_amend_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_export_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_initiate_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
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

  // Trade Finance (Letter of Credit). Families are invalidated whole, so
  // every Import / Export / Drafts list and every open LC detail or
  // amendment form is dropped together.
  ref.invalidate(corpLcListProvider);
  ref.invalidate(corpLcDetailProvider);
  ref.invalidate(corpLcLookupsProvider);
  ref.invalidate(corpLcSearchProvider);
  ref.invalidate(corpLcInitiateProvider);
  ref.invalidate(corpLcAmendProvider);
  ref.invalidate(corpLcExportAmendmentsProvider);
  ref.invalidate(corpLcAcceptanceProvider);
  ref.invalidate(corpLcTransferProvider);

  // Shared by both dashboards — one user's saved widget selection must
  // never be visible, even briefly, on the next user's dashboard.
  ref.invalidate(personalizationProvider);
}
