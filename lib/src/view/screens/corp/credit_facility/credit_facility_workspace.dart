import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_menu.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_overview_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/collateral_details_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/collateral_summary_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/facility_details_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/facility_summary_page.dart';

/// One screen in the workspace: a menu page, or a facility / collateral
/// opened from one (OBDX `loadComponent` with `facilityId` /
/// `collateralId`).
typedef _View = ({CfPage page, String? facility, CfDetailTab? tab, String? collateral});

/// A Credit Facility Management screen inside the corporate shell, like
/// the Trade Finance workspace: the page header (back arrow, title, OBDX's
/// "party | id" caption) over the chosen page.
///
/// What a page opens — a summary from the Overview, a facility, a
/// collateral — is pushed on top of it, and Back returns one step (OBDX
/// goes back in history). Screens underneath stay mounted, so their
/// search, filters and open groups are still there.
class CorpCreditFacilityWorkspace extends ConsumerStatefulWidget {
  const CorpCreditFacilityWorkspace({super.key, required this.page, required this.onBack});

  final CfPage page;

  /// Back from the menu page itself (to Home, as for Trade Finance).
  final VoidCallback onBack;

  @override
  ConsumerState<CorpCreditFacilityWorkspace> createState() => _CorpCreditFacilityWorkspaceState();
}

class _CorpCreditFacilityWorkspaceState extends ConsumerState<CorpCreditFacilityWorkspace> {
  /// Opened on top of [CorpCreditFacilityWorkspace.page], oldest first.
  final _opened = <_View>[];

  @override
  void didUpdateWidget(CorpCreditFacilityWorkspace old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) _opened.clear();
  }

  void _push(_View view) => setState(() => _opened.add(view));

  void _pop() => setState(_opened.removeLast);

  _View get _base => (page: widget.page, facility: null, tab: null, collateral: null);

  static String _title(_View v) => v.collateral != null || v.page == CfPage.collateralDetails
      ? 'Collateral Details'
      : v.facility != null || v.page == CfPage.facilityDetails
          ? 'Credit Facility Details'
          : v.page.label;

  Widget _build(_View v, CfPermissions perms, {required bool isBase}) {
    final onExit = isBase ? widget.onBack : _pop;
    final openCollateral = perms.collateralDetails
        ? (String code) => _push((page: v.page, facility: null, tab: null, collateral: code))
        : null;
    void openFacility(String key, CfDetailTab? tab) =>
        _push((page: CfPage.facilityDetails, facility: key, tab: tab, collateral: null));
    void openPage(CfPage page) => _push((page: page, facility: null, tab: null, collateral: null));

    if (v.collateral != null) return CollateralDetailsPage(initialCode: v.collateral, onExit: onExit);
    if (v.facility != null || v.page == CfPage.facilityDetails) {
      return FacilityDetailsPage(
        initialKey: v.facility,
        initialTab: v.tab,
        onExit: onExit,
        onOpenCollateral: openCollateral,
      );
    }
    return switch (v.page) {
      CfPage.overview => CfOverviewPage(
          onFacilitySummary: perms.facilitySummary ? () => openPage(CfPage.facilitySummary) : null,
          onCollateralSummary: perms.collateralGroups ? () => openPage(CfPage.collateralSummary) : null,
          onFacility: perms.facilityDetails ? (key) => openFacility(key, null) : null,
          onCollateral: openCollateral,
        ),
      CfPage.facilitySummary => FacilitySummaryPage(onOpen: openFacility),
      CfPage.collateralSummary => CollateralSummaryPage(onOpen: openCollateral),
      CfPage.collateralDetails => CollateralDetailsPage(onExit: onExit),
      CfPage.facilityDetails => const SizedBox.shrink(), // handled above
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final pad = width < 600 ? 16.0 : 24.0;
    final profile = ref.watch(corpProfileProvider).profile;
    final caption = profile?.partyIdDisplay == null
        ? null
        : '${profile?.partyName ?? ''} | ${profile!.partyIdDisplay}'.trim();
    final perms = ref.watch(cfPermissionsProvider);
    final views = [_base, ..._opened];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
      children: [
        CfPageHeader(
          title: _title(views.last),
          caption: caption,
          onBack: _opened.isEmpty ? widget.onBack : _pop,
        ),
        const SizedBox(height: 14),
        for (final (i, v) in views.indexed)
          Offstage(
            key: ValueKey('cf-view-$i-${v.page.name}-${v.facility}-${v.tab}-${v.collateral}'),
            offstage: i != views.length - 1,
            child: TickerMode(enabled: i == views.length - 1, child: _build(v, perms, isBase: i == 0)),
          ),
      ],
    );
  }
}
