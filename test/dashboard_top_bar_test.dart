import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/app_locale_holder.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/view/providers/common/app_settings_providers.dart';
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

    testWidgets('settings offers the theme switch; Personalize is in My Preferences',
        (tester) async {
      await _pump(
        tester,
        WebDashboardHeaderBar(displayName: 'Pooja Jha', onLogout: () {}),
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Switch to dark mode'), findsOneWidget);
      expect(find.text('Personalize Dashboard'), findsNothing);
    });

    testWidgets('Language opens the shared picker and changes the app locale',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => AppLocaleHolder.instance.update(const Locale('en')));
      await _pump(
        tester,
        WebDashboardHeaderBar(displayName: 'Pooja Jha', onLogout: () {}),
      );

      await tester.tap(find.byTooltip('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('French'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardTopBar)),
      );
      expect(container.read(appSettingsProvider).locale.languageCode, 'fr');
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
