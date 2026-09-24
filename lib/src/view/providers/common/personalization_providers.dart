import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_descriptor.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_grid_span.dart';
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
    userApi: ref.watch(obdxUserApiProvider),
  ),
);

/// Where `me/components` — the authorization set — stands.
///
/// Explicit rather than inferred from whether the set is empty: an empty
/// set that *loaded* means "nothing is authorized", while an empty set that
/// *failed* to load means "we do not know". Treating those the same, as an
/// earlier version did, made a failed call silently authorize everything.
enum DashboardAuthorizationStatus { notLoaded, loading, loaded, failed }

/// What the personalized part of a dashboard should render right now.
///
/// Computed once, here, so the Retail and Corporate dashboards cannot
/// disagree about it — each previously made this decision separately, and
/// they drifted (Corporate kept restoring its defaults for an intentionally
/// empty dashboard after Retail had stopped).
enum PersonalizedBodyStatus {
  /// Configuration or authorization still loading. Render a placeholder —
  /// never the defaults, or the dashboard visibly swaps under the user.
  loading,

  /// `me` says the user has no personalizable dashboard. Render the designed
  /// default layout. Final for the session.
  unavailable,

  /// The user has a personalizable dashboard, but it could not be loaded —
  /// its configuration, or the `me` response that locates it. Render an
  /// error with a retry, **not** the defaults: the saved layout is unknown,
  /// and the defaults would put back widgets the user may have removed.
  loadFailed,

  /// A configuration loaded but authorization did not. Render an error with
  /// a retry, **not** the saved widgets: without the authorization set we
  /// cannot tell which of them the user may see, so this fails closed.
  authorizationFailed,

  /// A configuration and authorization loaded, and nothing is left to show
  /// — the user unselected everything, or nothing they selected is
  /// authorized. Render an empty state, **not** the defaults: restoring
  /// defaults here puts back widgets the user deliberately removed.
  empty,

  /// Render [PersonalizationState.renderableItems].
  ready,
}

/// State of the personalized dashboard: the saved configuration, the
/// catalog it is chosen from, and the authorization set both are filtered
/// against.
///
/// Holds a *draft* selection separate from the saved [config] so the
/// Personalize panel can toggle freely and only commit on Save.
class PersonalizationState {
  const PersonalizationState({
    this.hasStarted = false,
    this.isLoading = false,
    this.isSaving = false,
    this.config,
    this.catalog = DashboardWidgetCatalog.empty,
    this.catalogSource = DashboardCatalogSource.none,
    this.authorized = DashboardAuthorizedComponents.empty,
    this.authorizationStatus = DashboardAuthorizationStatus.notLoaded,
    this.authorizationError,
    this.breakpoint = DashboardBreakpoint.large,
    this.draftSelection,
    this.errorMessage,
    this.saveErrorMessage,
    this.savedAt,
    this.isUnavailable = false,
    this.configLoadFailed = false,
  });

  /// True when the last load could not produce a configuration — the
  /// configuration request failed, or `me` had to be read and could not
  /// be. [errorMessage] says why; `PersonalizationNotifier.retry` tries
  /// again.
  final bool configLoadFailed;

  /// False until the first load begins. Distinguishes the very first frame
  /// — before the dashboard's post-frame load has run — from a settled
  /// "nothing to show", so that frame renders a placeholder instead of
  /// flashing the default layout.
  final bool hasStarted;

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

  /// Meaningful only when [authorizationStatus] is
  /// [DashboardAuthorizationStatus.loaded].
  final DashboardAuthorizedComponents authorized;

  final DashboardAuthorizationStatus authorizationStatus;
  final String? authorizationError;

  /// Which breakpoint's layout is being read and written. Set from the
  /// viewport so a phone edits `small` and a desktop edits `large`, exactly
  /// as the web client does.
  final DashboardBreakpoint breakpoint;

  /// Uncommitted selection from the Personalize panel. Null when no edit is
  /// in progress.
  final Set<String>? draftSelection;

  final String? errorMessage;
  final String? saveErrorMessage;
  final DateTime? savedAt;

  bool get isReady => config != null;

  bool get isAuthorizationLoaded =>
      authorizationStatus == DashboardAuthorizationStatus.loaded;

  /// Whether [componentName] may be shown. False whenever authorization has
  /// not loaded — unknown is not the same as allowed.
  bool isAuthorized(String componentName) =>
      isAuthorizationLoaded && authorized.contains(componentName);

