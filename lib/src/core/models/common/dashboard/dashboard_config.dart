import 'dart:convert';

import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// The responsive breakpoints OBDX stores a separate widget layout for.
///
/// `defaultLayout` is stored alongside the three sized layouts and is empty
/// in every capture we have, but it round-trips like the rest.
enum DashboardBreakpoint {
  defaultLayout('defaultLayout'),
  large('large'),
  medium('medium'),
  small('small');

  const DashboardBreakpoint(this.key);

  /// The key this layout sits under in `layout.layout`.
  final String key;

  /// Which layout a viewport of [width] logical pixels renders.
  ///
  /// Mirrors the Oracle JET grid the web client uses: `sm` below 768,
  /// `md` below 1024, `lg` at or above it. Both mobile and desktop are
  /// supported, so the app reads — and saves — the layout matching the
  /// screen the user is actually personalizing on.
  static DashboardBreakpoint forWidth(double width) {
    if (width < 768) return DashboardBreakpoint.small;
    if (width < 1024) return DashboardBreakpoint.medium;
    return DashboardBreakpoint.large;
  }

  /// The key a catalog entry's `width` map uses for this breakpoint.
  /// `defaultLayout` has none of its own and reads `large`.
  String get catalogWidthKey => switch (this) {
        DashboardBreakpoint.small => 'small',
        DashboardBreakpoint.medium => 'medium',
        DashboardBreakpoint.large ||
        DashboardBreakpoint.defaultLayout =>
          'large',
      };

  /// The Oracle JET grid class prefix for this breakpoint, e.g. `oj-lg`.
  String get jetPrefix => switch (this) {
        DashboardBreakpoint.small => 'oj-sm',
        DashboardBreakpoint.medium => 'oj-md',
        DashboardBreakpoint.large ||
        DashboardBreakpoint.defaultLayout =>
          'oj-lg',
      };
}

/// One widget placed on a dashboard layout.
class DashboardLayoutItem {
  const DashboardLayoutItem({
    required this.componentName,
    required this.module,
    this.style,
    this.data,
    this.childPanel = const <dynamic>[],
  });

  /// The stable widget key — never the display name. This is what the
  /// widget registry resolves to a Flutter widget.
  final String componentName;

  /// Owning OBDX module, e.g. `corporateDashboard`, `cash-management`.
  final String module;

  /// Oracle JET grid class, e.g. `oj-sm-12`. Retained so it round-trips
  /// untouched; Flutter derives its own sizing rather than parsing this.
  final String? style;

  /// Per-instance widget configuration, `"{}"` in every captured item.
  /// Kept because one component may later support multiple variants.
  final String? data;

  /// Nested panels. Always empty in the captures; preserved verbatim.
  final List<dynamic> childPanel;

  DashboardLayoutItem copyWith({String? style}) {
    return DashboardLayoutItem(
      componentName: componentName,
      module: module,
      style: style ?? this.style,
      data: data,
      childPanel: childPanel,
    );
  }

  factory DashboardLayoutItem.fromJson(Map<String, dynamic> json) {
    final childPanel = json['childPanel'];
    return DashboardLayoutItem(
      componentName: (json['componentName'] ?? '').toString().trim(),
      module: (json['module'] ?? '').toString().trim(),
      style: _trimmed(json['style']),
      // Distinguish an absent `data` key from `"{}"`: the captured config
      // contains items both with and without it, and the PUT echoes that
      // back, so writing one in where there was none would be a change.
      data: json.containsKey('data') ? json['data']?.toString() : null,
      childPanel:
          childPanel is List ? List<dynamic>.from(childPanel) : const [],
    );
  }

  /// Serialized in the key order the captured PUT uses.
  Map<String, dynamic> toJson() {
    return {
      'componentName': componentName,
      'module': module,
      if (data != null) 'data': data,
      if (style != null) 'style': style,
      if (childPanel.isNotEmpty) 'childPanel': childPanel,
    };
  }

  static String? _trimmed(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}

/// A user's personalized dashboard, from
/// `GET /digx-admin/config/v1/dashboards/modules?class=CUSTOM&value=custom`.
///
/// **The whole object round-trips.** The captured save
/// (`PUT .../dashboards/user/{dashboardId}`) sends every breakpoint's
/// layout, not a patch: the web client changed only `large` and echoed
/// `medium`, `small` and `defaultLayout` back byte-identical. Editing one
/// breakpoint and sending only that would therefore wipe the user's layout
/// on every other device size.
///
/// That is why this model keeps [layoutsByBreakpoint] whole and offers
/// [withLayout] to replace exactly one — callers cannot accidentally drop
/// the layouts they did not look at.
class DashboardConfig {
  const DashboardConfig({
    required this.dashboardId,
    required this.dashboardName,
    required this.dashboardDescription,
    required this.layoutsByBreakpoint,
    this.enterpriseRole,
    this.dashboardClass,
    this.dashboardClassValue,
    this.isFactory = false,
    this.waterfallLayout,
  });

  /// PUT target: `.../dashboards/user/{dashboardId}`.
  final String dashboardId;

  /// Opaque host-generated names. Echoed back on save unchanged — they are
  /// not display strings and must not be rewritten.
  final String dashboardName;
  final String dashboardDescription;

  final Map<DashboardBreakpoint, List<DashboardLayoutItem>> layoutsByBreakpoint;

  final String? enterpriseRole;
  final String? dashboardClass;
  final String? dashboardClassValue;

  /// A factory dashboard is the bank's default, not the user's own copy.
  final bool isFactory;

