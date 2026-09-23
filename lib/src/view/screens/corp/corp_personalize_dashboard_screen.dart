import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_dashboard_config.dart';
import 'package:ubci_bank/src/core/models/corp/corp_widget_definition.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_widget_labels.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_personalization_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Personalize Dashboard — pick which widgets appear on the corporate home
/// screen, grouped by module exactly as the OBDX web screen groups them.
///
/// Lists every widget the user is entitled to, not only the ones this app
/// can draw: the selection round-trips to the host and the web client can
/// render the rest. Widgets without a Flutter implementation are marked and
/// sorted after the implemented ones within their group, so the list is
/// honest without hiding anything.
///
/// Edits apply to the breakpoint the dashboard is currently showing, so a
/// phone personalizes `small` and a desktop `large` — and the layouts for
/// every other breakpoint round-trip untouched.
class CorpPersonalizePanel extends ConsumerStatefulWidget {
  const CorpPersonalizePanel({
    super.key,
    required this.userSegment,
    required this.onClose,
  });

  /// The user's role, e.g. `corporateuser` — one half of §17's filter.
  final String userSegment;

  /// Closes the panel. Supplied by the host so the panel does not assume
  /// it was pushed as a route — it lives in an end drawer.
  final VoidCallback onClose;

  @override
  ConsumerState<CorpPersonalizePanel> createState() =>
      _CorpPersonalizePanelState();
}