  /// Whether the catalog in use is the shipped fallback, which is known to
  /// lag the environment.
  bool get isCatalogStale =>
      catalogSource == DashboardCatalogSource.bundledAsset;

  /// Components currently on the dashboard at [breakpoint], de-duplicated.
  List<String> get selectedComponents =>
      config?.selectedComponentsAt(breakpoint) ?? const [];

  /// The saved layout items at [breakpoint], de-duplicated by component and
  /// keeping the user's order.
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

  /// [selectedItems] the user is authorized to see — the render path's
  /// input. Filters on authorization only, never the catalog: a saved
  /// layout can legitimately hold components the catalog has never listed.
  List<DashboardLayoutItem> get renderableItems => [
        for (final item in selectedItems)
          if (isAuthorized(item.componentName)) item,
      ];

  PersonalizedBodyStatus get bodyStatus {
    if (isUnavailable) return PersonalizedBodyStatus.unavailable;
    if (!hasStarted) return PersonalizedBodyStatus.loading;
    if (isLoading && !isReady) return PersonalizedBodyStatus.loading;
    if (!isReady) {
      // Otherwise the app is on its way to sign-in (session expired) and
      // there is nothing to show or retry here.
      return configLoadFailed
          ? PersonalizedBodyStatus.loadFailed
          : PersonalizedBodyStatus.loading;
    }

    switch (authorizationStatus) {
      case DashboardAuthorizationStatus.notLoaded:
      case DashboardAuthorizationStatus.loading:
        return PersonalizedBodyStatus.loading;
      case DashboardAuthorizationStatus.failed:
        return PersonalizedBodyStatus.authorizationFailed;
      case DashboardAuthorizationStatus.loaded:
        return renderableItems.isEmpty
            ? PersonalizedBodyStatus.empty
            : PersonalizedBodyStatus.ready;
    }
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

  /// Widgets the user may add, per §17. Empty until authorization has
  /// loaded — offering widgets we cannot check would let a user select
  /// something they are not entitled to.
  List<DashboardWidgetDefinition> availableWidgets(String userSegment) {
    if (!isAuthorizationLoaded) return const [];
    return catalog.availableFor(
      userSegment: userSegment,
      authorizedComponents: authorized.authorized,
    );
  }

  PersonalizationState copyWith({
    bool? hasStarted,
    bool? isLoading,
    bool? isSaving,
    DashboardConfig? config,
    DashboardWidgetCatalog? catalog,
    DashboardCatalogSource? catalogSource,
    DashboardAuthorizedComponents? authorized,
    DashboardAuthorizationStatus? authorizationStatus,
    String? authorizationError,
    DashboardBreakpoint? breakpoint,
    Set<String>? draftSelection,
    String? errorMessage,
    String? saveErrorMessage,
    DateTime? savedAt,
    bool? isUnavailable,
    bool? configLoadFailed,
    bool clearError = false,
    bool clearSaveError = false,
    bool clearDraft = false,
    bool clearAuthorizationError = false,
  }) {
    return PersonalizationState(
      hasStarted: hasStarted ?? this.hasStarted,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      config: config ?? this.config,
      catalog: catalog ?? this.catalog,
      catalogSource: catalogSource ?? this.catalogSource,
      authorized: authorized ?? this.authorized,
      authorizationStatus: authorizationStatus ?? this.authorizationStatus,
      authorizationError: clearAuthorizationError
          ? null
          : (authorizationError ?? this.authorizationError),
      breakpoint: breakpoint ?? this.breakpoint,
      draftSelection:
          clearDraft ? null : (draftSelection ?? this.draftSelection),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      saveErrorMessage:
          clearSaveError ? null : (saveErrorMessage ?? this.saveErrorMessage),
      savedAt: savedAt ?? this.savedAt,
      isUnavailable: isUnavailable ?? this.isUnavailable,
      configLoadFailed: configLoadFailed ?? this.configLoadFailed,
    );
  }
}

class PersonalizationNotifier extends StateNotifier<PersonalizationState> {
  PersonalizationNotifier(this._ref) : super(const PersonalizationState());

  final Ref _ref;

  /// True once a load has *settled*: the configuration loaded, or `me`
  /// said there is no personalizable dashboard. A failed load leaves it
  /// false, so [retry] — or a later [ensureLoaded] — tries again.
  bool _loadedOnce = false;
  Future<void>? _pendingLoad;

