import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';

/// Drag-and-drop arrangement on the dashboard itself, shared by Retail and
/// Corporate.
///
/// Holding a widget and dropping it on another moves it there and saves at
/// once — the drop is the whole edit — with an Undo in the confirmation.
class DashboardArrange {
  const DashboardArrange._();

  /// How long the "Dashboard updated · Undo" message stays up.
  ///
  /// Explicit, and not left to persist: a SnackBar with an action persists
  /// until dismissed by default, which left the message stuck on screen.
  static const confirmationDuration = Duration(seconds: 5);

  /// Whether widgets can be dragged right now: the dashboard is showing a
  /// saved layout it is allowed to write, and nothing is mid-save or has
  /// unsaved changes in the Personalize panel.
  ///
  /// Unsaved changes rather than any open draft: a draft the panel opened
  /// and never changed is no reason to stop a drag.
  static bool isAvailable(WidgetRef ref) {
    final state = ref.watch(personalizationProvider);
    return state.bodyStatus == PersonalizedBodyStatus.ready &&
        !state.isSaving &&
        !state.hasUnsavedChanges &&
        ref.read(personalizationProvider.notifier).saveBlockedReason == null;
  }

  /// Handles a drop of [dragged] on [target].
  static Future<void> move(
    BuildContext context,
    WidgetRef ref, {
    required DashboardWidgetRegistry registry,
    required String dragged,
    required String target,
  }) async {
    final state = ref.read(personalizationProvider);
    final notifier = ref.read(personalizationProvider.notifier);
    final spanFor = registry.spanResolver(
      breakpoint: state.breakpoint,
      catalog: state.catalog,
    );
    final before = [...state.effectiveOrder];
    final messenger = ScaffoldMessenger.of(context);

    final saved = await notifier.moveAndSave(
      dragged,
      target,
      spanFor: spanFor,
    );
    if (!context.mounted) return;

    // Each drop replaces the last drop's message, so Undo always undoes the
    // move just made.
    messenger.hideCurrentSnackBar();
    if (saved) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Dashboard updated'),
          duration: confirmationDuration,
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final undone = await notifier.saveOrder(before, spanFor: spanFor);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      undone ? 'Move undone' : 'Could not undo the move.',
                    ),
                  ),
                );
            },
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ref.read(personalizationProvider).saveErrorMessage ??
              'Could not save your dashboard.',
        ),
      ),
    );
  }

  /// Drops a draft the Personalize panel left behind when it closed — by
  /// tapping outside it, which is not a pop the panel sees, so its own
  /// discard never ran. Called from the dashboards' `onEndDrawerChanged`.
  static void panelClosed(WidgetRef ref) {
    final state = ref.read(personalizationProvider);
    if (state.isSaving || state.draft == null) return;
    ref.read(personalizationProvider.notifier).discardDraft();
  }
}
