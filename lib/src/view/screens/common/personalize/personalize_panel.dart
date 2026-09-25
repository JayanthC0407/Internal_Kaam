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

    // Saved at the sizes the dashboard draws them at, so the web client
    // shows the same arrangement.
    final state = ref.read(personalizationProvider);
    final saved = await notifier.save(
      spanFor: widget.registry.spanResolver(
        breakpoint: state.breakpoint,
        catalog: state.catalog,
      ),
    );
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
    // Read after watching the state, so it reflects the state this build
    // is rendering.
    final saveBlockedReason =
        ref.read(personalizationProvider.notifier).saveBlockedReason;

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
                // Disabled — with the reason shown below — rather than
                // letting the press fail: a factory dashboard, or permissions
                // that have not loaded, can never be saved from here.
                canSave: state.hasUnsavedChanges && saveBlockedReason == null,
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
                blockedReason: state.isReady ? saveBlockedReason : null,
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
        onRetry: state.configLoadFailed
            ? () => ref.read(personalizationProvider.notifier).retry()
            : null,
      );
    }

    // Explicit, rather than falling through to "no widgets available":
    // an authorization set that has not loaded is not the same as one that
    // authorizes nothing, and the user needs to know which they are seeing.
    switch (state.authorizationStatus) {
      case DashboardAuthorizationStatus.notLoaded:
      case DashboardAuthorizationStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case DashboardAuthorizationStatus.failed:
        return _Message(
          icon: Icons.lock_outline_rounded,
          message: state.authorizationError ??
              'Your widget permissions could not be loaded.',
          onRetry: () => ref.read(personalizationProvider.notifier).retry(),
        );
      case DashboardAuthorizationStatus.loaded:
        break;
    }

    if (groups.isEmpty) {
      return const _Message(
        icon: Icons.widgets_outlined,
        message: 'No widgets are available for your profile.',
      );
    }

    final moduleKeys = groups.keys.toList();

    void onToggle(String componentName) =>
        ref.read(personalizationProvider.notifier).toggle(componentName);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The flyout renders beside this panel, over the dashboard, so what
        // matters is the room on *screen*, not in the panel — the panel is
        // only as wide as the headings. Below phone width, fall back to
        // headings that expand in place: a pop-out would have nowhere to
        // pop to, and there is no hover there anyway.
        final canFlyOut = MediaQuery.of(context).size.width >= 600;

        if (!canFlyOut) {
          return _ModuleAccordion(
            modules: moduleKeys,
            groups: groups,
            selection: selection,
            registry: widget.registry,
            onToggle: onToggle,
          );
        }

        return _ModuleFlyout(
          modules: moduleKeys,
          groups: groups,
          selection: selection,
          registry: widget.registry,
          onToggle: onToggle,
        );
      },
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

/// How many of [module]'s widgets are currently selected.
int _selectedCount(
  String module,
  Map<String, List<DashboardWidgetDefinition>> groups,
  Set<String> selection,
) {
  final definitions = groups[module] ?? const <DashboardWidgetDefinition>[];
  var count = 0;
  for (final definition in definitions) {
    if (selection.contains(definition.componentName)) count++;
  }
  return count;
}

/// Module headings with a pop-out panel of that module's widgets, the way
/// the bank's own navigation menus behave.
///
/// Pointing at a heading floats its widgets beside it; the flyout stays up
/// while the pointer is over either the heading or the flyout, so you can
/// travel across the gap to reach a checkbox. Tapping pins a heading open,
/// which is what makes this usable on a touch screen where there is no
/// hover at all.
class _ModuleFlyout extends StatefulWidget {
  const _ModuleFlyout({
    required this.modules,
    required this.groups,
    required this.selection,
    required this.registry,
    required this.onToggle,
  });

  final List<String> modules;
  final Map<String, List<DashboardWidgetDefinition>> groups;
  final Set<String> selection;
  final DashboardWidgetRegistry registry;
  final ValueChanged<String> onToggle;

  @override
  State<_ModuleFlyout> createState() => _ModuleFlyoutState();
}

class _ModuleFlyoutState extends State<_ModuleFlyout> {
  static const double _rowHeight = 46;
  static const double _flyoutWidth = 300;
  static const double _rowEntryHeight = 52;

  /// Gap between the flyout and the headings it belongs to.
  static const double _gap = 8;

  final ScrollController _scroll = ScrollController();

