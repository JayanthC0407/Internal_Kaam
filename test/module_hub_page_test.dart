import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_bank/l10n/app_localizations.dart';
import 'package:demo_bank/src/core/config/locale_config.dart';
import 'package:demo_bank/src/core/theme/app_theme.dart';
import 'package:demo_bank/src/view/screens/common/dashboard/module_hub_page.dart';
import 'package:demo_bank/src/view/screens/retail/home/widgets/home_menu_button.dart';

Future<void> _pump(WidgetTester tester, {VoidCallback? onBack}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: LocaleConfig.supportedLocales,
      home: Scaffold(
        drawer: const Drawer(),
        body: ModuleHubPage(title: 'Bill Payments', subtitle: 'Pay your bills.', tiles: const [], onBack: onBack),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone: a hub opened with Back shows only Back, no hamburger', (tester) async {
    var back = false;
    await _pump(tester, onBack: () => back = true);
    expect(find.byType(HomeMenuButton), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    expect(back, isTrue);
  });

  testWidgets('phone: a hub without Back keeps the hamburger', (tester) async {
    await _pump(tester);
    expect(find.byType(HomeMenuButton), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });
}
