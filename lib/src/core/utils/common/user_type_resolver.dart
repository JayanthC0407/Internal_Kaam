/// Backend-resolved user-type values, as documented in
/// "Corporate & Retail Dashboard Selection" (API Flow & Implementation doc).
///
/// The `me` API response contains `dashboardResponse.dashboardDTOs`, which is
/// resolved server-side at `USER_TYPE` level. `dashboardClassValue` is the
/// authoritative signal for which dashboard to open — never the username.
class UserType {
  UserType._();

  static const String corporate = 'corporateuser';

  /// TODO: confirm the exact retail value returned by the backend `me` API
  /// (dashboardClassValue / userProfile.roles) and update if it differs.
  static const String retail = 'retailuser';
}

/// Resolves the authenticated user's dashboard/user type from the `me` API
/// response, following the *updated* algorithm from the API flow doc
/// (§19–20, "Critical Dashboard Selection Rule" / "Updated User-Type
/// Resolution Algorithm").
///
/// `dashboardResponse.dashboardDTOs` can contain **more than one** entry —
/// the documented Retail example returns both a `retailuser` DTO and a
/// factory/default `Customer` DTO. Blindly taking `dashboardDTOs[0]` is
/// explicitly called out as wrong, so this walks the list and returns the
/// first `dashboardClassValue` that also appears in `userProfile.roles`,
/// rather than trusting index 0.
///
/// If `dashboardDTOs` is present but non-empty and no entry's
/// `dashboardClassValue` matches any role, resolution is treated as
/// unavailable (`null`) rather than guessing — per the doc, "do not blindly
/// select the first dashboard."
///
/// Only when `dashboardDTOs` itself is empty/absent does this fall back to
/// checking `userProfile.roles` directly against the known `corporateuser`
/// / `retailuser` values.
///
/// [profileResponse] is the wrapped `me` API response as stored on
/// `LoginTrace.profileResponse` / `HomeDashboardArgs.loginTrace['profileResponse']`,
/// i.e. `{ statusCode, headers, body: { userProfile, dashboardResponse, ... } }`.
///
/// Returns `null` when the user type cannot be reliably resolved (e.g. `me`
/// failed, response is malformed, or no dashboard matches a role) — callers
/// should treat a `null` result as "resolution unavailable", not as any
/// specific type.
String? resolveUserType(Map<String, dynamic>? profileResponse) {
  final body = profileResponse?['body'];
  if (body is! Map) return null;
  final bodyMap = Map<String, dynamic>.from(body);

  final userProfile = bodyMap['userProfile'];
  final roles = userProfile is Map ? userProfile['roles'] : null;

  final dashboardResponse = bodyMap['dashboardResponse'];
  final dashboards = dashboardResponse is Map
      ? dashboardResponse['dashboardDTOs']
      : null;

  if (dashboards is List && dashboards.isNotEmpty) {
    // Prefer the dashboard whose class value matches one of the login roles.
    if (roles is List) {
      for (final dashboard in dashboards) {
        if (dashboard is! Map) continue;
        final value = dashboard['dashboardClassValue'];
        if (value is String && value.isNotEmpty && roles.contains(value)) {
          return value;
        }
      }
    }

    // dashboardDTOs exists but nothing matched a known role — do not
    // blindly select the first dashboard.
    return null;
  }

  // No dashboardDTOs at all: fall back to userProfile.roles directly,
  // limited to known exact role values.
  if (roles is List) {
    final roleStrings = roles.whereType<String>();
    if (roleStrings.contains(UserType.corporate)) return UserType.corporate;
    if (roleStrings.contains(UserType.retail)) return UserType.retail;
  }

  return null;
}

/// Returns the exact `dashboardDTOs` entry whose `dashboardClassValue`
/// matches [userType] (e.g. to read its `dashboardId` for later use), per
/// the doc's §21 "Recommended Exact Dashboard DTO Selection".
///
/// Not required for the current blank-Corporate-dashboard integration, but
/// kept alongside [resolveUserType] since both read the same structure and
/// this will be needed once dashboard-specific config/data loading (doc
/// §11) is implemented.
Map<String, dynamic>? resolveDashboardDto(
  Map<String, dynamic>? profileResponse,
  String userType,
) {
  final body = profileResponse?['body'];
  if (body is! Map) return null;
  final dashboardResponse = body['dashboardResponse'];
  if (dashboardResponse is! Map) return null;
  final dashboards = dashboardResponse['dashboardDTOs'];
  if (dashboards is! List) return null;

  for (final dashboard in dashboards) {
    if (dashboard is Map && dashboard['dashboardClassValue'] == userType) {
      return Map<String, dynamic>.from(dashboard);
    }
  }
  return null;
}
