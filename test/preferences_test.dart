import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/theme/app_palette.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/view/providers/common/app_settings_providers.dart';
import 'package:ubci_bank/src/view/providers/common/preferences_providers.dart';
import 'package:ubci_bank/src/view/screens/common/dashboard/dashboard_top_bar.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/preferences_screen.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/themes_section.dart';

// Field names follow the OBDX channel components (base-components-profile,
// sms-primary-account, third-party-consents, generic-settings); values are
// made up.

final _party = {
  'party': {
    'personalDetails': {
      'firstName': 'TOM',
      'middleName': '',
      'lastName': 'PHILIP',
      'birthDate': '1990-12-01T00:00:00',
      'email': 'tom@example.com',
    },
    'identifications': [
      {'type': 'PASSPORT', 'id': 'P1234567'},
    ],
    'contacts': [
      {
        'contactType': 'WMO',
        'phone': {'areaCode': '+44', 'number': '7700900123'},
      },
    ],
    'addresses': [
      {
        'type': 'PST',
        'postalAddress': {'line1': '1 High St', 'line2': '', 'city': 'London', 'country': 'GB', 'postalCode': '10001'},
      },
    ],
  },
};

final _config = {
  'userProfileConfigDTO': {
    'personalDetails': [
      {'fieldName': 'PASSPORT', 'displayValue': 'Passport', 'editable': true},
    ],
    'contactDetails': [
      {'fieldName': 'EMAIL', 'displayValue': 'Email Id', 'editable': true},
      {'fieldName': 'PHONENO', 'displayValue': 'Phone Number', 'editable': false},
      {'fieldName': 'PHONEISDNO', 'displayValue': 'ISD', 'editable': false},
      {'fieldName': 'ADDRESS', 'displayValue': 'Communication Address', 'editable': true},
    ],
  },
};

final _prefs = {
  'status': {'result': 'SUCCESSFUL'},
  'feedbackEnabled': true,
  'liveExpEnabled': false,
  'otpDeliveryMode': 'SMS',
  'operativeAccount': [
    {
      'determinantValue': 'OBDX_BU',
      'accountId': {'value': 'A1', 'displayValue': 'xxxx0001'},
    },
    {
      'determinantValue': 'OTHER_BU',
      'accountId': {'value': 'B1', 'displayValue': 'xxxx0002'},
    },
  ],
  'userAccessPointRelationship': [
    {'accessPointId': 'APP1', 'status': true},
  ],
};

