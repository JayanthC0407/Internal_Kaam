/// One entry of the OBDX widget catalog (`moduleComponents.json`).
///
/// The catalog says what a component *is* — which module owns it, which
/// user segments it applies to, its responsive widths. It does **not** say
/// whether a given user may use it (that is `authorizedUIComponents`) or
/// whether they currently have it (that is the dashboard configuration).
/// Those three are separate concepts and must not be collapsed.
class CorpWidgetDefinition {
  const CorpWidgetDefinition({
    required this.componentName,
    required this.module,
    required this.segments,
    this.widths = const <String, String>{},
    this.height,
    this.type,
    this.isVisible,
    this.isWidget,
    this.inputOptions = const <String, List<String>>{},
  });

  /// Stable widget key — the identity used everywhere. Never the display
  /// name.
  final String componentName;

  /// Owning OBDX module, e.g. `corporateDashboard`, `cash-management`.
  final String module;

  /// `segment` — user types this applies to, or `common` for any.
  final List<String> segments;

  /// Oracle JET column widths keyed by breakpoint (`large`/`medium`/`small`).
  final Map<String, String> widths;

  final String? height;
  final String? type;

  /// `isVisible` / `isWidget`. **Null means the catalog has no opinion** —
  /// 10 corporate-eligible entries omit both keys entirely (including
  /// `currency-exposure`, which appears on real saved dashboards), so a
  /// missing flag must not exclude the component.
  final bool? isVisible;
  final bool? isWidget;

  /// `input.values` — the variants one component supports, e.g.
  /// `dashboard-quick-links` accepts a `type` of `payments-quick-links`.
  /// Retained because the layout item's `data` field selects among these.
  final Map<String, List<String>> inputOptions;

  /// Whether this entry may be offered on the personalize screen.
  ///
  /// Explicitly `false` on either flag excludes it; absent flags do not.
  bool get isSelectable => isVisible != false && isWidget != false;

  /// Whether the component applies to [userSegment], per §17's rule:
  /// the segment list contains the user's role, or the wildcard `common`.
  bool appliesToSegment(String userSegment) {
    final target = userSegment.trim().toLowerCase();
    for (final segment in segments) {
      final value = segment.trim().toLowerCase();
      if (value == 'common' || value == target) return true;
    }
    return false;
  }

  /// Column width for [breakpoint], when the catalog specifies one.
  String? widthFor(String breakpoint) => widths[breakpoint];

  factory CorpWidgetDefinition.fromJson(Map<String, dynamic> json) {
    final segmentRaw = json['segment'];
    final segments = segmentRaw is List
        ? segmentRaw
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList()
        : const <String>[];

    final widthRaw = json['width'];
    final widths = <String, String>{};
    if (widthRaw is Map) {
      widthRaw.forEach((key, value) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) widths[key.toString()] = text;
      });
    }

    final inputOptions = <String, List<String>>{};
    final input = json['input'];
    if (input is Map) {
      final values = input['values'];
      if (values is Map) {
        values.forEach((key, value) {
          if (value is! List) return;
          inputOptions[key.toString()] = value
              .map((entry) => entry?.toString().trim() ?? '')
              .where((entry) => entry.isNotEmpty)
              .toList();
        });
      }
    }

    return CorpWidgetDefinition(
      componentName: (json['componentName'] ?? '').toString().trim(),
      module: (json['module'] ?? '').toString().trim(),
      segments: segments,
      widths: widths,
      height: _trimmed(json['height']),
      type: _trimmed(json['type']),
      isVisible: json['isVisible'] is bool ? json['isVisible'] as bool : null,
      isWidget: json['isWidget'] is bool ? json['isWidget'] as bool : null,
      inputOptions: inputOptions,
    );
  }

  static String? _trimmed(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}

/// The parsed `moduleComponents.json` catalog.
class CorpWidgetCatalog {
  const CorpWidgetCatalog({required this.definitions});

  static const empty = CorpWidgetCatalog(definitions: <CorpWidgetDefinition>[]);

  final List<CorpWidgetDefinition> definitions;

  bool get isEmpty => definitions.isEmpty;

  CorpWidgetDefinition? byName(String componentName) {
    for (final definition in definitions) {
      if (definition.componentName == componentName) return definition;
    }
    return null;
  }

  /// §17's availability rule: applicable to the user's segment **and**
  /// authorized for them **and** not explicitly hidden by the catalog.
  ///
  /// Note this governs what the personalize screen *offers*. It is
  /// deliberately not used to decide what to *render* — a user's saved
  /// dashboard can legitimately hold components this catalog has never
  /// heard of (5 of the 10 on the captured dashboard), because the catalog
  /// ships with the web app and can lag the environment.
  List<CorpWidgetDefinition> availableFor({
    required String userSegment,
    required Set<String> authorizedComponents,
  }) {
    return definitions
        .where((definition) =>
            definition.isSelectable &&
            definition.appliesToSegment(userSegment) &&
            authorizedComponents.contains(definition.componentName))
        .toList();
  }

  static CorpWidgetCatalog fromPayload(dynamic data) {
    final root = _unwrap(data);
    if (root == null) return empty;
    final raw = root['components'];
    if (raw is! List) return empty;

    final definitions = <CorpWidgetDefinition>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final definition =
          CorpWidgetDefinition.fromJson(Map<String, dynamic>.from(item));
      if (definition.componentName.isEmpty) continue;
      definitions.add(definition);
    }
    return CorpWidgetCatalog(definitions: definitions);
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('components')) return map;
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }
}

/// `GET /digx-common/user/v1/me/components` — what this user is entitled to.
///
/// `authorizedUIComponents` is a flat list of ~2500 UI component names
/// covering the whole application, not just dashboard widgets, so it is an
/// authorization set to check against — never a widget list in itself.
class CorpAuthorizedComponents {
  const CorpAuthorizedComponents({
    required this.authorized,
    this.defaultDashboards = const <String>[],
  });

  static const empty = CorpAuthorizedComponents(authorized: <String>{});

  final Set<String> authorized;
  final List<String> defaultDashboards;

  bool contains(String componentName) => authorized.contains(componentName);

  bool get isEmpty => authorized.isEmpty;

  /// True when we actually hold an authorization set. Callers use this to
  /// distinguish "not authorized" from "we never loaded the set" — the
  /// latter must not silently hide every widget.
  bool get isNotEmpty => authorized.isNotEmpty;

  static CorpAuthorizedComponents fromPayload(dynamic data) {
    final root = _unwrap(data);
    if (root == null) return empty;

    final raw = root['authorizedUIComponents'];
    final authorized = <String>{};
    if (raw is List) {
      for (final value in raw) {
        final name = value?.toString().trim() ?? '';
        if (name.isNotEmpty) authorized.add(name);
      }
    }

    final dashboardsRaw = root['defaultDashboards'];
    final dashboards = <String>[];
    if (dashboardsRaw is List) {
      for (final value in dashboardsRaw) {
        final name = value?.toString().trim() ?? '';
        if (name.isNotEmpty) dashboards.add(name);
      }
    }

    return CorpAuthorizedComponents(
      authorized: authorized,
      defaultDashboards: dashboards,
    );
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('authorizedUIComponents')) return map;
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }
}