  /// The user this state belongs to, normalised. See [ensureLoaded].
  String? _owner;

  /// Bumped whenever the owner changes. See [_isCurrent].
  int _ownerGeneration = 0;

  /// What is known about the user's dashboard — as the caller passed it,
  /// or as resolved from our own `me` read. Kept so a retry starts from the
  /// most resolved answer rather than reading `me` again.
  DashboardDescriptorLookup _lookup = const DashboardDescriptorUnknown();

  /// Which dashboard to read and write, once resolved. Null until then, and
  /// when the user has none.
  DashboardDescriptor? _descriptor;

  DashboardDescriptor? get descriptor => _descriptor;

  /// Loads once per user from [lookup], which the caller builds from the
  /// `me` response it holds — Corporate from its parsed profile, Retail via
  /// `DashboardDescriptorLookup.fromProfileResponse`. When the caller has
  /// no `me` ([DashboardDescriptorUnknown]), this reads `me` itself.
  ///
  /// [userKey] scopes the state to the signed-in user. If it differs from
  /// the user this state was loaded for, everything is discarded first:
  /// one user's dashboard configuration, catalog selection or authorization
  /// set must never be shown to the next user to sign in on the device.
  ///
  /// Logout also clears this state — `resetUserSessionState` invalidates
  /// the provider and [SessionGeneration] advances — and the provider is
  /// `autoDispose`; this check is the backstop for any path that reaches a
  /// different user without going through logout.
  Future<void> ensureLoaded(
    DashboardDescriptorLookup lookup, {
    required String userKey,
  }) {
    final owner = userKey.trim().toLowerCase();
    if (_owner != null && _owner != owner) _resetForNewOwner();
    _owner = owner;

    // "No dashboard" is final — unless the caller now holds a `me` that
    // does list one, which is newer information than what settled it.
    if (_loadedOnce &&
        _lookup is DashboardDescriptorAbsent &&
        lookup is DashboardDescriptorFound) {
      _loadedOnce = false;
    }

    if (_loadedOnce) return Future.value();
    final pending = _pendingLoad;
    if (pending != null) return pending;

    // Never let "we don't have `me`" overwrite something already resolved.
    if (lookup is! DashboardDescriptorUnknown) _lookup = lookup;
    return _startLoad();
  }

  /// Tries again after a failure — whichever part failed.
  ///
  /// With no configuration yet, everything is reloaded: `me` if it was
  /// never resolved, then the configuration, authorization set and catalog.
  /// With a configuration in hand only authorization can have failed, so
  /// only that is re-requested, keeping the configuration and any unsaved
  /// edit in the Personalize panel.
  ///
  /// Does nothing while a load is running (returns it), before the first
  /// [ensureLoaded], or once `me` has said there is no dashboard.
  Future<void> retry() {
    final pending = _pendingLoad;
    if (pending != null) return pending;
    if (_owner == null || state.isUnavailable) return Future.value();
    if (state.config != null) return _reloadAuthorization();
    _loadedOnce = false;
    return _startLoad();
  }

  Future<void> _startLoad() {
    late final Future<void> load;
    load = _load(_lookup).whenComplete(() {
      // Only clear our own marker — a reset may already have replaced it.
      if (identical(_pendingLoad, load)) _pendingLoad = null;
    });
    _pendingLoad = load;
    return load;
  }

  void _resetForNewOwner() {
    _ownerGeneration++;
    _loadedOnce = false;
    _pendingLoad = null;
    _lookup = const DashboardDescriptorUnknown();
    _descriptor = null;
    state = PersonalizationState(breakpoint: state.breakpoint);
  }

  /// Which session and which user an async operation started under.
  /// Captured before the first await; checked with [_isCurrent] after each.
  _Epoch _epoch() => _Epoch(
        session: SessionGeneration.current,
        owner: _ownerGeneration,
      );

  /// Whether a result that started under [epoch] may still be published.
  ///
  /// Two independent guards, and either moving on means the result belongs
  /// to someone else: [SessionGeneration] advances on every logout,
  /// app-wide; [_ownerGeneration] advances when a different user reaches
  /// this same state without a logout in between (see [ensureLoaded]).
  bool _isCurrent(_Epoch epoch) =>
      mounted &&
      SessionGeneration.isCurrent(epoch.session) &&
      epoch.owner == _ownerGeneration;

