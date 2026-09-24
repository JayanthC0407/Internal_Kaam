import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_descriptor.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_grid_span.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_dashboard_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/common/dashboard_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/infra/session/session_generation.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';

final obdxDashboardApiProvider = Provider(
  (ref) => ObdxDashboardApi(ref.watch(obdxDioClientProvider)),
);

final dashboardRepositoryProvider = Provider(
  (ref) => DashboardRepository(
    dashboardApi: ref.watch(obdxDashboardApiProvider),
  ),
);

/// State of the personalized dashboard: the saved configuration, the
/// catalog it is chosen from, and the authorization set both are filtered
/// against.
///
/// Holds a *draft* selection separate from the saved [config] so the
/// Personalize screen can toggle freely and only commit on Save.
class PersonalizationState {
  const PersonalizationState({
    this.isLoading = false,
    this.isSaving = false,
    this.config,
    this.catalog = DashboardWidgetCatalog.empty,
    this.catalogSource = DashboardCatalogSource.none,
    this.authorized = DashboardAuthorizedComponents.empty,
    this.breakpoint = DashboardBreakpoint.large,
    this.draftSelection,
    this.errorMessage,
    this.saveErrorMessage,
    this.savedAt,
    this.isUnavailable = false,
  });

  /// True once we know `me` gave this user no personalizable dashboard, as
  /// opposed to simply not having loaded yet.
  ///
  /// Lives on the state rather than the notifier so widgets that
  /// `ref.watch(personalizationProvider)` rebuild when it resolves —
  /// watching `.notifier` would never rebuild, since the notifier instance
  /// never changes.
  final bool isUnavailable;

  final bool isLoading;
  final bool isSaving;

  /// The configuration as last loaded or saved. Null until the first load
  /// succeeds, or when the user has no personalizable dashboard.
  final DashboardConfig? config;

  final DashboardWidgetCatalog catalog;
  final DashboardCatalogSource catalogSource;
  final DashboardAuthorizedComponents authorized;

  /// Which breakpoint's layout is being read and written. Set from the
  /// viewport so a phone edits `small` and a desktop edits `large`, exactly
  /// as the web client does.
  final DashboardBreakpoint breakpoint;

  /// Uncommitted selection from the Personalize screen. Null when no edit
  /// is in progress.
  final Set<String>? draftSelection;

  final String? errorMessage;
  final String? saveErrorMessage;
  final DateTime? savedAt;

  bool get isReady => config != null;

  /// Whether the catalog in use is the shipped fallback, which is known to
  /// lag the environment.
  bool get isCatalogStale => catalogSource == DashboardCatalogSource.bundledAsset;

  /// Components currently on the dashboard at [breakpoint], de-duplicated.
  List<String> get selectedComponents =>
      config?.selectedComponentsAt(breakpoint) ?? const [];

  /// The saved layout items at [breakpoint], de-duplicated by component and
  /// keeping the user's order — the render path's input.
  ///
  /// Returns items rather than names so the dashboard can honour each
  /// widget's stored `style` (`oj-lg-4`, `oj-sm-12`, …) when sizing it.
  List<DashboardLayoutItem> get selectedItems {
    final items = config?.layoutFor(breakpoint) ?? const [];
    final seen = <String>{};
    final deduped = <DashboardLayoutItem>[];
    for (final item in items) {
      if (item.componentName.isEmpty) continue;
      if (!seen.add(item.componentName)) continue;
      deduped.add(item);
    }
    return deduped;
  }

  /// The draft if one is open, else what is saved.
  Set<String> get effectiveSelection =>
      draftSelection ?? selectedComponents.toSet();

  bool get hasUnsavedChanges {
    final draft = draftSelection;
    if (draft == null) return false;
    final saved = selectedComponents.toSet();
    return draft.length != saved.length || !draft.containsAll(saved);
  }

  /// Widgets the user may add, per §17. Rendering does **not** use this —
  /// the environment can hold components this catalog never listed.
  List<DashboardWidgetDefinition> availableWidgets(String userSegment) {
    return catalog.availableFor(
      userSegment: userSegment,
      authorizedComponents: authorized.authorized,
    );
  }

