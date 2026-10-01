import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/personalize_panel.dart';

/// Opens Personalize Dashboard the way the screen suits: a bottom sheet on
/// phones, the side panel everywhere else. Shared by both dashboards.
///
/// The sheet is the mobile convention — it rises from where the thumb is,
/// and uses the full width a phone has, where a side drawer would squeeze
/// the module list into most of the screen anyway.
class PersonalizeLauncher {
  const PersonalizeLauncher._();

  /// Screens narrower than this get the bottom sheet.
  static const double sheetBelowWidth = 600;

  static bool usesSheet(BuildContext context) =>
      MediaQuery.sizeOf(context).width < sheetBelowWidth;

  /// Opens Personalize. On wider screens this opens [scaffold]'s end drawer
  /// (which the dashboard builds as the side panel); on phones, a sheet —
  /// and [onClosed] runs once it has gone, as the dashboards' end-drawer
  /// callback does for the side panel.
  static Future<void> open(
    BuildContext context, {
    required ScaffoldState? scaffold,
    required String userSegment,
    required DashboardWidgetRegistry registry,
    VoidCallback? onClosed,
  }) async {
    if (!usesSheet(context)) {
      scaffold?.openEndDrawer();
      return;
    }

    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Off: the framework's own drag-to-close pops the sheet directly,
      // skipping the panel's "Discard changes?" check. [_SheetHandle]
      // closes it the checked way instead.
      enableDrag: false,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.9,
        child: Column(
          children: [
            const _SheetHandle(),
            Expanded(
              child: PersonalizePanel(
                userSegment: userSegment,
                registry: registry,
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
    onClosed?.call();
  }
}

/// The grab bar at the top of the sheet. Swiping it down closes the sheet
/// through [Navigator.maybePop], so the panel can ask about unsaved changes
/// first — tapping outside the sheet takes the same route.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Close Personalize Dashboard',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 150) {
            Navigator.of(context).maybePop();
          }
        },
        child: SizedBox(
          height: 28,
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