class _CorpPersonalizePanelState extends ConsumerState<CorpPersonalizePanel> {
  @override
  void initState() {
    super.initState();
    // Seeds the draft from the saved selection. Post-frame because it
    // mutates a provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(corpPersonalizationProvider.notifier).beginEditing();
    });
  }

  Future<void> _save() async {
    final notifier = ref.read(corpPersonalizationProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final saved = await notifier.save();
    if (!mounted) return;

    if (saved) {
      // The dashboard watches the same provider, so the new arrangement is
      // already on screen behind the panel by the time this closes.
      messenger.showSnackBar(
        const SnackBar(content: Text('Dashboard updated')),
      );
      widget.onClose();
      return;
    }

    final error = ref.read(corpPersonalizationProvider).saveErrorMessage;
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Could not save your dashboard.')),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!ref.read(corpPersonalizationProvider).hasUnsavedChanges) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Your dashboard changes have not been saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true) {
      ref.read(corpPersonalizationProvider.notifier).discardDraft();
      return true;
    }
    return false;
  }

  /// Groups available widgets by module, implemented ones first inside each
  /// group, then alphabetically by display name.
  Map<String, List<CorpWidgetDefinition>> _grouped(
    List<CorpWidgetDefinition> definitions,
  ) {
    final groups = <String, List<CorpWidgetDefinition>>{};
    for (final definition in definitions) {
      groups.putIfAbsent(definition.module, () => []).add(definition);
    }
    for (final entry in groups.entries) {
      entry.value.sort((a, b) {
        final aImplemented = CorpWidgetRegistry.isImplemented(a.componentName);
        final bImplemented = CorpWidgetRegistry.isImplemented(b.componentName);
        if (aImplemented != bImplemented) return aImplemented ? -1 : 1;
        return CorpWidgetLabels.forComponent(a.componentName)
            .compareTo(CorpWidgetLabels.forComponent(b.componentName));
      });
    }
    return Map.fromEntries(
      groups.entries.toList()
        ..sort((a, b) => CorpWidgetLabels.forModule(a.key)
            .compareTo(CorpWidgetLabels.forModule(b.key))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpPersonalizationProvider);
    final available = state.availableWidgets(widget.userSegment);
    final groups = _grouped(available);
    final selection = state.effectiveSelection;

    return PopScope(
      // Intercepts the drawer's own dismissal (back gesture / Esc) so an
      // unsaved selection is not lost silently.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) widget.onClose();
      },
      child: Material(
        color: CorpColors.card(context),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PanelHeader(
                isSaving: state.isSaving,
                canSave: state.hasUnsavedChanges,
                onSave: _save,
                onClose: () async {
                  if (await _confirmDiscard() && mounted) widget.onClose();
                },
              ),
              Divider(height: 1, color: CorpColors.divider(context)),
              Expanded(
                child: _buildBody(context, state, groups, selection),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CorpPersonalizationState state,
    Map<String, List<CorpWidgetDefinition>> groups,
    Set<String> selection,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && !state.isReady) {
      return _Message(
        icon: Icons.error_outline_rounded,
        message: state.errorMessage!,
      );
    }

    if (groups.isEmpty) {
      return const _Message(
        icon: Icons.widgets_outlined,
        message: 'No widgets are available for your profile.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SelectionSummary(
          selectedCount: selection.length,
          breakpointLabel: _breakpointLabel(state),
          isCatalogStale: state.isCatalogStale,
        ),
        const SizedBox(height: 16),
        for (final entry in groups.entries) ...[
          _ModuleGroup(
            moduleLabel: CorpWidgetLabels.forModule(entry.key),
            definitions: entry.value,
            selection: selection,
            onToggle: (componentName) => ref
                .read(corpPersonalizationProvider.notifier)
                .toggle(componentName),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  static String _breakpointLabel(CorpPersonalizationState state) {
    switch (state.breakpoint) {
      case CorpLayoutBreakpoint.small:
        return 'this phone layout';
      case CorpLayoutBreakpoint.medium:
        return 'this tablet layout';
      case CorpLayoutBreakpoint.large:
      case CorpLayoutBreakpoint.defaultLayout:
        return 'this desktop layout';
    }
  }
}

/// Panel title row — replaces the AppBar the full-page version had.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.isSaving,
    required this.canSave,
    required this.onSave,
    required this.onClose,
  });

  final bool isSaving;
  final bool canSave;
  final VoidCallback onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 20,
            color: CorpColors.brand(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Personalize Dashboard',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: CorpColors.textPrimary(context),
              ),
            ),
          ),
          FilledButton(
            onPressed: isSaving || !canSave ? null : onSave,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: isSaving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: isSaving ? null : onClose,
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.selectedCount,
    required this.breakpointLabel,
    required this.isCatalogStale,
  });

  final int selectedCount;
  final String breakpointLabel;
  final bool isCatalogStale;

  @override
  Widget build(BuildContext context) {
    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$selectedCount ${selectedCount == 1 ? 'widget' : 'widgets'} selected',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Changes apply to $breakpointLabel. Your other screen sizes keep '
            'their own arrangement.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: CorpColors.textSecondary(context),
            ),
          ),
          if (isCatalogStale) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: CorpColors.textSecondary(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Showing the built-in widget list — the server list could '
                    'not be reached, so some widgets may be missing.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup({
    required this.moduleLabel,
    required this.definitions,
    required this.selection,
    required this.onToggle,
  });

  final String moduleLabel;
  final List<CorpWidgetDefinition> definitions;
  final Set<String> selection;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: Text(
              moduleLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CorpColors.brand(context),
              ),
            ),
          ),
          for (final definition in definitions)
            _WidgetTile(
              definition: definition,
              selected: selection.contains(definition.componentName),
              onToggle: () => onToggle(definition.componentName),
            ),
        ],
      ),
    );
  }
}

class _WidgetTile extends StatelessWidget {
  const _WidgetTile({
    required this.definition,
    required this.selected,
    required this.onToggle,
  });

  final CorpWidgetDefinition definition;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final implemented =
        CorpWidgetRegistry.isImplemented(definition.componentName);
    final label = CorpWidgetLabels.forComponent(definition.componentName);

    return CheckboxListTile(
      value: selected,
      onChanged: (_) => onToggle(),
      dense: true,
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: CorpColors.textPrimary(context),
        ),
      ),
      subtitle: implemented
          ? null
          : Text(
              'Not available in this app yet',
              style: TextStyle(
                fontSize: 11,
                color: CorpColors.textSecondary(context),
              ),
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: CorpColors.navInactive(context)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: CorpColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
