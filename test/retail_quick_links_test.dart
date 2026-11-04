import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_bank/l10n/app_localizations.dart';
import 'package:demo_bank/src/core/config/locale_config.dart';
import 'package:demo_bank/src/core/theme/app_theme.dart';
import 'package:demo_bank/src/view/screens/retail/dashboard_widgets/retail_dashboard_widgets.dart';
import 'package:demo_bank/src/view/screens/retail/home/widgets/retail_home_actions.dart';

// The personalised dashboard's Activity Centre (OBDX `quick-links`) opens
// the same things as the fixed Home's.
void main() {
  testWidgets('each built tile opens its Home action; Passbook is Coming soon', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleConfig.supportedLocales,
          home: Scaffold(
            body: RetailHomeActions(
              onTermDeposit: () => opened.add('td'),
              onViewStatement: () => opened.add('statement'),
              onChequeBook: () => opened.add('cheque'),
              onNewDebitCard: () => opened.add('debit'),
              onCalculator: () => opened.add('calc'),
              child: const SingleChildScrollView(child: RetailQuickLinksWidget()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['Term Deposit', 'View Statement', 'Cheque Book', 'New Debit card', 'Calculator']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(opened, ['td', 'statement', 'cheque', 'debit', 'calc']);
    await tester.tap(find.text('Passbook'));
    await tester.pump();
    expect(find.textContaining('Passbook ·'), findsOneWidget);
  });
}
