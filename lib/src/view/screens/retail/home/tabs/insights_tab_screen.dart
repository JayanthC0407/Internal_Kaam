import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'blank_tab_scaffold.dart';

class InsightsTabScreen extends StatelessWidget {
  const InsightsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlankTabScaffold(
      title: l10n.insights,
      icon: Icons.pie_chart_outline_rounded,
    );
  }
}
