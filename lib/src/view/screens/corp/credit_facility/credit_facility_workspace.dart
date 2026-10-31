import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_menu.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/facility_details_page.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/facility_summary_page.dart';

/// A Credit Facility Management screen inside the corporate shell, like
/// the Trade Finance workspace: the page header (back arrow, title, OBDX's
/// "party | id" caption) over the chosen page. A facility opened from
/// Facility Summary shows its details here; Back returns to the summary.
class CorpCreditFacilityWorkspace extends ConsumerStatefulWidget {
  const CorpCreditFacilityWorkspace({super.key, required this.page, required this.onBack});

  final CfPage page;

  /// Back from the page itself (to Home, as for Trade Finance).
  final VoidCallback onBack;

  @override
  ConsumerState<CorpCreditFacilityWorkspace> createState() => _CorpCreditFacilityWorkspaceState();
}

class _CorpCreditFacilityWorkspaceState extends ConsumerState<CorpCreditFacilityWorkspace> {
  /// A facility opened from the summary, and the tab asked for.
  String? _openKey;
  CfDetailTab? _openTab;

  @override
  void didUpdateWidget(CorpCreditFacilityWorkspace old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) {
      _openKey = null;
      _openTab = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final pad = width < 600 ? 16.0 : 24.0;
    final profile = ref.watch(corpProfileProvider).profile;
    final caption = profile?.partyIdDisplay == null
        ? null
        : '${profile?.partyName ?? ''} | ${profile!.partyIdDisplay}'.trim();
    final fromSummary = widget.page == CfPage.facilitySummary && _openKey != null;
    final showsDetails = widget.page == CfPage.facilityDetails || fromSummary;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
      children: [
        CfPageHeader(
          title: showsDetails ? 'Credit Facility Details' : 'Facility Summary',
          caption: caption,
          onBack: fromSummary
              ? () => setState(() {
                    _openKey = null;
                    _openTab = null;
                  })
              : widget.onBack,
        ),
        const SizedBox(height: 14),
        if (showsDetails)
          FacilityDetailsPage(
            key: ValueKey('details-${widget.page.name}-$_openKey-$_openTab'),
            initialKey: _openKey,
            initialTab: _openTab,
            onExit: widget.onBack,
          )
        else
          FacilitySummaryPage(
            onOpen: (key, tab) => setState(() {
              _openKey = key;
              _openTab = tab;
            }),
          ),
      ],
    );
  }
}
