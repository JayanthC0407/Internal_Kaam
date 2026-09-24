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
      parsed
          .add(DashboardDescriptor.fromJson(Map<String, dynamic>.from(entry)));
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

  /// Whether [profileResponse] is a `me` response at all — as opposed to
  /// missing, which is what a session restore passes on when its own `me`
  /// call failed.
  static bool isProfileResponse(dynamic profileResponse) =>
      _bodyOf(profileResponse) != null;

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

/// What is known about the user's personalizable dashboard.
///
/// Three cases, because two of them used to be one: "`me` says this user
/// has no `CUSTOM` dashboard" is final, while "we do not have `me`" is not —
/// a session restore whose own `me` call failed passes no response at all.
/// Treating the second like the first made a transient failure switch
/// personalization off for the rest of the session.
sealed class DashboardDescriptorLookup {
  const DashboardDescriptorLookup();

  /// From a descriptor the caller has already resolved out of a `me`
  /// response it holds: null means that response has no `CUSTOM` entry.
  factory DashboardDescriptorLookup.resolved(DashboardDescriptor? descriptor) =>
      descriptor == null
          ? const DashboardDescriptorAbsent()
          : DashboardDescriptorFound(descriptor);

  /// From a raw `me` response, which may be missing.
  factory DashboardDescriptorLookup.fromProfileResponse(
    dynamic profileResponse,
  ) {
    if (!DashboardDescriptor.isProfileResponse(profileResponse)) {
      return const DashboardDescriptorUnknown();
    }
    return DashboardDescriptorLookup.resolved(
      DashboardDescriptor.personalizableFromProfileResponse(profileResponse),
    );
  }
}

/// `me` lists this `CUSTOM` dashboard as the user's own.
final class DashboardDescriptorFound extends DashboardDescriptorLookup {
  const DashboardDescriptorFound(this.descriptor);

  final DashboardDescriptor descriptor;
}

/// `me` was read and has no `CUSTOM` dashboard for this user. Final:
/// personalization is unavailable.
final class DashboardDescriptorAbsent extends DashboardDescriptorLookup {
  const DashboardDescriptorAbsent();
}

/// No `me` response is in hand. Not final: the dashboard's personalization
/// state fetches `me` itself.
final class DashboardDescriptorUnknown extends DashboardDescriptorLookup {
  const DashboardDescriptorUnknown();
}
