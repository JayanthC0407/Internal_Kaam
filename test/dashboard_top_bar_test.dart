import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/view/screens/common/dashboard/dashboard_top_bar.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_nav_content.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/dashboard_header_bar.dart';

Future<void> _pump(WidgetTester tester, Widget bar) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleConfig.supportedLocales,
        home: Scaffold(body: Column(children: [bar])),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Retail web top bar', () {
    testWidgets('is the shared top bar the Corporate dashboard uses',
        (tester) async {
      await _pump(
        tester,
        WebDashboardHeaderBar(displayName: 'Pooja Jha', onLogout: () {}),
      );

      expect(find.byType(DashboardTopBar), findsOneWidget);
      expect(find.text('PJ'), findsOneWidget);
    });

    testWidgets('the profile menu shows the user and logs out', (tester) async {
      var loggedOut = false;
      await _pump(
        tester,
        WebDashboardHeaderBar(
          displayName: 'Pooja Jha',
          userId: 'pooja01',
          onLogout: () => loggedOut = true,
        ),
      );

      await tester.tap(find.text('PJ'));
      await tester.pumpAndSettle();
      expect(find.text('Pooja Jha'), findsOneWidget);
      expect(find.text('pooja01'), findsOneWidget);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(loggedOut, isTrue);
    });

    testWidgets('does not repeat the name as the sign-in ID', (tester) async {
      await _pump(
        tester,
        WebDashboardHeaderBar(
          displayName: 'pooja01',
          userId: 'POOJA01',
          onLogout: () {},
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      expect(find.text('POOJA01'), findsNothing);
    });

    testWidgets('settings offers Personalize Dashboard and the theme switch',
        (tester) async {
      var opened = false;
      await _pump(
        tester,
        WebDashboardHeaderBar(
          displayName: 'Pooja Jha',
          onLogout: () {},
          onPersonalizeDashboard: () => opened = true,
        ),
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Switch to dark mode'), findsOneWidget);

      await tester.tap(find.text('Personalize Dashboard'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    });
  });

  test('the Corporate menu lists Home first', () {
    expect(CorpNavDestination.values.first, CorpNavDestination.home);
    expect(
      CorpNavDestination.values.indexOf(CorpNavDestination.loan),
      greaterThan(CorpNavDestination.values.indexOf(CorpNavDestination.home)),
    );
  });
}
