import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// One entry of `me`'s `dashboardResponse.dashboardDTOs[]`.
///
/// A user typically has two: their own `CUSTOM`/`custom` dashboard
/// (`factory: false`) and the bank's factory `USER_TYPE` one. These serve
/// different purposes and must not be confused:
///  - choosing *which dashboard screen to open* matches
///    `dashboardClassValue` against the user's roles (`resolveUserType`),
///    which selects the `USER_TYPE` entry;
///  - *personalization* reads and writes the `CUSTOM` entry, whose
///    `dashboardId` is the PUT target.
///
/// Shared by both user types — the `me` response has the same shape
/// whether the user is Retail or Corporate.
class DashboardDescriptor {
  const DashboardDescriptor({
    required this.dashboardId,
    required this.dashboardClass,
    required this.dashboardClassValue,
    this.enterpriseRole,
    this.isFactory = false,
  });

  final String dashboardId;

  /// e.g. `CUSTOM`, `USER_TYPE` — the `class` query parameter.
  final String dashboardClass;

  /// e.g. `custom`, `corporateuser` — the `value` query parameter.
  final String dashboardClassValue;

  final String? enterpriseRole;

  /// A factory dashboard is the bank's default rather than the user's own.
  final bool isFactory;

  bool get isUsable => dashboardId.isNotEmpty;

  factory DashboardDescriptor.fromJson(Map<String, dynamic> json) {
    final role = (json['enterpriseRole'] ?? '').toString().trim();
    return DashboardDescriptor(
      dashboardId: (json['dashboardId'] ?? '').toString().trim(),
      dashboardClass: (json['dashboardClass'] ?? '').toString().trim(),
      dashboardClassValue:
          (json['dashboardClassValue'] ?? '').toString().trim(),
      enterpriseRole: role.isEmpty ? null : role,
      isFactory: json['factory'] == true,
    );
  }

  /// Every dashboard DTO on a wrapped `me` response.
  static List<DashboardDescriptor> listFromProfileResponse(
    dynamic profileResponse,
  ) {
    final body = _bodyOf(profileResponse);
    if (body == null) return const [];

    final dashboardResponse = ObdxApiUtils.asMap(body['dashboardResponse']);
    final raw = dashboardResponse['dashboardDTOs'];
    if (raw is! List) return const [];

    final parsed = <DashboardDescriptor>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      parsed.add(DashboardDescriptor.fromJson(Map<String, dynamic>.from(entry)));
    }
    return parsed;
  }

  /// The dashboard personalization should read and write.
  ///
  /// Prefers the user's own non-factory entry (the captured corporate user
  /// has `CUSTOM`/`custom`, id 25801); falls back to the factory entry for
  /// a user who has never personalized. Returns null when `me` carried no
  /// usable dashboard DTO, in which case personalization is unavailable
  /// rather than guessed at.
  static DashboardDescriptor? personalizableFrom(
    List<DashboardDescriptor> dashboards,
  ) {
    for (final dashboard in dashboards) {
      if (!dashboard.isFactory && dashboard.isUsable) return dashboard;
    }
    for (final dashboard in dashboards) {
      if (dashboard.isUsable) return dashboard;
    }
    return null;
  }

  /// Convenience for callers that hold only the raw `me` response — which
  /// is what the Retail dashboard has, since it never parses a typed
  /// profile the way Corporate does.
  static DashboardDescriptor? personalizableFromProfileResponse(
    dynamic profileResponse,
  ) =>
      personalizableFrom(listFromProfileResponse(profileResponse));

  static Map<String, dynamic>? _bodyOf(dynamic profileResponse) {
    if (profileResponse is! Map) return null;
    final map = Map<String, dynamic>.from(profileResponse);
    if (map.containsKey('dashboardResponse') ||
        map.containsKey('userProfile')) {
      return map;
    }
    final body = map['body'];
    if (body is Map) return _bodyOf(body);
    return null;
  }
}
