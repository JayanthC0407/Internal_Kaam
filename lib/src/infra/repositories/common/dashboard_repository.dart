import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_dashboard_api.dart';
import 'package:ubci_bank/src/infra/network/dashboard_api_constants.dart';
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
  DashboardRepository({required ObdxDashboardApi dashboardApi})
      : _api = dashboardApi;

  final ObdxDashboardApi _api;

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
  Future<DashboardCatalogResult> fetchCatalog() async {
    try {
      final result = await _api.fetchModuleComponents();
      final parsed = await parseBody(result, DashboardWidgetCatalog.fromPayload);
      if (parsed is Success<DashboardWidgetCatalog> &&
          parsed.data != null &&
          !parsed.data!.isEmpty) {
        return DashboardCatalogResult(
          catalog: parsed.data!,
          source: DashboardCatalogSource.environment,
        );
      }
    } catch (_) {
      // Fall through to the bundled copy.
    }

    try {
      final raw = await rootBundle.loadString(
        DashboardApiConst.moduleComponentsAsset,
      );
      final catalog = DashboardWidgetCatalog.fromPayload(jsonDecode(raw));
      if (!catalog.isEmpty) {
        return DashboardCatalogResult(
          catalog: catalog,
          source: DashboardCatalogSource.bundledAsset,
        );
      }
    } catch (_) {
      // Fall through to empty.
    }

    return const DashboardCatalogResult(
      catalog: DashboardWidgetCatalog.empty,
      source: DashboardCatalogSource.none,
    );
  }
}
