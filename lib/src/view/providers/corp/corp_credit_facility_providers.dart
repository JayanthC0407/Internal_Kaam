import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_credit_facility_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_credit_facility_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';

/// Credit Facility Management (docs/obdx/features/credit-facility.md).
/// autoDispose: loaded while a screen is open.

final obdxCorpCreditFacilityApiProvider =
    Provider((ref) => ObdxCorpCreditFacilityApi(ref.watch(obdxDioClientProvider)));

final corpCreditFacilityRepositoryProvider =
    Provider((ref) => CorpCreditFacilityRepository(api: ref.watch(obdxCorpCreditFacilityApiProvider)));

/// Which screens and tabs the user may open, by OBDX component name
/// (`me/components`; UIAuthorization.json). An empty list allows all, as
/// for the other corporate menus.
class CfPermissions {
  const CfPermissions({
    this.facilitySummary = true,
    this.facilityDetails = true,
    this.collateralGroups = true,
    this.utilization = true,
  });

  final bool facilitySummary;
  final bool facilityDetails;

  /// The Collateral Groups tab (`collateral-overview`).
  final bool collateralGroups;

  /// The Transaction Summary tab and View Utilization (`facility-utilization`).
  final bool utilization;

  bool get any => facilitySummary || facilityDetails;
}

final cfPermissionsProvider = Provider<CfPermissions>((ref) {
  final authorized = ref.watch(personalizationProvider).authorized;
  bool allowed(String name) => authorized.isEmpty || authorized.contains(name);
  return CfPermissions(
    facilitySummary: allowed('facility-overview'),
    facilityDetails: allowed('facility-details'),
    collateralGroups: allowed('collateral-overview'),
    utilization: allowed('facility-utilization'),
  );
});

/// The signed-in user's party id (`userProfile.partyId.value`).
final cfUserPartyIdProvider = Provider<String>((ref) => ref.watch(corpProfileProvider).profile?.partyId ?? '');

final cfLookupsProvider = FutureProvider.autoDispose<CfLookups>((ref) {
  final group = ref.watch(corpProfileProvider).profile?.groupCorporateId;
  return ref.read(corpCreditFacilityRepositoryProvider).fetchLookups(groupCorporateId: group);
});

/// Facility Summary, by selected party ('' until one is chosen).
final cfFacilitiesProvider = FutureProvider.autoDispose.family<CfFacilities, String>(
  (ref, partyId) async => _data(await ref.read(corpCreditFacilityRepositoryProvider).fetchFacilities(partyId)),
);

/// Facility Details' Facility Name options.
final cfFacilityOptionsProvider = FutureProvider.autoDispose<CfFacilities>((ref) async {
  final party = ref.watch(cfUserPartyIdProvider);
  return _data(await ref.read(corpCreditFacilityRepositoryProvider).fetchFacilityOptions(party));
});

final cfFacilityProvider = FutureProvider.autoDispose.family<CfFacility, String>(
  (ref, key) async => _data(await ref.read(corpCreditFacilityRepositoryProvider).fetchFacility(key)),
);

/// The Collateral Groups tab, by pool id. Null data = no group.
final cfCollateralGroupProvider = FutureProvider.autoDispose.family<CfCollateralGroup?, String>((ref, poolId) async {
  final party = ref.watch(cfUserPartyIdProvider);
  final result = await ref.read(corpCreditFacilityRepositoryProvider).fetchCollateralGroup(poolId, party);
  if (result is Success<CfCollateralGroup?>) return result.data;
  throw CfLoadError(result is Error<CfCollateralGroup?> ? result.error : null);
});

typedef CfUtilizationKey = ({String facility, DateTime? from, DateTime? to});

final cfUtilizationProvider = FutureProvider.autoDispose.family<List<CfUtilizationRow>, CfUtilizationKey>(
  (ref, key) async => _data(await ref
      .read(corpCreditFacilityRepositoryProvider)
      .fetchUtilization(key.facility, from: key.from, to: key.to)),
);

T _data<T>(ResponseHandler<T> result) {
  if (result is Success<T> && result.data != null) return result.data as T;
  throw CfLoadError(result is Error<T> ? result.error : null);
}

/// Load failure; [message] is OBDX's text when the server sent one.
class CfLoadError implements Exception {
  const CfLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'CfLoadError';
}
