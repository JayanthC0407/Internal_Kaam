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

  /// The user's own personalized dashboard: not the bank's factory one, and
  /// of class `CUSTOM`.
  bool get isUserCustom =>
      !isFactory && dashboardClass.toUpperCase() == 'CUSTOM';

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

  /// The dashboard personalization should read and write — the user's own
  /// `CUSTOM` dashboard, and nothing else.
  ///
  /// **There is deliberately no fallback to the factory dashboard.** A
  /// factory dashboard (`USER_TYPE`/`corporateuser`, id 18 in the capture)
  /// is shared by every user of that type, so writing to it would change the
  /// bank's default for all of them, not personalize one user's. What OBDX
  /// does for a first-time user who has no `CUSTOM` dashboard yet — whether
  /// the first save creates one, and under what id — has not been captured
  /// or verified. Until it is, such a user gets no personalization rather
  /// than a write to a shared record.
  ///
  /// Returns null when there is no usable `CUSTOM` entry; callers treat that
  /// as "personalization unavailable".
  static DashboardDescriptor? personalizableFrom(
    List<DashboardDescriptor> dashboards,
  ) {
    for (final dashboard in dashboards) {
      if (dashboard.isUserCustom && dashboard.isUsable) return dashboard;
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
