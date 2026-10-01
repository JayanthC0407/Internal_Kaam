import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/retail/dashboard_widgets/retail_dashboard_widgets.dart';

/// The Retail dashboard's `componentName` → widget map.
///
/// The names come from the OBDX catalog's retail-eligible entries; the
/// widgets are the ones the Retail dashboard already renders. Five of the
/// catalog's 41 retail-eligible components have a Flutter implementation —
/// everything else the user selects draws a named placeholder, exactly as
/// on Corporate.
///
/// A name need not mean the same widget for both user types (see
/// [DashboardWidgetRegistry]), which is why each user type gets its own
/// registry rather than sharing one map.
class RetailWidgetRegistry extends DashboardWidgetRegistry {
  const RetailWidgetRegistry();

  @override
  Map<String, Widget Function()> get builders => {
        // ── Names seen on a real retail user's saved dashboard ──────────
        //
        // These come from the configuration the host actually returns, not
        // from the catalog. An earlier version of this map was derived from
        // the catalog's retail-eligible entries and matched almost none of
        // them, so the whole dashboard rendered as placeholders.
        //
        // The accounts carousel ([RetailAccountsWidget]: CASA / Credit Card
        // / Loans / Insurance tabs) is not in this map. It is part of the
        // dashboard itself — see [fixedTileCount] — and it used to be
        // mapped to `casa-balance-card` and `financial-summary`, neither of
        // which it resembles; selecting either now draws a placeholder.
        'casa-account-card': () => const RetailCasaAccountsWidget(),
        'loans-account-card': () => const RetailLoanAccountsWidget(),
        'loans-balance-card': () => const RetailLoanSummaryWidget(),
        'dashboard-quick-links': () => const RetailQuickLinksWidget(),
        'credit-card': () => const RetailCreditCardsWidget(),

        // ── Catalog names for the same widgets ──────────────────────────
        //
        // Kept alongside: a user whose dashboard was built from the catalog
        // rather than these host names should still render.
        'recent-account-transactions': () =>
            const RetailRecentTransactionsWidget(),
        'spend-summary': () => const RetailSpendSummaryWidget(),
        'loan-summary': () => const RetailLoanSummaryWidget(),
        'quick-links': () => const RetailQuickLinksWidget(),
        'offers': () => const RetailOffersWidget(),
      };

  /// Sizes — every widget is half the row, which is the fixed Retail
  /// home's two-column arrangement (see [DashboardGridLayout.twoColumns]).
  /// Saving 6 also gives the web client two columns.
  ///
  /// The host names above have no catalog entry at all; without these
  /// they had no size and each drew full width, one per row.
  ///
  /// Widgets with a card of their own keep it ([DashboardWidgetSpec.ownCard]),
  /// so the personalized dashboard looks exactly like the fixed one. The
  /// two bare lists and the card visuals have none, so the grid draws
  /// Retail's card around them, with a title.
  @override
  Map<String, DashboardWidgetSpec> get specs => const {
        'casa-account-card': DashboardWidgetSpec(
          large: 6,
          medium: 12,
          // TODO(l10n): tile titles.
          title: 'My Accounts',
        ),
        'loans-account-card': DashboardWidgetSpec(
          large: 6,
          medium: 12,
          title: 'Loans & Finances',
        ),
        'loans-balance-card': _ownCard,
        'dashboard-quick-links': _ownCard,
        'credit-card': DashboardWidgetSpec(
          large: 6,
          medium: 12,
          title: 'Credit Cards',
        ),
        'recent-account-transactions': _ownCard,
        'spend-summary': _ownCard,
        'loan-summary': _ownCard,
        'quick-links': _ownCard,
        'offers': _ownCard,
      };

  /// My Spendings is part of the Retail dashboard proper rather than a
  /// widget the user opts into: it always shows, top right, as on the fixed
  /// home.
  @override
  Set<String> get pinnedComponents => const {'spend-summary'};

  /// The accounts carousel, always shown top left, as on the fixed home.
  /// It has no component name, so it is counted here, toward the widget
  /// limit, rather than through [pinnedComponents].
  @override
  int get fixedTileCount => 1;

  static const _ownCard = DashboardWidgetSpec(
    large: 6,
    medium: 12,
    ownCard: true,
  );

  /// Retail's card — the one its home widgets draw for themselves — for the
  /// tiles the grid frames.
  static BoxDecoration tileDecoration(BuildContext context) => BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: HomeColors.brandLight(context).withValues(alpha: 0.30),
            blurRadius: 15,
          ),
        ],
      );

  /// Every widget the fixed Retail dashboard renders, in its original
  /// order — the layout used when the user has no saved configuration.
  ///
  /// Keeping this beside the map is what guarantees the default and the
  /// personalized paths draw the same set: if a widget is added to one it
  /// has to be added here too, or it is plainly missing.
  ///
  /// The accounts carousel, first on the fixed home, is not listed: it is
  /// always drawn, see [fixedTileCount].
  static const defaultComponents = <String>[
    'quick-links',
    'loan-summary',
    'spend-summary',
    'recent-account-transactions',
    'offers',
  ];
}
