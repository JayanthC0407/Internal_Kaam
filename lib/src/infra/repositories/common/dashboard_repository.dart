import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_descriptor.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_dashboard_api.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_user_api.dart';
import 'package:ubci_bank/src/infra/network/dashboard_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Where a loaded widget catalog came from. Surfaced so the UI can say so
/// when it is running on the shipped copy, which is known to lag the
/// environment.
enum DashboardCatalogSource { environment, bundledAsset, none }

class DashboardCatalogResult {
  const DashboardCatalogResult({required this.catalog, required this.source});

  final DashboardWidgetCatalog catalog;
  final DashboardCatalogSource source;

  bool get isStale => source == DashboardCatalogSource.bundledAsset;
}

/// Personalized-dashboard data: the saved configuration, the authorization
/// set, and the widget catalog.
class DashboardRepository extends ObdxRepositoryBase {
  DashboardRepository({
    required ObdxDashboardApi dashboardApi,
    required ObdxUserApi userApi,
  })  : _api = dashboardApi,
        _userApi = userApi;

  final ObdxDashboardApi _api;
  final ObdxUserApi _userApi;

  /// Reads `me` and resolves the user's personalizable dashboard from it.
  ///
  /// For when the caller has no `me` response of its own — a restored
  /// session whose `me` call failed. Success is always a *resolved* lookup
  /// ([DashboardDescriptorFound] or [DashboardDescriptorAbsent]): a `me`
  /// this call read is authoritative even when it lists no dashboards.
  Future<ResponseHandler<DashboardDescriptorLookup>>
      fetchPersonalizableDashboard() async {
    try {
      final result = await _userApi.fetchProfile();
      return parseBody(result, (body) {
        // A 200 that is not a `me` body resolves nothing — fail it rather
        // than read it as "no dashboard".
        if (!DashboardDescriptor.isProfileResponse(body)) {
          throw StateError('Not a me response');
        }
        // With the role template, as the login path resolves it, so a
        // first-time user can personalize either way.
        return DashboardDescriptorLookup.fromProfileResponse(body);
      });
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// The user's saved dashboard.
  ///
  /// [dashboardClass] / [dashboardClassValue] must come from the caller's
  /// `me` response — see `resolveDashboardDto`.
  Future<ResponseHandler<DashboardConfig>> fetchConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async {
    try {
      final result = await _api.fetchDashboardConfig(
        dashboardClass: dashboardClass,
        dashboardClassValue: dashboardClassValue,
      );
      return parseBody(result, (body) {
        final config = DashboardConfig.fromPayload(body);
        if (config == null) throw StateError('No dashboardDTO in response');
        return config;
      });
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Saves [config] in full, then re-reads it from the host.
  ///
  /// [config] must be one that was loaded and then edited via
  /// `DashboardConfig.withLayout` — never assembled from scratch, or
  /// the breakpoints the user did not touch would be wiped.
  ///
  /// **The PUT response carries no layout.** It returns a `dashboardDTO`
  /// with only metadata (id, name, class), so parsing it yields a config
  /// whose every breakpoint is empty. Treating that as the new state is
  /// what silently blanked `medium` and `small` on the next save. The web
  /// client avoids this by re-fetching after saving (GET → PUT → GET in
  /// the capture), which is what this does; the config we sent is the
  /// fallback if that re-fetch fails, since the host just accepted it.
  Future<ResponseHandler<DashboardConfig>> saveConfig(
    DashboardConfig config,
  ) async {
    try {
      final result = await _api.saveDashboardConfig(
        dashboardId: config.dashboardId,
        payload: config.toUpdatePayload(),
      );

      // Surface a failed save as a failure — never fall through to the
      // re-fetch, or a rejected save would look like it worked.
      final saved = await parseBody(result, (body) => body);
      if (saved is! Success<Map<String, dynamic>>) {
        return mapFailure<DashboardConfig>(saved);
      }

      final refreshed = await fetchConfig(
        dashboardClass: config.dashboardClass ?? 'CUSTOM',
        dashboardClassValue: config.dashboardClassValue ?? 'custom',
      );
      if (refreshed is Success<DashboardConfig> && refreshed.data != null) {
        return refreshed;
      }
      return ResponseHandler.success(config, code: 200);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// Creates the user's own `CUSTOM` dashboard from [edited] — their role
  /// dashboard with their changes — the way the OBDX web client does on a
  /// new user's first save (`customize for new user.har`: `POST
  /// .../dashboards/user` → 201, then `me`, then `CUSTOM/custom`).
  ///
  /// Sent under fresh opaque names, never [edited]'s own: those belong to
  /// the shared role dashboard. The host's answer carries only the new
  /// dashboard's identity, so the layout is re-read; if that fails, what
  /// was sent — under the new id — stands in, since the host accepted it.
  Future<ResponseHandler<DashboardConfig>> createConfig(
    DashboardConfig edited,
  ) async {
    try {
      final draft = edited.withIdentity(
        dashboardName: DashboardConfig.newOpaqueName(),
        dashboardDescription: DashboardConfig.newOpaqueName(),
      );
      final result = await _api.createDashboardConfig(
        payload: draft.toUpdatePayload(),
      );
      final created = await parseBody(
        result,
        (body) {
          final dto = DashboardDescriptor.fromJson(
            ObdxApiUtils.asMap(body['dashboardDTO']),
          );
          if (!dto.isUsable) throw StateError('No dashboardId in response');
          return dto;
        },
        successCodes: const {200, 201},
      );
      if (created is! Success<DashboardDescriptor> || created.data == null) {
        return mapFailure<DashboardConfig>(created);
      }

      final dto = created.data!;
      final local = draft.withIdentity(
        dashboardId: dto.dashboardId,
        enterpriseRole: dto.enterpriseRole,
        dashboardClass: dto.dashboardClass.isEmpty ? 'CUSTOM' : dto.dashboardClass,
        dashboardClassValue: dto.dashboardClassValue.isEmpty
            ? 'custom'
            : dto.dashboardClassValue,
        isFactory: dto.isFactory,
      );
      final refreshed = await fetchConfig(
        dashboardClass: local.dashboardClass!,
        dashboardClassValue: local.dashboardClassValue!,
      );
      if (refreshed is Success<DashboardConfig> &&
          refreshed.data?.dashboardId == dto.dashboardId) {
        return refreshed;
      }
      return ResponseHandler.success(local, code: 201);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<DashboardAuthorizedComponents>>
      fetchAuthorizedComponents() async {
    try {
      final result = await _api.fetchAuthorizedComponents();
      return parseBody(result, DashboardAuthorizedComponents.fromPayload);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  /// The widget catalog, preferring the environment's copy.
  ///
  /// The shipped asset is only a fallback: the environment's catalog is
  /// demonstrably richer (the real Personalize screen lists modules the
  /// shipped file does not contain at all), so treating the bundled copy
  /// as the source of truth would hide widgets users actually have.
  ///
  /// Never fails outright — a catalog that cannot be loaded at all returns
  /// an empty one with [DashboardCatalogSource.none], which callers render as
  /// "no widgets available to add" rather than an error.
  ///
  /// Each step logs a one-line outcome to the console, release builds
  /// included — nothing about the user, only where the catalog came from
  /// and, when the server's copy was not usable, what came back instead.
  /// A deployment whose web server does not route `/framework/` to OBDX
  /// shows up here as HTML or a 404 rather than as a silent empty list.
  Future<DashboardCatalogResult> fetchCatalog() async {
    try {
      final result = await _api.fetchModuleComponents();
      final parsed =
          await parseBody(result, DashboardWidgetCatalog.fromPayload);
      if (parsed is Success<DashboardWidgetCatalog> &&
          parsed.data != null &&
          !parsed.data!.isEmpty) {
        _log('using the server\'s moduleComponents.json '
            '(${parsed.data!.definitions.length} widgets)');
        return DashboardCatalogResult(
          catalog: parsed.data!,
          source: DashboardCatalogSource.environment,
        );
      }
      _log('the server\'s moduleComponents.json was not usable — '
          '${_describe(result)}; trying the built-in list');
    } catch (error) {
      _log('the server\'s moduleComponents.json failed '
          '(${error.runtimeType}); trying the built-in list');
    }

    try {
      final raw = await rootBundle.loadString(
        DashboardApiConst.moduleComponentsAsset,
      );
      final catalog = DashboardWidgetCatalog.fromPayload(jsonDecode(raw));
      if (!catalog.isEmpty) {
        _log('using the built-in widget list '
            '(${catalog.definitions.length} widgets)');
        return DashboardCatalogResult(
          catalog: catalog,
          source: DashboardCatalogSource.bundledAsset,
        );
      }
      _log('the built-in widget list is empty');
    } catch (error) {
      _log('the built-in widget list '
          '(${DashboardApiConst.moduleComponentsAsset}) could not be read '
          '(${error.runtimeType})');
    }

    return const DashboardCatalogResult(
      catalog: DashboardWidgetCatalog.empty,
      source: DashboardCatalogSource.none,
    );
  }

  /// What a catalog response actually was, for the log.
  static String _describe(ResponseHandler<Map<String, dynamic>> result) {
    if (result is Success<Map<String, dynamic>>) {
      final data = result.data ?? const {};
      final preview = (data['bodyPreview'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), ' ');
      return 'HTTP ${data['statusCode']} from ${data['url']}, '
          'content-type ${data['contentType']}, '
          'body starts "$preview"';
    }
    if (result is Error<Map<String, dynamic>>) {
      return 'HTTP ${result.code}';
    }
    return result.runtimeType.toString();
  }

  static void _log(String message) =>
      debugPrint('[Personalize] Widget catalog: $message');
}
