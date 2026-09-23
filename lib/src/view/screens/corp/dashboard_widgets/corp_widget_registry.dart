import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_widget_labels.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_currency_exposure_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_financial_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_pickup_points_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_account_summary_card.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_quick_links_card.dart';

/// Maps an OBDX `componentName` to a Flutter widget.
///
/// An OBDX component name does not imply a Flutter implementation — the web
/// side resolves each to an Oracle JET component we have no equivalent of.
/// This registry is the bridge, and adding a widget to the dashboard is
/// therefore: a catalog entry (which the host owns) + a registry entry +
/// the widget itself.
///
/// Every builder takes no arguments and reads its own providers, so a
/// widget can be constructed from a name alone.
class CorpWidgetRegistry {
  CorpWidgetRegistry._();

  static final Map<String, Widget Function()> _builders = {
    'account-financial-summary': () => const CorpFinancialSummaryWidget(),
    'account-quick-links': () => const CorpQuickLinksCard(),
    'currency-exposure': () => const CorpCurrencyExposureWidget(),
    'pickup-point-collections': () => const CorpPickupPointsWidget(),
    // `account-summary` is the demand-deposits module's per-account grid,
    // which is what our Account Summary card already shows.
    'account-summary': () => const CorpAccountSummaryCard(),
  };

  /// Component names this app can actually draw.
  static Set<String> get implementedComponents => _builders.keys.toSet();

  static bool isImplemented(String componentName) =>
      _builders.containsKey(componentName);

  /// Builds [componentName], or a placeholder naming it when unimplemented.
  ///
  /// A placeholder rather than nothing: the user chose to put this widget
  /// on their dashboard, and silently dropping it would make the Personalize
  /// screen look broken. It also keeps the saved configuration honest —
  /// the component stays in the layout and still round-trips to the web
  /// client, which *can* render it.
  static Widget build(String componentName) {
    final builder = _builders[componentName];
    if (builder != null) return builder();
    return CorpUnavailableWidget(componentName: componentName);
  }
}

/// Shown in place of a widget this app does not implement yet.
class CorpUnavailableWidget extends StatelessWidget {
  const CorpUnavailableWidget({super.key, required this.componentName});

  final String componentName;

  @override
  Widget build(BuildContext context) {
    final label = CorpWidgetLabels.forComponent(componentName);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CorpColors.navInactive(context).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.widgets_outlined,
              size: 19,
              color: CorpColors.navInactive(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Not available in this app yet',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