void main() {
  group('models', () {
    test('profile: names, ISD phone, address and identification fields', () {
      final p = PartyProfile.fromPayloads(party: _party, config: _config);
      expect(p.displayName, 'TOM PHILIP');
      expect(p.birthDate, DateTime(1990, 12, 1));
      expect(p.mobileIsd, isTrue);
      expect(p.valueOf('PHONENO'), '+447700900123');
      expect(p.valueOf('EMAIL'), 'tom@example.com');
      expect(p.valueOf('PASSPORT'), 'P1234567');
      expect(p.valueOf('ADDRESS'), '1 High St, London, GB, 10001');
      // PHONEISDNO is a flag, not a row.
      expect(p.contactFields.map((f) => f.fieldName), ['EMAIL', 'PHONENO', 'ADDRESS']);
      expect(p.editableFields.map((f) => f.fieldName), ['PASSPORT', 'EMAIL', 'ADDRESS']);
    });

    test('userPreferences: primary account is per entity, status is dropped', () {
      final prefs = UserPreferences(_prefs);
      expect(prefs.raw.containsKey('status'), isFalse);
      expect(prefs.primaryAccountFor('OBDX_BU'), 'A1');

      final changed = prefs.withPrimaryAccount('OBDX_BU', accountId: 'A2', displayValue: 'xxxx0003');
      final rows = changed['operativeAccount'] as List;
      expect(rows, hasLength(2));
      expect(rows.where((r) => r['determinantValue'] == 'OTHER_BU'), hasLength(1));
      expect(rows.last['accountId'], {'value': 'A2', 'displayValue': 'xxxx0003'});

      final cleared = prefs.withPrimaryAccount('OBDX_BU');
      expect((cleared['operativeAccount'] as List).map((r) => r['determinantValue']), ['OTHER_BU']);
      // The original is untouched.
      expect(prefs.primaryAccountFor('OBDX_BU'), 'A1');
    });

    test('userPreferences: access point status and single values', () {
      final prefs = UserPreferences(_prefs);
      expect(prefs.accessPointStatus, {'APP1': true});
      final revoked = prefs.withAccessPointStatus('APP1', false);
      expect((revoked['userAccessPointRelationship'] as List).first['status'], isFalse);
      expect(prefs.withValue('otpDeliveryMode', 'BOTH')['otpDeliveryMode'], 'BOTH');
      expect(prefs.feedbackEnabled, isTrue);
      expect(prefs.liveExpEnabled, isFalse);
    });

    test('consent setup groups accounts by type', () {
      final setup = ConsentSetup.fromPayload({
        'accessPointAccountDTOs': [
          {
            'accountType': 'CSA',
            'accountAccessId': 'AA1',
            'accountExclusionDTOs': [
              {
                'accountNumber': {'value': 'A1', 'displayValue': 'xxxx0001'},
                'taskIds': ['OB_I', 'OB_P'],
                'accountExclusionId': 'EX1',
              },
            ],
          },
          {'accountType': 'XYZ', 'accountExclusionDTOs': []},
        ],
      });
      expect(setup.groups.keys, [ConsentAccountType.csa]);
      final account = setup.groups[ConsentAccountType.csa]!.accounts.single;
      expect(account.displayValue, 'xxxx0001');
      expect(account.taskIds, ['OB_I', 'OB_P']);
      expect(account.exclusionId, 'EX1');
    });

    test('device counts by OS', () {
      final counts = DeviceCounts.fromPayload({
        'listDTO': [
          {'os': 'android', 'count': 2},
          {'os': 'IOS', 'count': '0'},
        ],
      });
      expect(counts.of(DeviceOs.android), 2);
      expect(counts.of(DeviceOs.ios), 0);
      expect(counts.of(DeviceOs.browser), 0);
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, Widget home, {double width = 400, ThemeData? theme}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            partyProfileProvider.overrideWith((ref) async => PartyProfile.fromPayloads(party: _party, config: _config)),
            userPreferencesProvider.overrideWith((ref) async => UserPreferences(_prefs)),
            thirdPartyAppsProvider.overrideWith((ref) async => const <ThirdPartyApp>[]),
            pushTokensProvider.overrideWith((ref) async => const DeviceCounts({})),
          ],
          child: MaterialApp(
            theme: theme ?? AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: home,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const sections = [
      'Profile',
      'Primary Account Number',
      'Limits & Controls',
      'Security & Login',
      'Privacy & Consents',
      'Notifications & Alerts',
      'Appearance & Language',
    ];

    testWidgets('phone: card, grouped list, Personalize and Log out', (tester) async {
      var personalize = 0;
      var logout = 0;
      await pump(
        tester,
        PreferencesScreen(
          userName: 'tom01',
          lastLogin: DateTime(2026, 10, 25, 9, 30),
          onLogout: () => logout++,
          onPersonalize: () => personalize++,
        ),
      );
      expect(find.text('My Preferences'), findsOneWidget);
      // The card: name from me/party, user id, last login — no contact details.
      expect(find.text('TOM PHILIP'), findsOneWidget);
      expect(find.text('User ID: tom01'), findsOneWidget);
      expect(find.textContaining('example.com'), findsNothing);
      expect(find.textContaining('0123'), findsNothing);
      expect(find.textContaining('Last login 25 Oct 2026'), findsOneWidget);
      for (final g in ['ACCOUNT', 'SECURITY & PRIVACY', 'APP']) {
        expect(find.text(g), findsOneWidget, reason: g);
      }
      for (final s in [...sections, 'Personalize Dashboard', 'Log out']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      // The current appearance shows on its row.
      expect(find.text('Light · Cyan · English'), findsOneWidget);

      await tester.tap(find.text('Personalize Dashboard'));
      expect(personalize, 1);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(logout, 1);
    });

    testWidgets('phone: no Personalize row without a personalisable dashboard', (tester) async {
      await pump(tester, PreferencesScreen(userName: 'tom', onLogout: () {}));
      expect(find.text('Personalize Dashboard'), findsNothing);
    });

    testWidgets('phone: Profile opens and Back returns to the list', (tester) async {
      await pump(tester, PreferencesScreen(userName: 'tom', onLogout: () {}));
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('01 Dec 1990'), findsOneWidget);
      expect(find.text('P1234567'), findsOneWidget);
      expect(find.byTooltip('Edit Email Id'), findsOneWidget);
      // Phone is not editable.
      expect(find.byTooltip('Edit Phone Number'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('My Preferences'), findsOneWidget);
    });

    testWidgets('web: the card over the list beside Profile; Appearance has language', (tester) async {
      await pump(tester, PreferencesScreen(userName: 'tom', onLogout: () {}), width: 1280);
      for (final s in sections) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('Personal Information'), findsOneWidget);

      await tester.tap(find.text('Appearance & Language'));
      await tester.pumpAndSettle();
      expect(find.text('Select a theme to change the look of the application'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('web: Notifications & Alerts and Privacy & Consents hold the old Settings blocks', (tester) async {
      await pump(tester, PreferencesScreen(userName: 'tom', onLogout: () {}), width: 1280);

      await tester.tap(find.text('Notifications & Alerts'));
      await tester.pumpAndSettle();
      expect(find.text('Push Notification'), findsOneWidget);
      expect(find.text('Preferred Delivery Mode (Only for OTP)'), findsOneWidget);

      await tester.tap(find.text('Privacy & Consents'));
      await tester.pumpAndSettle();
      expect(find.text('Feedback Preferences'), findsWidgets);
      expect(find.text('Live Help'), findsWidgets);
    });

    for (final palette in AppThemePalette.values) {
      for (final dark in [false, true]) {
        testWidgets('themes: previews render in ${palette.name} ${dark ? 'dark' : 'light'}', (tester) async {
          await pump(
            tester,
            Scaffold(body: SingleChildScrollView(child: ThemesSection(onBack: () {}))),
            width: 1280,
            theme: dark ? AppTheme.dark(palette) : AppTheme.light(palette),
          );
          for (final name in ['Cyan', 'Orange', 'Indigo']) {
            expect(find.textContaining(name), findsWidgets);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('web header: only the icons are tap targets; the initials open Preferences', (tester) async {
      var preferences = 0;
      var logout = 0;
      await pump(
        tester,
        Scaffold(
          body: DashboardTopBar(
            displayName: 'Tom Philip',
            onLogout: () => logout++,
            onProfileTap: () => preferences++,
            profileTooltip: 'My Preferences',
          ),
        ),
        width: 1280,
      );
      await tester.tap(find.text('TP'));
      await tester.pumpAndSettle();
      expect(preferences, 1);
      // No dropdown: Log out is in My Preferences.
      expect(find.text('Log out'), findsNothing);
      expect(logout, 0);
      // No chevrons beside the settings gear or the initials.
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Switch to dark mode'), findsOneWidget);
    });

    testWidgets('themes: Apply only after choosing another theme, then it is the app theme', (tester) async {
      await pump(tester, Scaffold(body: SingleChildScrollView(child: ThemesSection(onBack: () {}))), width: 1280);
      final container = ProviderScope.containerOf(tester.element(find.byType(ThemesSection)));
      await tester.pumpAndSettle();
      final apply = find.widgetWithText(FilledButton, 'Apply');
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);

      await tester.tap(find.text('Orange'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);

      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).palette, AppThemePalette.orange);
      expect(find.text('Switch to Default Theme'), findsOneWidget);
    });
  });
}
