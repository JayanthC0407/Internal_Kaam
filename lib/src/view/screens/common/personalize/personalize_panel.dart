import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_widget_labels.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_registry.dart';

/// Personalize Dashboard — pick which widgets appear on the home screen.
///
/// Two panes, as the OBDX screen does it: module headings on the left, and
/// that module's widgets beside them. Pointing at a heading reveals its
/// widgets; on touch devices, where there is no hover, tapping does the
/// same.
///
/// Lists every widget the user is entitled to, not only the ones this app
/// can draw: the selection round-trips to the host and the web client can
/// render the rest. Widgets without a Flutter implementation are marked and
/// sorted after the implemented ones within their group.
///
/// Edits apply to the breakpoint the dashboard is currently showing, so a
/// phone personalizes `small` and a desktop `large` — every other
/// breakpoint round-trips untouched.
///
/// User-type agnostic: [registry] decides which components can actually be
/// drawn and [userSegment] is the §17 filter's segment half, so the same
/// panel serves Retail and Corporate.
class PersonalizePanel extends ConsumerStatefulWidget {
  const PersonalizePanel({
    super.key,
    required this.userSegment,
    required this.registry,
    required this.onClose,
  });

  /// The user's role, e.g. `corporateuser` / `retailuser`.
  final String userSegment;

  final DashboardWidgetRegistry registry;

  /// Closes the panel. Supplied by the host so the panel does not assume it
  /// was pushed as a route — it lives in an end drawer.
  final VoidCallback onClose;

  @override
  ConsumerState<PersonalizePanel> createState() => _PersonalizePanelState();
}

class _PersonalizePanelState extends ConsumerState<PersonalizePanel> {
  /// Module whose widgets are showing in the right pane.
  String? _activeModule;

  @override
  void initState() {
    super.initState();
    // Seeds the draft from the saved selection. Post-frame because it
    // mutates a provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(personalizationProvider.notifier).beginEditing();
    });
  }

  Future<void> _save() async {
    final notifier = ref.read(personalizationProvider.notifier);
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

    final error = ref.read(personalizationProvider).saveErrorMessage;
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Could not save your dashboard.')),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!ref.read(personalizationProvider).hasUnsavedChanges) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your dashboard changes have not been saved.'),
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
      ref.read(personalizationProvider.notifier).discardDraft();
      return true;
    }
    return false;
  }

  /// Groups available widgets by module, implemented ones first inside each
  /// group, then alphabetically by display name.
  Map<String, List<DashboardWidgetDefinition>> _grouped(
    List<DashboardWidgetDefinition> definitions,
  ) {
    final groups = <String, List<DashboardWidgetDefinition>>{};
    for (final definition in definitions) {
      groups.putIfAbsent(definition.module, () => []).add(definition);
    }
    for (final entry in groups.entries) {
      entry.value.sort((a, b) {
        final aImplemented = widget.registry.isImplemented(a.componentName);
        final bImplemented = widget.registry.isImplemented(b.componentName);
        if (aImplemented != bImplemented) return aImplemented ? -1 : 1;
        return DashboardWidgetLabels.forComponent(a.componentName)
            .compareTo(DashboardWidgetLabels.forComponent(b.componentName));
      });
    }
    return Map.fromEntries(
      groups.entries.toList()
        ..sort((a, b) => DashboardWidgetLabels.forModule(a.key)
            .compareTo(DashboardWidgetLabels.forModule(b.key))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personalizationProvider);
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
        color: Theme.of(context).cardColor,
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
              Divider(height: 1, color: Theme.of(context).dividerColor),
              _SelectionSummary(
                selectedCount: selection.length,
                breakpointLabel: _breakpointLabel(state),
                isCatalogStale: state.isCatalogStale,
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              Expanded(child: _buildBody(context, state, groups, selection)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PersonalizationState state,
    Map<String, List<DashboardWidgetDefinition>> groups,
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

    // Keep the active module valid across rebuilds; default to the first.
    final moduleKeys = groups.keys.toList();
    final active = moduleKeys.contains(_activeModule)
        ? _activeModule!
        : moduleKeys.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 168,
          child: _ModuleList(
            modules: moduleKeys,
            active: active,
            selection: selection,
            groups: groups,
            onActivate: (module) {
              if (_activeModule == module) return;
              setState(() => _activeModule = module);
            },
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          child: _WidgetList(
            definitions: groups[active] ?? const [],
            selection: selection,
            registry: widget.registry,
            onToggle: (componentName) => ref
                .read(personalizationProvider.notifier)
                .toggle(componentName),
          ),
        ),
      ],
    );
  }

  static String _breakpointLabel(PersonalizationState state) {
    switch (state.breakpoint) {
      case DashboardBreakpoint.small:
        return 'this phone layout';
      case DashboardBreakpoint.medium:
        return 'this tablet layout';
      case DashboardBreakpoint.large:
      case DashboardBreakpoint.defaultLayout:
        return 'this desktop layout';
    }
  }
}