  /// Anchors the flyout to the headings list, so it can be positioned
  /// *outside* the panel — the panel is a right-edge drawer, so the only
  /// direction with room is left, over the dashboard.
  final LayerLink _link = LayerLink();

  final OverlayPortalController _portal = OverlayPortalController();

  int? _hoveredIndex;
  bool _pointerInFlyout = false;

  /// A heading the user tapped, which stays open until they tap elsewhere.
  /// Without this the panel would be unusable on a touch screen.
  int? _pinnedIndex;

  /// Height available to the headings list, used to keep the flyout on
  /// screen when a heading near the bottom is opened.
  double _listHeight = 0;

  @override
  void initState() {
    super.initState();
    // The flyout is positioned against the heading's on-screen offset, so
    // it has to follow the list as it scrolls.
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_openIndex != null) setState(() {});
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// A pinned heading wins; otherwise whichever the pointer is over.
  int? get _openIndex => _pinnedIndex ?? _hoveredIndex;

  /// Keeps the overlay in step with [_openIndex]. Called after every
  /// state change rather than from build, since toggling the portal
  /// during a build would mutate the overlay mid-frame.
  void _syncPortal() {
    final shouldShow = _openIndex != null;
    if (shouldShow && !_portal.isShowing) {
      _portal.show();
    } else if (!shouldShow && _portal.isShowing) {
      _portal.hide();
    }
  }

  void _hover(int? index) {
    if (_hoveredIndex == index) return;
    setState(() => _hoveredIndex = index);
    _syncPortal();
  }

  /// Closes only when the pointer has left both the heading and the flyout,
  /// and nothing is pinned.
  void _maybeClose() {
    if (_pointerInFlyout || _pinnedIndex != null) return;
    if (_hoveredIndex == null) return;
    setState(() => _hoveredIndex = null);
    _syncPortal();
  }

  void _togglePin(int index) {
    setState(() {
      _pinnedIndex = _pinnedIndex == index ? null : index;
      _hoveredIndex = _pinnedIndex == null ? null : index;
    });
    _syncPortal();
  }

