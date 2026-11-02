import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:demo_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:demo_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/liquidity/charges_inquiry_page.dart';
import 'package:demo_bank/src/view/screens/corp/liquidity/lm_menu.dart';
import 'package:demo_bank/src/view/screens/corp/liquidity/lm_overview_page.dart';

/// A Liquidity Management screen inside the corporate shell: the page
/// header (back arrow, title, OBDX's "party | id" caption) over the page.
class CorpLiquidityWorkspace extends ConsumerWidget {
  const CorpLiquidityWorkspace({super.key, required this.page, required this.onBack});

  final LmPage page;

  /// Back and Cancel: to Home, as for the other corporate menus.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = MediaQuery.of(context).size.width < 600 ? 16.0 : 24.0;
    final profile = ref.watch(corpProfileProvider).profile;
    final caption = profile?.partyIdDisplay == null
        ? null
        : '${profile?.partyName ?? ''} | ${profile!.partyIdDisplay}'.trim();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
      children: [
        // The module dashboard's header is the module name (nls/dashboard.js).
        CfPageHeader(
          title: page == LmPage.overview ? 'Liquidity Management' : page.label,
          caption: caption,
          onBack: onBack,
        ),
        const SizedBox(height: 14),
        switch (page) {
          LmPage.overview => const LmOverviewPage(),
          LmPage.chargesInquiry => ChargesInquiryPage(onCancel: onBack),
        },
      ],
    );
  }
}
