import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/corp/corp_dashboard_config.dart';
import 'package:ubci_bank/src/core/models/corp/corp_user_profile.dart';
import 'package:ubci_bank/src/core/models/corp/corp_widget_definition.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_dashboard_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_dashboard_repository.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';

final obdxCorpDashboardApiProvider = Provider(
  (ref) => ObdxCorpDashboardApi(ref.watch(obdxDioClientProvider)),
);

final corpDashboardRepositoryProvider = Provider(
  (ref) => CorpDashboardRepository(
    dashboardApi: ref.watch(obdxCorpDashboardApiProvider),
  ),
);

/// State of the personalized dashboard: the saved configuration, the
/// catalog it is chosen from, and the authorization set both are filtered
/// against.
///
/// Holds a *draft* selection separate from the saved [config] so the
/// Personalize screen can toggle freely and only commit on Save.
class CorpPersonalizationState {
  const CorpPersonalizationState({
    this.isLoading = false,
    this.isSaving = false,
    this.config,
    this.catalog = CorpWidgetCatalog.empty,
    this.catalogSource = CorpCatalogSource.none,
    this.authorized = CorpAuthorizedComponents.empty,
    this.breakpoint = CorpLayoutBreakpoint.large,
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
  /// `ref.watch(corpPersonalizationProvider)` rebuild when it resolves —
  /// watching `.notifier` would never rebuild, since the notifier instance
  /// never changes.
  final bool isUnavailable;

  final bool isLoading;
  final bool isSaving;

  /// The configuration as last loaded or saved. Null until the first load
  /// succeeds, or when the user has no personalizable dashboard.
  final CorpDashboardConfig? config;

  final CorpWidgetCatalog catalog;
  final CorpCatalogSource catalogSource;
  final CorpAuthorizedComponents authorized;

  /// Which breakpoint's layout is being read and written. Set from the
  /// viewport so a phone edits `small` and a desktop edits `large`, exactly
  /// as the web client does.
  final CorpLayoutBreakpoint breakpoint;

  /// Uncommitted selection from the Personalize screen. Null when no edit
  /// is in progress.
  final Set<String>? draftSelection;

  final String? errorMessage;
  final String? saveErrorMessage;
  final DateTime? savedAt;

  bool get isReady => config != null;

  /// Whether the catalog in use is the shipped fallback, which is known to
  /// lag the environment.
  bool get isCatalogStale => catalogSource == CorpCatalogSource.bundledAsset;

  /// Components currently on the dashboard at [breakpoint], de-duplicated.
  List<String> get selectedComponents =>
      config?.selectedComponentsAt(breakpoint) ?? const [];

  /// The saved layout items at [breakpoint], de-duplicated by component and
  /// keeping the user's order — the render path's input.
  ///
  /// Returns items rather than names so the dashboard can honour each
  /// widget's stored `style` (`oj-lg-4`, `oj-sm-12`, …) when sizing it.
  List<CorpDashboardLayoutItem> get selectedItems {
    final items = config?.layoutFor(breakpoint) ?? const [];
    final seen = <String>{};
    final deduped = <CorpDashboardLayoutItem>[];
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
  List<CorpWidgetDefinition> availableWidgets(String userSegment) {
    return catalog.availableFor(
      userSegment: userSegment,
      authorizedComponents: authorized.authorized,
    );
  }

  CorpPersonalizationState copyWith({
    bool? isLoading,
    bool? isSaving,
    CorpDashboardConfig? config,
    CorpWidgetCatalog? catalog,
    CorpCatalogSource? catalogSource,
    CorpAuthorizedComponents? authorized,
    CorpLayoutBreakpoint? breakpoint,
    Set<String>? draftSelection,
    String? errorMessage,
    String? saveErrorMessage,
    DateTime? savedAt,
    bool? isUnavailable,
    bool clearError = false,
    bool clearSaveError = false,
    bool clearDraft = false,
  }) {
    return CorpPersonalizationState(
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

class CorpPersonalizationNotifier
    extends StateNotifier<CorpPersonalizationState> {
  CorpPersonalizationNotifier(this._ref)
      : super(const CorpPersonalizationState());

  final Ref _ref;
  bool _loadedOnce = false;
  Future<void>? _pendingLoad;

  /// Which dashboard to read and write, resolved from `me`. Null means the
  /// user has no personalizable dashboard and the feature is unavailable.
  CorpDashboardDescriptor? _descriptor;

  CorpDashboardDescriptor? get descriptor => _descriptor;

  Future<void> ensureLoaded(CorpUserProfile? profile) {
    if (_loadedOnce) return Future.value();
    return _pendingLoad ??= load(profile).whenComplete(() {
      _pendingLoad = null;
    });
  }

  /// Sets which breakpoint's layout is in play. Called from the dashboard
  /// as the viewport changes, so both mobile and desktop read and write
  /// their own layout.
  void setBreakpoint(CorpLayoutBreakpoint breakpoint) {
    if (state.breakpoint == breakpoint) return;
    // An in-flight draft belongs to the old breakpoint; drop it rather than
    // applying a phone selection to the desktop layout.
    state = state.copyWith(breakpoint: breakpoint, clearDraft: true);
  }

  Future<void> load(CorpUserProfile? profile) async {
    final descriptor = profile?.personalizableDashboard;
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
    final repository = _ref.read(corpDashboardRepositoryProvider);

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

    if (!mounted) return;
    _loadedOnce = true;

    final configResult = results[0];
    final authorizedResult = results[1];

    if (configResult is Success<CorpDashboardConfig>) {
      state = state.copyWith(
        isLoading: false,
        config: configResult.data,
        catalog: catalogResult.catalog,
        catalogSource: catalogResult.source,
        authorized: authorizedResult is Success<CorpAuthorizedComponents>
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
    if (!mounted) return;
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
  /// wipe the desktop dashboard (`CorpDashboardConfig.withLayout`).
  Future<bool> save() async {
    final config = state.config;
    final draft = state.draftSelection;
    if (config == null || draft == null) return false;

    state = state.copyWith(isSaving: true, clearSaveError: true);

    final existing = config.layoutFor(state.breakpoint);
    final items = <CorpDashboardLayoutItem>[];
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
        CorpDashboardLayoutItem(
          componentName: componentName,
          module: _moduleFor(componentName),
          data: '{}',
          style: _styleFor(state.breakpoint),
        ),
      );
    }

    final result = await _ref
        .read(corpDashboardRepositoryProvider)
        .saveConfig(config.withLayout(state.breakpoint, items));

    if (!mounted) return false;

    if (result is Success<CorpDashboardConfig>) {
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
    if (!mounted) return false;
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

  /// Oracle JET grid class for a newly added item. Flutter derives its own
  /// layout, but the value round-trips to the web client, so it has to be
  /// one the web grid understands.
  static String _styleFor(CorpLayoutBreakpoint breakpoint) {
    switch (breakpoint) {
      case CorpLayoutBreakpoint.small:
        return 'oj-sm-12';
      case CorpLayoutBreakpoint.medium:
        return 'oj-md-12';
      case CorpLayoutBreakpoint.large:
      case CorpLayoutBreakpoint.defaultLayout:
        return 'oj-lg-12';
    }
  }
}

final corpPersonalizationProvider = StateNotifierProvider<
    CorpPersonalizationNotifier, CorpPersonalizationState>(
  (ref) => CorpPersonalizationNotifier(ref),
);