  void _dismiss() {
    if (_pinnedIndex == null && _hoveredIndex == null) return;
    setState(() {
      _pinnedIndex = null;
      _hoveredIndex = null;
    });
    _syncPortal();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _listHeight = constraints.maxHeight;

        return OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _buildFlyout,
          child: CompositedTransformTarget(
            link: _link,
            child: MouseRegion(
              onExit: (_) => _maybeClose(),
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: widget.modules.length,
                itemExtent: _rowHeight,
                itemBuilder: (context, index) {
                  final module = widget.modules[index];
                  return _ModuleHeading(
                    label: DashboardWidgetLabels.forModule(module),
                    selectedCount: _selectedCount(
                      module,
                      widget.groups,
                      widget.selection,
                    ),
                    isOpen: index == _openIndex,
                    isPinned: index == _pinnedIndex,
                    onHover: () => _hover(index),
                    onTap: () => _togglePin(index),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// The pop-out, rendered in the app overlay so it can sit *outside* the
  /// drawer — to the left of the headings, floating over the dashboard.
  /// Keeping it inside the drawer would mean sizing the drawer for both
  /// columns, which leaves a dead area whenever nothing is open.
  Widget _buildFlyout(BuildContext context) {
    final openIndex = _openIndex;
    if (openIndex == null) return const SizedBox.shrink();

    final module = widget.modules[openIndex];
    final definitions =
        widget.groups[module] ?? const <DashboardWidgetDefinition>[];
    if (definitions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scrollOffset = _scroll.hasClients ? _scroll.offset : 0.0;

    final height = (definitions.length * _rowEntryHeight + 16)
        .clamp(0.0, _listHeight <= 0 ? 320.0 : _listHeight);
    final rawTop = (openIndex * _rowHeight) - scrollOffset + 6;
    final maxTop = (_listHeight - height - 6).clamp(0.0, double.infinity);
    final top = rawTop.clamp(0.0, maxTop);

    return Stack(
      children: [
        // Tapping anywhere else dismisses, the way a menu does. Only while
        // pinned — a hover-opened flyout closes on its own.
        if (_pinnedIndex != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismiss,
            ),
          ),
        CompositedTransformFollower(
          link: _link,
          // Attach the flyout's top-right to the headings' top-left, so it
          // grows leftwards away from the panel.
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.topRight,
          offset: Offset(-_gap, top),
          child: MouseRegion(
            onEnter: (_) => setState(() => _pointerInFlyout = true),
            onExit: (_) {
              setState(() => _pointerInFlyout = false);
              _maybeClose();
            },
            child: SizedBox(
              width: _flyoutWidth,
              height: height,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: theme.cardColor,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _WidgetChecklist(
                    definitions: definitions,
                    selection: widget.selection,
                    registry: widget.registry,
                    onToggle: widget.onToggle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One heading row in the flyout list.
class _ModuleHeading extends StatelessWidget {
  const _ModuleHeading({
    required this.label,
    required this.selectedCount,
    required this.isOpen,
    required this.isPinned,
    required this.onHover,
    required this.onTap,
  });

  final String label;
  final int selectedCount;
  final bool isOpen;
  final bool isPinned;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      onHover: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: isOpen ? accent.withValues(alpha: 0.10) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isOpen ? accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: isOpen ? FontWeight.w700 : FontWeight.w500,
                    color: isOpen ? accent : null,
                  ),
                ),
              ),
              if (selectedCount > 0) ...[
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
                    '$selectedCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
              Icon(
                isPinned ? Icons.push_pin_rounded : Icons.chevron_right_rounded,
                size: isPinned ? 13 : 16,
                color: isOpen ? accent : theme.hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Narrow fallback: headings that expand in place.
///
/// A pop-out needs somewhere to pop to, and a phone has neither the room
/// nor a pointer to hover with.
class _ModuleAccordion extends StatefulWidget {
  const _ModuleAccordion({
    required this.modules,
    required this.groups,
    required this.selection,
    required this.registry,
    required this.onToggle,
  });

  final List<String> modules;
  final Map<String, List<DashboardWidgetDefinition>> groups;
  final Set<String> selection;
  final DashboardWidgetRegistry registry;
  final ValueChanged<String> onToggle;

  @override
  State<_ModuleAccordion> createState() => _ModuleAccordionState();
}

class _ModuleAccordionState extends State<_ModuleAccordion> {
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: widget.modules.length,
      itemBuilder: (context, index) {
        final module = widget.modules[index];
        final definitions =
            widget.groups[module] ?? const <DashboardWidgetDefinition>[];
        final isExpanded = module == _expanded;
        final count = _selectedCount(module, widget.groups, widget.selection);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModuleHeading(
              label: DashboardWidgetLabels.forModule(module),
              selectedCount: count,
              isOpen: isExpanded,
              isPinned: false,
              onHover: () {},
              onTap: () => setState(
                () => _expanded = isExpanded ? null : module,
              ),
            ),
            if (isExpanded)
              Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.04),
                child: _WidgetChecklist(
                  definitions: definitions,
                  selection: widget.selection,
                  registry: widget.registry,
                  onToggle: widget.onToggle,
                  shrinkWrap: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The checkboxes for one module's widgets.
class _WidgetChecklist extends StatelessWidget {
  const _WidgetChecklist({
    required this.definitions,
    required this.selection,
    required this.registry,
    required this.onToggle,
    this.shrinkWrap = false,
  });

  final List<DashboardWidgetDefinition> definitions;
  final Set<String> selection;
  final DashboardWidgetRegistry registry;
  final ValueChanged<String> onToggle;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (definitions.isEmpty) {
      return const _Message(
        icon: Icons.widgets_outlined,
        message: 'No widgets in this module.',
      );
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: definitions.length,
      itemBuilder: (context, index) {
        final definition = definitions[index];
        final implemented = registry.isImplemented(definition.componentName);
        final isSelected = selection.contains(definition.componentName);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => onToggle(definition.componentName),
          dense: true,
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            DashboardWidgetLabels.forComponent(definition.componentName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
    this.blockedReason,
  });

  final int selectedCount;
  final String breakpointLabel;
  final bool isCatalogStale;

  /// Why Save is unavailable, shown so a disabled button explains itself.
  final String? blockedReason;

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
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.open_with_rounded, size: 13, color: theme.hintColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'To rearrange, hold a widget on the dashboard and drag it '
                  'where you want it.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 10.5, height: 1.3),
                ),
              ),
            ],
          ),
          if (isCatalogStale) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13, color: theme.hintColor),
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
          if (blockedReason != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    blockedReason!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      height: 1.3,
                      color: theme.colorScheme.error,
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

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.message, this.onRetry});

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

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
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
