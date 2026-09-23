import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_widget_labels.dart';

/// Maps an OBDX `componentName` to a Flutter widget.
///
/// An OBDX component name does not imply a Flutter implementation — the web
/// side resolves each to an Oracle JET component we have no equivalent of.
/// This registry is the bridge, and adding a widget to a dashboard is
/// therefore: a catalog entry (which the host owns) + a registry entry +
/// the widget itself.
///
/// One implementation per user type, because the same `componentName` can
/// legitimately mean different things — a Retail `financial-summary` is not
/// a Corporate `account-financial-summary`, and neither user type should be
/// able to build the other's widgets.
abstract class DashboardWidgetRegistry {
  const DashboardWidgetRegistry();

  /// Builders keyed by `componentName`. Each takes no arguments and reads
  /// its own providers, so a widget can be constructed from a name alone.
  Map<String, Widget Function()> get builders;

  Set<String> get implementedComponents => builders.keys.toSet();

  bool isImplemented(String componentName) =>
      builders.containsKey(componentName);

  /// Builds [componentName], or a placeholder naming it when unimplemented.
  ///
  /// A placeholder rather than nothing: the user chose to put this widget
  /// on their dashboard, and silently dropping it would make the Personalize
  /// panel look broken. It also keeps the saved configuration honest — the
  /// component stays in the layout and still round-trips to the web client,
  /// which *can* render it.
  Widget build(String componentName) {
    final builder = builders[componentName];
    if (builder != null) return builder();
    return UnavailableDashboardWidget(componentName: componentName);
  }
}

/// Shown in place of a widget this app does not implement yet.
class UnavailableDashboardWidget extends StatelessWidget {
  const UnavailableDashboardWidget({super.key, required this.componentName});

  final String componentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ?? theme.hintColor;
    final label = DashboardWidgetLabels.forComponent(componentName);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: muted.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.widgets_outlined, size: 19, color: muted),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Not available in this app yet',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
