import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:ubci_bank/src/core/models/corp/corp_dashboard_config.dart';
import 'package:ubci_bank/src/core/models/corp/corp_widget_definition.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_dashboard_api.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_api_constants.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

/// Where a loaded widget catalog came from. Surfaced so the UI can say so
/// when it is running on the shipped copy, which is known to lag the
/// environment.
enum CorpCatalogSource { environment, bundledAsset, none }

class CorpCatalogResult {
  const CorpCatalogResult({required this.catalog, required this.source});

  final CorpWidgetCatalog catalog;
  final CorpCatalogSource source;

  bool get isStale => source == CorpCatalogSource.bundledAsset;
}

/// Personalized-dashboard data: the saved configuration, the authorization
/// set, and the widget catalog.
class CorpDashboardRepository extends CorpRepositoryBase {
  CorpDashboardRepository({required ObdxCorpDashboardApi dashboardApi})
      : _api = dashboardApi;

  final ObdxCorpDashboardApi _api;

  /// The user's saved dashboard.
  ///
  /// [dashboardClass] / [dashboardClassValue] must come from the caller's
  /// `me` response — see `resolveDashboardDto`.
  Future<ResponseHandler<CorpDashboardConfig>> fetchConfig({
    required String dashboardClass,
    required String dashboardClassValue,
  }) async {
    try {
      final result = await _api.fetchDashboardConfig(
        dashboardClass: dashboardClass,
        dashboardClassValue: dashboardClassValue,
      );
      return parseBody(result, (body) {
        final config = CorpDashboardConfig.fromPayload(body);
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
  /// `CorpDashboardConfig.withLayout` — never assembled from scratch, or
  /// the breakpoints the user did not touch would be wiped.
  ///
  /// **The PUT response carries no layout.** It returns a `dashboardDTO`
  /// with only metadata (id, name, class), so parsing it yields a config
  /// whose every breakpoint is empty. Treating that as the new state is
  /// what silently blanked `medium` and `small` on the next save. The web
  /// client avoids this by re-fetching after saving (GET → PUT → GET in
  /// the capture), which is what this does; the config we sent is the
  /// fallback if that re-fetch fails, since the host just accepted it.
  Future<ResponseHandler<CorpDashboardConfig>> saveConfig(
    CorpDashboardConfig config,
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
        return mapFailure<CorpDashboardConfig>(saved);
      }

      final refreshed = await fetchConfig(
        dashboardClass: config.dashboardClass ?? 'CUSTOM',
        dashboardClassValue: config.dashboardClassValue ?? 'custom',
      );
      if (refreshed is Success<CorpDashboardConfig> && refreshed.data != null) {
        return refreshed;
      }
      return ResponseHandler.success(config, code: 200);
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<CorpAuthorizedComponents>>
      fetchAuthorizedComponents() async {
    try {
      final result = await _api.fetchAuthorizedComponents();
      return parseBody(result, CorpAuthorizedComponents.fromPayload);
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
  /// an empty one with [CorpCatalogSource.none], which callers render as
  /// "no widgets available to add" rather than an error.
  Future<CorpCatalogResult> fetchCatalog() async {
    try {
      final result = await _api.fetchModuleComponents();
      final parsed = await parseBody(result, CorpWidgetCatalog.fromPayload);
      if (parsed is Success<CorpWidgetCatalog> &&
          parsed.data != null &&
          !parsed.data!.isEmpty) {
        return CorpCatalogResult(
          catalog: parsed.data!,
          source: CorpCatalogSource.environment,
        );
      }
    } catch (_) {
      // Fall through to the bundled copy.
    }

    try {
      final raw = await rootBundle.loadString(
        CorpApiConst.moduleComponentsAsset,
      );
      final catalog = CorpWidgetCatalog.fromPayload(jsonDecode(raw));
      if (!catalog.isEmpty) {
        return CorpCatalogResult(
          catalog: catalog,
          source: CorpCatalogSource.bundledAsset,
        );
      }
    } catch (_) {
      // Fall through to empty.
    }

    return const CorpCatalogResult(
      catalog: CorpWidgetCatalog.empty,
      source: CorpCatalogSource.none,
    );
  }
}