  /// `layout.waterfallLayout`, kept verbatim.
  ///
  /// Nothing in this app reads or edits it, which is exactly why it is held
  /// raw rather than parsed: the save replaces the whole `layout` object, so
  /// anything not sent back is at risk of being cleared. Round-tripping it
  /// untouched means a layout the web client arranged there survives a save
  /// made from this app. Null when the host did not send one, in which case
  /// none is invented on save.
  final Map<String, dynamic>? waterfallLayout;

  /// The user's own personalized dashboard — the only kind this app writes.
  ///
  /// A factory dashboard is shared by every user of the type, so saving to
  /// one would change the bank's default for all of them.
  bool get isUserCustom =>
      !isFactory && (dashboardClass ?? '').toUpperCase() == 'CUSTOM';

  List<DashboardLayoutItem> layoutFor(DashboardBreakpoint breakpoint) =>
      layoutsByBreakpoint[breakpoint] ?? const [];

  /// Distinct component names selected at [breakpoint], in first-seen
  /// order.
  ///
  /// De-duplicates deliberately: the captured `small` layout holds 13
  /// entries for 7 distinct widgets (`approval-transactions-widget` three
  /// times), which would otherwise render the same widget repeatedly.
  List<String> selectedComponentsAt(DashboardBreakpoint breakpoint) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final item in layoutFor(breakpoint)) {
      if (item.componentName.isEmpty) continue;
      if (seen.add(item.componentName)) ordered.add(item.componentName);
    }
    return ordered;
  }

  /// True when [breakpoint] stores the same widget more than once.
  bool hasDuplicatesAt(DashboardBreakpoint breakpoint) =>
      layoutFor(breakpoint).length != selectedComponentsAt(breakpoint).length;

  /// Replaces exactly one breakpoint's layout, leaving every other
  /// breakpoint's items untouched so they round-trip unchanged.
  DashboardConfig withLayout(
    DashboardBreakpoint breakpoint,
    List<DashboardLayoutItem> items,
  ) {
    return DashboardConfig(
      dashboardId: dashboardId,
      dashboardName: dashboardName,
      dashboardDescription: dashboardDescription,
      layoutsByBreakpoint: {...layoutsByBreakpoint, breakpoint: items},
      enterpriseRole: enterpriseRole,
      dashboardClass: dashboardClass,
      dashboardClassValue: dashboardClassValue,
      isFactory: isFactory,
      waterfallLayout: waterfallLayout,
    );
  }

  /// The PUT body, in the shape the captured request used.
  ///
  /// [waterfallLayout] is sent back exactly as it was received. The captured
  /// web-client PUT happened to omit it, but that capture's waterfall was
  /// empty, so it proves nothing about a populated one — and because the
  /// save replaces the whole `layout` object, omitting a populated waterfall
  /// risks clearing it. Preserving it is the safe round-trip.
  Map<String, dynamic> toUpdatePayload() {
    final waterfall = waterfallLayout;
    return {
      'dashboardName': dashboardName,
      'dashboardDescription': dashboardDescription,
      'layout': {
        'layout': {
          for (final breakpoint in DashboardBreakpoint.values)
            breakpoint.key: [
              for (final item in layoutFor(breakpoint)) item.toJson(),
            ],
        },
        if (waterfall != null) 'waterfallLayout': _deepCopy(waterfall),
      },
    };
  }

  /// Independent copy of a JSON map, so a caller mutating the payload
  /// cannot reach back into this config.
  static Map<String, dynamic> _deepCopy(Map<String, dynamic> source) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);

  static DashboardConfig? fromPayload(dynamic data) {
    final root = _unwrap(data);
    if (root == null) return null;

    final dto = ObdxApiUtils.asMap(root['dashboardDTO']);
    if (dto.isEmpty) return null;

    final dashboardId = (dto['dashboardId'] ?? '').toString().trim();
    if (dashboardId.isEmpty) return null;

    // A `dashboardDTO` with no `layout` key is a metadata-only response —
    // the save endpoint returns exactly that. Parsing it would yield a
    // config whose every breakpoint is empty, which is indistinguishable
    // from a real dashboard the user has emptied, and saving that back
    // wipes the layouts for every screen size. Refuse it instead, so
    // callers fall back to a config they know is complete.
    if (!dto.containsKey('layout')) return null;

    // `layout.layout` — the outer key wraps `layout` and `waterfallLayout`.
    final layoutWrapper = ObdxApiUtils.asMap(dto['layout']);
    final layouts = ObdxApiUtils.asMap(layoutWrapper['layout']);
    final waterfall = layoutWrapper['waterfallLayout'];

    final parsed = <DashboardBreakpoint, List<DashboardLayoutItem>>{};
    for (final breakpoint in DashboardBreakpoint.values) {
      final raw = layouts[breakpoint.key];
      if (raw is! List) {
        parsed[breakpoint] = const [];
        continue;
      }
      final items = <DashboardLayoutItem>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final item = DashboardLayoutItem.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (item.componentName.isEmpty) continue;
        items.add(item);
      }
      parsed[breakpoint] = items;
    }

    return DashboardConfig(
      dashboardId: dashboardId,
      dashboardName: (dto['dashboardName'] ?? '').toString(),
      dashboardDescription: (dto['dashboardDescription'] ?? '').toString(),
      layoutsByBreakpoint: parsed,
      enterpriseRole: _trimmed(dto['enterpriseRole']),
      dashboardClass: _trimmed(dto['dashboardClass']),
      dashboardClassValue: _trimmed(dto['dashboardClassValue']),
      isFactory: dto['factory'] == true,
      waterfallLayout: waterfall is Map
          ? _deepCopy(Map<String, dynamic>.from(waterfall))
          : null,
    );
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('dashboardDTO')) return map;
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }

  static String? _trimmed(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}
