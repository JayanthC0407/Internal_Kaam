import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';

/// How many widgets a dashboard may show on one screen size, and how many
/// it shows now.
///
/// The limits come from the agreed widget-defaults sheet
/// (`Dashboard_Widget_Defaults.xlsx`): 8 on a desktop, 6 on a tablet, 5 on
/// a phone. They count everything on the dashboard — the widgets the user
/// picked *and* the ones that are always shown (Retail's My Spendings,
/// Corporate's accounts card) — because both take room on screen.
///
/// Enforced at selection time in the Personalize panel. A dashboard saved
/// over the limit before this existed keeps all its widgets; the user can
/// remove widgets from it, but not add more.
class DashboardWidgetLimit {
  const DashboardWidgetLimit({
    required this.limit,
    required this.onScreen,
    required this.savedOnScreen,
  });

  /// Widgets allowed on [breakpoint]'s layout, always-shown ones included.
  static int limitFor(DashboardBreakpoint breakpoint) => switch (breakpoint) {
        DashboardBreakpoint.small => 5,
        DashboardBreakpoint.medium => 6,
        DashboardBreakpoint.large || DashboardBreakpoint.defaultLayout => 8,
      };

  /// The limit as it stands for [state]'s screen size and current edit.
  factory DashboardWidgetLimit.of(
    PersonalizationState state,
    DashboardWidgetRegistry registry,
  ) {
    return DashboardWidgetLimit(
      limit: limitFor(state.breakpoint),
      onScreen: _countOnScreen(state.effectiveSelection, state, registry),
      savedOnScreen: _countOnScreen(
        state.selectedComponents.toSet(),
        state,
        registry,
      ),
    );
  }

  /// What the dashboard would show with [selection]: the selected widgets
  /// that actually appear (authorized ones — unauthorized ones are never
  /// drawn), plus everything always shown. A pinned widget that is also in
  /// the selection is counted once.
  static int _countOnScreen(
    Set<String> selection,
    PersonalizationState state,
    DashboardWidgetRegistry registry,
  ) {
    final picked = selection
        .where((name) =>
            state.isAuthorized(name) &&
            !registry.pinnedComponents.contains(name))
        .length;
    return picked + registry.alwaysShownCount;
  }

  final int limit;

  /// Widgets on the dashboard with the current edit applied.
  final int onScreen;

  /// Widgets on the dashboard as saved.
  final int savedOnScreen;

  /// Another widget can be added.
  bool get canAdd => onScreen < limit;

  bool get isOverLimit => onScreen > limit;

  /// How many must go before the dashboard is within the limit.
  int get excess => isOverLimit ? onScreen - limit : 0;

  /// Whether the edit may be saved as far as the limit is concerned: within
  /// it — or, for a dashboard already over it, not adding to it, so the
  /// user can save the removals that bring it down.
  bool get allowsSave => !isOverLimit || onScreen <= savedOnScreen;
}