  /// Sets which breakpoint's layout is in play. Called from the dashboard
  /// as the viewport changes, so both mobile and desktop read and write
  /// their own layout.
  void setBreakpoint(DashboardBreakpoint breakpoint) {
    if (state.breakpoint == breakpoint) return;
    // An in-flight draft belongs to the old breakpoint; drop it rather than
    // applying a phone selection to the desktop layout.
    state = state.copyWith(breakpoint: breakpoint, clearDraft: true);
  }

  Future<void> _load(DashboardDescriptorLookup lookup) async {
    final epoch = _epoch();
    final repository = _ref.read(dashboardRepositoryProvider);

    state = state.copyWith(
      hasStarted: true,
      isLoading: true,
      isUnavailable: false,
      configLoadFailed: false,
      clearError: true,
    );

    // The caller had no `me` — a restored session whose own `me` call
    // failed. Read it here rather than concluding there is no dashboard.
    var resolved = lookup;
    if (resolved is DashboardDescriptorUnknown) {
      final result = await repository.fetchPersonalizableDashboard();
      if (!_isCurrent(epoch)) return;
      if (result is! Success<DashboardDescriptorLookup> ||
          result.data == null) {
        await _failLoad(
          epoch,
          result,
          fallback: 'Could not load your dashboard.',
        );
        return;
      }
      resolved = result.data!;
      _lookup = resolved;
    }

    if (resolved is DashboardDescriptorAbsent) {
      _descriptor = null;
      _loadedOnce = true;
      state = state.copyWith(isLoading: false, isUnavailable: true);
      return;
    }
    if (resolved is! DashboardDescriptorFound) {
      // Unreachable: a `me` read always resolves. Fail rather than guess.
      await _failLoad(
        epoch,
        null,
        fallback: 'Could not load your dashboard.',
      );
      return;
    }
    final descriptor = resolved.descriptor;
    _descriptor = descriptor;

    state = state.copyWith(
      authorizationStatus: DashboardAuthorizationStatus.loading,
      clearAuthorizationError: true,
    );

    // The catalog and authorization set are independent of the config, so
    // fetch them together.
    final results = await Future.wait([
      repository.fetchConfig(
        dashboardClass: descriptor.dashboardClass,
        dashboardClassValue: descriptor.dashboardClassValue,
      ),
      repository.fetchAuthorizedComponents(),
    ]);
    final catalogResult = await repository.fetchCatalog();

    if (!_isCurrent(epoch)) return;

    final configResult = results[0];
    final authorizedResult = results[1];
    final authorization = await _authorizationFrom(authorizedResult);
    if (!_isCurrent(epoch)) return;

    if (configResult is Success<DashboardConfig> && configResult.data != null) {
      // Settled only now — a failed configuration must stay retryable.
      _loadedOnce = true;
      state = state.copyWith(
        isLoading: false,
        config: configResult.data,
        catalog: catalogResult.catalog,
        catalogSource: catalogResult.source,
        authorized: authorization.authorized,
        authorizationStatus: authorization.status,
        authorizationError: authorization.error,
        clearAuthorizationError: authorization.error == null,
        clearError: true,
        clearDraft: true,
      );
      return;
    }

    // Keep what did load, so a retry only has the configuration to fix.
    state = state.copyWith(
      catalog: catalogResult.catalog,
      catalogSource: catalogResult.source,
      authorized: authorization.authorized,
      authorizationStatus: authorization.status,
      authorizationError: authorization.error,
      clearAuthorizationError: authorization.error == null,
    );
    await _failLoad(
      epoch,
      configResult,
      fallback: 'Could not load your dashboard configuration.',
    );
  }