  PersonalizationState copyWith({
    bool? isLoading,
    bool? isSaving,
    DashboardConfig? config,
    DashboardWidgetCatalog? catalog,
    DashboardCatalogSource? catalogSource,
    DashboardAuthorizedComponents? authorized,
    DashboardBreakpoint? breakpoint,
    Set<String>? draftSelection,
    String? errorMessage,
    String? saveErrorMessage,
    DateTime? savedAt,
    bool? isUnavailable,
    bool clearError = false,
    bool clearSaveError = false,
    bool clearDraft = false,
  }) {
    return PersonalizationState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      config: config ?? this.config,
      catalog: catalog ?? this.catalog,
      catalogSource: catalogSource ?? this.catalogSource,
      authorized: authorized ?? this.authorized,
      breakpoint: breakpoint ?? this.breakpoint,
      draftSelection: clearDraft ? null : (draftSelection ?? this.draftSelection),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      saveErrorMessage:
          clearSaveError ? null : (saveErrorMessage ?? this.saveErrorMessage),
      savedAt: savedAt ?? this.savedAt,
      isUnavailable: isUnavailable ?? this.isUnavailable,
    );
  }
}

class PersonalizationNotifier
    extends StateNotifier<PersonalizationState> {
  PersonalizationNotifier(this._ref)
      : super(const PersonalizationState());

  final Ref _ref;
  bool _loadedOnce = false;
  Future<void>? _pendingLoad;

  /// Which dashboard to read and write, resolved from `me`. Null means the
  /// user has no personalizable dashboard and the feature is unavailable.
  DashboardDescriptor? _descriptor;

  DashboardDescriptor? get descriptor => _descriptor;

  /// Loads once for [descriptor], which the caller resolves from its own
  /// `me` response — Corporate via `CorpUserProfile.personalizableDashboard`,
  /// Retail via `DashboardDescriptor.personalizableFromProfileResponse`.
  ///
  /// Taking a descriptor rather than a typed profile is what lets one
  /// engine serve both user types.
  Future<void> ensureLoaded(DashboardDescriptor? descriptor) {
    if (_loadedOnce) return Future.value();
    return _pendingLoad ??= load(descriptor).whenComplete(() {
      _pendingLoad = null;
    });
  }

  /// Sets which breakpoint's layout is in play. Called from the dashboard
  /// as the viewport changes, so both mobile and desktop read and write
  /// their own layout.
  void setBreakpoint(DashboardBreakpoint breakpoint) {
    if (state.breakpoint == breakpoint) return;
    // An in-flight draft belongs to the old breakpoint; drop it rather than
    // applying a phone selection to the desktop layout.
    state = state.copyWith(breakpoint: breakpoint, clearDraft: true);
  }

  Future<void> load(DashboardDescriptor? descriptor) async {
    final generation = SessionGeneration.current;
    _descriptor = descriptor;

    if (descriptor == null) {
      _loadedOnce = true;
      state = state.copyWith(
        isLoading: false,
        isUnavailable: true,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isUnavailable: false,
      clearError: true,
    );
    final repository = _ref.read(dashboardRepositoryProvider);

    // The catalog and authorization set are independent of the config, so
    // fetch all three together.
    final results = await Future.wait([
      repository.fetchConfig(
        dashboardClass: descriptor.dashboardClass,
        dashboardClassValue: descriptor.dashboardClassValue,
      ),
      repository.fetchAuthorizedComponents(),
    ]);
    final catalogResult = await repository.fetchCatalog();

    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    _loadedOnce = true;

    final configResult = results[0];
    final authorizedResult = results[1];

    if (configResult is Success<DashboardConfig>) {
      state = state.copyWith(
        isLoading: false,
        config: configResult.data,
        catalog: catalogResult.catalog,
        catalogSource: catalogResult.source,
        authorized: authorizedResult is Success<DashboardAuthorizedComponents>
            ? authorizedResult.data
            : null,
        clearError: true,
        clearDraft: true,
      );
      return;
    }

    if (SessionExpiryCoordinator.instance.isHandling) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    final l10n = await AppLocalizationsHelper.current();
    if (!SessionGeneration.isCurrent(generation) || !mounted) return;
    state = state.copyWith(
      isLoading: false,
      catalog: catalogResult.catalog,
      catalogSource: catalogResult.source,
      errorMessage: configResult.resolveUserMessage(
        l10n: l10n,
        fallback: 'Could not load your dashboard configuration.',
      ),
    );
  }

  /// Opens a draft seeded from the saved selection.
  void beginEditing() {
    state = state.copyWith(
      draftSelection: state.selectedComponents.toSet(),
      clearSaveError: true,
    );
  }

  void discardDraft() => state = state.copyWith(clearDraft: true);

  void toggle(String componentName) {
    final draft = {...state.effectiveSelection};
    if (!draft.remove(componentName)) draft.add(componentName);
    state = state.copyWith(draftSelection: draft, clearSaveError: true);
  }

  /// Commits the draft to the host.
  ///
  /// Only the current breakpoint's layout is rewritten; every other
  /// breakpoint round-trips untouched, so personalizing on a phone cannot
  /// wipe the desktop dashboard (`DashboardConfig.withLayout`).
  Future<bool> save() async {
    final generation = SessionGeneration.current;
    final config = state.config;
    final draft = state.draftSelection;
    if (config == null || draft == null) return false;

    state = state.copyWith(isSaving: true, clearSaveError: true);

    final existing = config.layoutFor(state.breakpoint);
    final items = <DashboardLayoutItem>[];
    final seen = <String>{};

    // Keep the stored item for anything still selected — preserving its
    // style and data — and keep the user's existing order. Duplicates
    // collapse to the first occurrence.
    for (final item in existing) {
      if (!draft.contains(item.componentName)) continue;
      if (!seen.add(item.componentName)) continue;
      items.add(item);
    }

    // Anything newly switched on is appended, sized full-width for the
    // breakpoint being edited.
    for (final componentName in draft) {
      if (seen.contains(componentName)) continue;
      seen.add(componentName);
      items.add(
        DashboardLayoutItem(
          componentName: componentName,
          module: _moduleFor(componentName),
          data: '{}',
          style: _styleFor(componentName, state.breakpoint),
        ),
      );
    }

    final result = await _ref
        .read(dashboardRepositoryProvider)
        .saveConfig(config.withLayout(state.breakpoint, items));

    if (!SessionGeneration.isCurrent(generation) || !mounted) return false;

    if (result is Success<DashboardConfig>) {
      state = state.copyWith(
        isSaving: false,
        config: result.data,
        savedAt: DateTime.now(),
        clearDraft: true,
        clearSaveError: true,
      );
      return true;
    }

    final l10n = await AppLocalizationsHelper.current();
    if (!SessionGeneration.isCurrent(generation) || !mounted) return false;
    state = state.copyWith(
      isSaving: false,
      saveErrorMessage: result.resolveUserMessage(
        l10n: l10n,
        fallback: 'Could not save your dashboard.',
      ),
    );
    return false;
  }

  /// Module for a newly added component, from the catalog. Falls back to
  /// `corporateDashboard`, which is what the host uses for most corporate
  /// widgets, when the catalog has no entry for it.
  String _moduleFor(String componentName) {
    final definition = state.catalog.byName(componentName);
    final module = definition?.module.trim() ?? '';
    return module.isEmpty ? 'corporateDashboard' : module;
  }

  /// Oracle JET grid class for a newly added item.
  ///
  /// Takes the column count from the catalog's `width` for this breakpoint,
  /// which is the size the bank configured the widget at — writing a flat
  /// `oj-*-12` instead made every newly added widget full width, so a
  /// personalized dashboard collapsed into a single vertical column.
  ///
  /// Full width is only the fallback, for a component the catalog has no
  /// entry or no width for. Flutter derives its own layout from this, but
  /// the value also round-trips to the web client, so it has to be a class
  /// the Oracle JET grid understands.
  String _styleFor(String componentName, DashboardBreakpoint breakpoint) {
    final prefix = switch (breakpoint) {
      DashboardBreakpoint.small => 'oj-sm',
      DashboardBreakpoint.medium => 'oj-md',
      DashboardBreakpoint.large ||
      DashboardBreakpoint.defaultLayout =>
        'oj-lg',
    };
    final widthKey = switch (breakpoint) {
      DashboardBreakpoint.small => 'small',
      DashboardBreakpoint.medium => 'medium',
      DashboardBreakpoint.large || DashboardBreakpoint.defaultLayout => 'large',
    };

    final definition = state.catalog.byName(componentName);
    final span = DashboardGridSpan.fromCatalogWidth(
      definition?.widthFor(widthKey),
    );
    return '$prefix-${span ?? DashboardGridSpan.columns}';
  }
}

final personalizationProvider = StateNotifierProvider<
    PersonalizationNotifier, PersonalizationState>(
  (ref) => PersonalizationNotifier(ref),
);
