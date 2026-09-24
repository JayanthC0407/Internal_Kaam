import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'blank_tab_scaffold.dart';

class RewardsTabScreen extends StatelessWidget {
  const RewardsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlankTabScaffold(
      title: l10n.rewards,
      icon: Icons.card_giftcard_rounded,
    );
  }
}