/// Left pane — module headings. Pointing at one reveals its widgets; tap
/// does the same, so the panel works without a pointer.
class _ModuleList extends StatelessWidget {
  const _ModuleList({
    required this.modules,
    required this.active,
    required this.selection,
    required this.groups,
    required this.onActivate,
  });

  final List<String> modules;
  final String active;
  final Set<String> selection;
  final Map<String, List<DashboardWidgetDefinition>> groups;
  final ValueChanged<String> onActivate;

  /// How many of this module's widgets are currently selected — shown so
  /// the user can see where their dashboard is made up from without
  /// opening every heading.
  int _selectedIn(String module) {
    final definitions = groups[module] ?? const <DashboardWidgetDefinition>[];
    var count = 0;
    for (final definition in definitions) {
      if (selection.contains(definition.componentName)) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        final isActive = module == active;
        final selected = _selectedIn(module);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onActivate(module),
          child: InkWell(
            onTap: () => onActivate(module),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
              decoration: BoxDecoration(
                color: isActive
                    ? accent.withValues(alpha: 0.10)
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isActive ? accent : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DashboardWidgetLabels.forModule(module),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? accent : null,
                      ),
                    ),
                  ),
                  if (selected > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$selected',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isActive ? accent : theme.hintColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Right pane — the active module's widgets.
class _WidgetList extends StatelessWidget {
  const _WidgetList({
    required this.definitions,
    required this.selection,
    required this.registry,
    required this.onToggle,
  });

  final List<DashboardWidgetDefinition> definitions;
  final Set<String> selection;
  final DashboardWidgetRegistry registry;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (definitions.isEmpty) {
      return const _Message(
        icon: Icons.widgets_outlined,
        message: 'No widgets in this module.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 16),
      itemCount: definitions.length,
      itemBuilder: (context, index) {
        final definition = definitions[index];
        final implemented = registry.isImplemented(definition.componentName);

        return CheckboxListTile(
          value: selection.contains(definition.componentName),
          onChanged: (_) => onToggle(definition.componentName),
          dense: true,
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          title: Text(
            DashboardWidgetLabels.forComponent(definition.componentName),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: selection.contains(definition.componentName)
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
          ),
          subtitle: implemented
              ? null
              : Text(
                  'Not available in this app yet',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 10.5),
                ),
        );
      },
    );
  }
}

/// Panel title row — replaces the AppBar a full-page version would have.
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Personalize Dashboard',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
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
            icon: const Icon(Icons.close_rounded, size: 20),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$selectedCount ${selectedCount == 1 ? 'widget' : 'widgets'} '
            'selected',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Applies to $breakpointLabel. Your other screen sizes keep their '
            'own arrangement.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.35,
            ),
          ),
          if (isCatalogStale) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: theme.hintColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Showing the built-in widget list — the server list could '
                    'not be reached, so some widgets may be missing.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 10.5, height: 1.3),
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

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
