import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// The responsive breakpoints OBDX stores a separate widget layout for.
///
/// `defaultLayout` is stored alongside the three sized layouts and is empty
/// in every capture we have, but it round-trips like the rest.
enum CorpLayoutBreakpoint {
  defaultLayout('defaultLayout'),
  large('large'),
  medium('medium'),
  small('small');

  const CorpLayoutBreakpoint(this.key);

  /// The key this layout sits under in `layout.layout`.
  final String key;

  /// Which layout a viewport of [width] logical pixels renders.
  ///
  /// Mirrors the Oracle JET grid the web client uses: `sm` below 768,
  /// `md` below 1024, `lg` at or above it. Both mobile and desktop are
  /// supported, so the app reads — and saves — the layout matching the
  /// screen the user is actually personalizing on.
  static CorpLayoutBreakpoint forWidth(double width) {
    if (width < 768) return CorpLayoutBreakpoint.small;
    if (width < 1024) return CorpLayoutBreakpoint.medium;
    return CorpLayoutBreakpoint.large;
  }
}

/// One widget placed on a dashboard layout.
class CorpDashboardLayoutItem {
  const CorpDashboardLayoutItem({
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

  CorpDashboardLayoutItem copyWith({String? style}) {
    return CorpDashboardLayoutItem(
      componentName: componentName,
      module: module,
      style: style ?? this.style,
      data: data,
      childPanel: childPanel,
    );
  }

  factory CorpDashboardLayoutItem.fromJson(Map<String, dynamic> json) {
    final childPanel = json['childPanel'];
    return CorpDashboardLayoutItem(
      componentName: (json['componentName'] ?? '').toString().trim(),
      module: (json['module'] ?? '').toString().trim(),
      style: _trimmed(json['style']),
      // Distinguish an absent `data` key from `"{}"`: the captured config
      // contains items both with and without it, and the PUT echoes that
      // back, so writing one in where there was none would be a change.
      data: json.containsKey('data') ? json['data']?.toString() : null,
      childPanel: childPanel is List ? List<dynamic>.from(childPanel) : const [],
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
class CorpDashboardConfig {
  const CorpDashboardConfig({
    required this.dashboardId,
    required this.dashboardName,
    required this.dashboardDescription,
    required this.layoutsByBreakpoint,
    this.enterpriseRole,
    this.dashboardClass,
    this.dashboardClassValue,
    this.isFactory = false,
  });

  /// PUT target: `.../dashboards/user/{dashboardId}`.
  final String dashboardId;

  /// Opaque host-generated names. Echoed back on save unchanged — they are
  /// not display strings and must not be rewritten.
  final String dashboardName;
  final String dashboardDescription;

  final Map<CorpLayoutBreakpoint, List<CorpDashboardLayoutItem>>
      layoutsByBreakpoint;

  final String? enterpriseRole;
  final String? dashboardClass;
  final String? dashboardClassValue;

  /// A factory dashboard is the bank's default, not the user's own copy.
  final bool isFactory;

  List<CorpDashboardLayoutItem> layoutFor(CorpLayoutBreakpoint breakpoint) =>
      layoutsByBreakpoint[breakpoint] ?? const [];

  /// Distinct component names selected at [breakpoint], in first-seen
  /// order.
  ///
  /// De-duplicates deliberately: the captured `small` layout holds 13
  /// entries for 7 distinct widgets (`approval-transactions-widget` three
  /// times), which would otherwise render the same widget repeatedly.
  List<String> selectedComponentsAt(CorpLayoutBreakpoint breakpoint) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final item in layoutFor(breakpoint)) {
      if (item.componentName.isEmpty) continue;
      if (seen.add(item.componentName)) ordered.add(item.componentName);
    }
    return ordered;
  }

  /// True when [breakpoint] stores the same widget more than once.
  bool hasDuplicatesAt(CorpLayoutBreakpoint breakpoint) =>
      layoutFor(breakpoint).length != selectedComponentsAt(breakpoint).length;

  /// Replaces exactly one breakpoint's layout, leaving every other
  /// breakpoint's items untouched so they round-trip unchanged.
  CorpDashboardConfig withLayout(
    CorpLayoutBreakpoint breakpoint,
    List<CorpDashboardLayoutItem> items,
  ) {
    return CorpDashboardConfig(
      dashboardId: dashboardId,
      dashboardName: dashboardName,
      dashboardDescription: dashboardDescription,
      layoutsByBreakpoint: {...layoutsByBreakpoint, breakpoint: items},
      enterpriseRole: enterpriseRole,
      dashboardClass: dashboardClass,
      dashboardClassValue: dashboardClassValue,
      isFactory: isFactory,
    );
  }

  /// The PUT body, in the shape the captured request used.
  ///
  /// `waterfallLayout` is intentionally omitted: the GET returns it but the
  /// captured PUT does not send it. (Untested for a user whose
  /// `waterfallLayout` is non-empty — every capture we have is empty.)
  Map<String, dynamic> toUpdatePayload() {
    return {
      'dashboardName': dashboardName,
      'dashboardDescription': dashboardDescription,
      'layout': {
        'layout': {
          for (final breakpoint in CorpLayoutBreakpoint.values)
            breakpoint.key: [
              for (final item in layoutFor(breakpoint)) item.toJson(),
            ],
        },
      },
    };
  }

  static CorpDashboardConfig? fromPayload(dynamic data) {
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

    final parsed = <CorpLayoutBreakpoint, List<CorpDashboardLayoutItem>>{};
    for (final breakpoint in CorpLayoutBreakpoint.values) {
      final raw = layouts[breakpoint.key];
      if (raw is! List) {
        parsed[breakpoint] = const [];
        continue;
      }
      final items = <CorpDashboardLayoutItem>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final item = CorpDashboardLayoutItem.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (item.componentName.isEmpty) continue;
        items.add(item);
      }
      parsed[breakpoint] = items;
    }

    return CorpDashboardConfig(
      dashboardId: dashboardId,
      dashboardName: (dto['dashboardName'] ?? '').toString(),
      dashboardDescription: (dto['dashboardDescription'] ?? '').toString(),
      layoutsByBreakpoint: parsed,
      enterpriseRole: _trimmed(dto['enterpriseRole']),
      dashboardClass: _trimmed(dto['dashboardClass']),
      dashboardClassValue: _trimmed(dto['dashboardClassValue']),
      isFactory: dto['factory'] == true,
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