  /// Settles a load that produced no configuration as failed and
  /// retryable — [_loadedOnce] stays false.
  Future<void> _failLoad(
    _Epoch epoch,
    ResponseHandler<dynamic>? result, {
    required String fallback,
  }) async {
    if (SessionExpiryCoordinator.instance.isHandling) {
      // On its way to sign-in; nothing here is worth retrying.
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    final l10n = await AppLocalizationsHelper.current();
    if (!_isCurrent(epoch)) return;
    state = state.copyWith(
      isLoading: false,
      configLoadFailed: true,
      errorMessage: result == null
          ? fallback
          : result.resolveUserMessage(l10n: l10n, fallback: fallback),
    );
  }

  /// Re-requests only the authorization set, after it failed. See [retry].
  Future<void> _reloadAuthorization() async {
    if (_descriptor == null) return;
    if (state.authorizationStatus == DashboardAuthorizationStatus.loading) {
      return;
    }
    final epoch = _epoch();

    state = state.copyWith(
      authorizationStatus: DashboardAuthorizationStatus.loading,
      clearAuthorizationError: true,
    );
    final result = await _ref
        .read(dashboardRepositoryProvider)
        .fetchAuthorizedComponents();
    if (!_isCurrent(epoch)) return;

    final authorization = await _authorizationFrom(result);
    if (!_isCurrent(epoch)) return;
    state = state.copyWith(
      authorized: authorization.authorized,
      authorizationStatus: authorization.status,
      authorizationError: authorization.error,
      clearAuthorizationError: authorization.error == null,
    );
  }

  Future<_AuthorizationOutcome> _authorizationFrom(
    ResponseHandler<dynamic> result,
  ) async {
    if (result is Success<DashboardAuthorizedComponents> &&
        result.data != null) {
      return _AuthorizationOutcome(
        status: DashboardAuthorizationStatus.loaded,
        authorized: result.data!,
      );
    }
    if (SessionExpiryCoordinator.instance.isHandling) {
      return const _AuthorizationOutcome(
        status: DashboardAuthorizationStatus.failed,
        authorized: DashboardAuthorizedComponents.empty,
      );
    }
    final l10n = await AppLocalizationsHelper.current();
    return _AuthorizationOutcome(
      status: DashboardAuthorizationStatus.failed,
      authorized: DashboardAuthorizedComponents.empty,
      error: result.resolveUserMessage(
        l10n: l10n,
        fallback: 'Could not load your widget permissions.',
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

  /// Why [save] would refuse right now, or null if it would proceed.
  ///
  /// Exposed so the panel can disable Save and say why, rather than let the
  /// user press it and find out.
  String? get saveBlockedReason {
    final config = state.config;
    final descriptor = _descriptor;
    if (config == null || descriptor == null) {
      return 'Your dashboard has not loaded yet.';
    }
    // Only ever write to the user's own CUSTOM dashboard. Checked on both
    // what `me` described *and* what the host actually returned, because a
    // host could answer a CUSTOM request with the factory dashboard for a
    // user who has none — and the factory record is shared by every user
    // of the type.
    if (!descriptor.isUserCustom ||
        !config.isUserCustom ||
        config.dashboardId != descriptor.dashboardId) {
      return 'This dashboard cannot be personalized yet.';
    }
    if (!state.isAuthorizationLoaded) {
      return 'Your widget permissions have not loaded.';
    }
    return null;
  }

  /// Commits the draft to the host.
  ///
  /// Only the current breakpoint's layout is rewritten; every other
  /// breakpoint — and `waterfallLayout` — round-trips untouched, so
  /// personalizing on a phone cannot wipe the desktop dashboard
  /// (`DashboardConfig.withLayout`).
  Future<bool> save() async {
    final config = state.config;
    final draft = state.draftSelection;
    if (config == null || draft == null) return false;

    final blocked = saveBlockedReason;
    if (blocked != null) {
      state = state.copyWith(saveErrorMessage: blocked);
      return false;
    }

    final epoch = _epoch();
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

    // Anything newly switched on is appended, sized from the catalog for
    // the breakpoint being edited.
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

    if (!_isCurrent(epoch)) return false;

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
    if (!_isCurrent(epoch)) return false;
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
      DashboardBreakpoint.large || DashboardBreakpoint.defaultLayout => 'oj-lg',
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

class _Epoch {
  const _Epoch({required this.session, required this.owner});

  final int session;
  final int owner;
}

class _AuthorizationOutcome {
  const _AuthorizationOutcome({
    required this.status,
    required this.authorized,
    this.error,
  });

  final DashboardAuthorizationStatus status;
  final DashboardAuthorizedComponents authorized;
  final String? error;
}

/// `autoDispose` so the state is discarded as soon as no dashboard is
/// watching it — logging out pops the dashboard, which drops the state
/// before the next user signs in. [PersonalizationNotifier.ensureLoaded]'s
/// user check is the backstop for any path that keeps it alive across a
/// user change.
final personalizationProvider = StateNotifierProvider.autoDispose<
    PersonalizationNotifier, PersonalizationState>(
  (ref) => PersonalizationNotifier(ref),
);
