import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/account_settings/account_settings_models.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_account_settings_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/account_settings_repository.dart';
import 'package:ubci_bank/src/infra/security/obdx_password_crypto_service.dart';
import 'package:ubci_bank/src/view/providers/common/account_settings_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/alerts_subscription_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/change_password_section.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/session_summary_section.dart';

// Field names follow OBDX session-summary, change-password and
// user-alerts-subscription model.js; values are made up.

ResponseHandler<Map<String, dynamic>> _ok([Map<String, dynamic> body = const {}]) =>
    ResponseHandler.success({'statusCode': 200, 'headers': <String, dynamic>{}, 'body': body});

/// `implements`: the real API would build the Dio client.
class _FakeApi implements ObdxAccountSettingsApi {
  final calls = <(String, String?, Map<String, dynamic>?)>[];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> changePassword(Map<String, dynamic> body, {String? challengeResponseHeader}) async {
    calls.add(('PUT credentials', null, body));
    return _ok();
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> createSubscription(Map<String, dynamic> body, {String? challengeResponseHeader}) async {
    calls.add(('POST', null, body));
    return _ok();
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> updateSubscription(String id, Map<String, dynamic> body,
      {String? challengeResponseHeader}) async {
    calls.add(('PUT', id, body));
    return _ok();
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> deleteSubscription(String id, {String? challengeResponseHeader}) async {
    calls.add(('DELETE', id, null));
    return _ok();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class _FakeCrypto implements ObdxPasswordCryptoService {
  @override
  Future<ResponseHandler<String>> encryptForUser({required String userName, required String plainPassword}) async =>
      ResponseHandler.success('enc($userName:$plainPassword)');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

final _policy = PasswordPolicy.fromPayload({
  'passwordPolicyDTO': [
    {
      'pwdMinLength': 5,
      'pwdMaxLength': 20,
      'nbrUpperAlpha': 1,
      'nbrLowerAlpha': 1,
      'nbrNumeric': 1,
      'nbrSpecial': 1,
      'specialCharsAllowed': true,
      'specialCharAllowed': ['@', '#'],
      'pwdHistorySize': 3,
      'excludedDictWords': ['Password@1'],
    },
  ],
});

const _user = AlertsUser(userId: 'obdxretail', partyValue: '9090092909760982', partyDisplay: '9090092909760982', partyName: 'Jayanth C');
const _module = AlertModule(id: 'CH', description: 'Current and Savings Account', accountTypes: ['CSA']);
const _account = AlertTarget(value: 'ACC1', displayValue: 'xxxx1022');
const _other = AlertTarget(value: 'ACC2', displayValue: 'xxxx3381');

final _events = AlertEvent.listFromPayload({
  'alertResponseDTO': [
    for (final (i, name) in ['Stop/Unblock Cheque Range', 'Cheque Book Request'].indexed)
      {
        'activityEventDescription': name,
        'moduleType': 'CH',
        'alertDTO': {
          'alertName': 'AL$i',
          'alertKeyDTO': {'activityId': 'A$i', 'eventId': 'E$i', 'actionId': 'X$i'},
          'alertTemplate': {'version': 1},
        },
      },
  ],
});

void main() {
  group('models', () {
    test('password policy: OBDX rules, live checks, history left to the bank', () {
      expect(_policy.rules, [
        PasswordRule.length,
        PasswordRule.upper,
        PasswordRule.lower,
        PasswordRule.number,
        PasswordRule.special,
        PasswordRule.common,
        PasswordRule.history,
      ]);
      expect(_policy.satisfies(PasswordRule.length, 'Ab1@'), isFalse);
      expect(_policy.satisfies(PasswordRule.special, 'Abcd1!'), isFalse, reason: '! is not allowed');
      expect(_policy.satisfies(PasswordRule.special, 'Abcd1#'), isTrue);
      expect(_policy.satisfies(PasswordRule.common, 'password@1'), isFalse);
      expect(_policy.satisfies(PasswordRule.history, 'Abcd1#'), isNull);
      expect(_policy.accepts('Abcd1#'), isTrue);
      expect(_policy.accepts('abcd1#'), isFalse);
    });

    test('sessions newest first; activity statuses', () {
      final sessions = UserSession.listFromPayload({
        'userSessionDTOList': [
          {'sessionId': 'S1', 'creationDate': '2026-10-25T07:04:00', 'accessPointId': 'APINTERNET', 'ipAddress': '10.1.0.64'},
          {'sessionId': 'S2', 'creationDate': '2026-10-26T12:34:00', 'accessPointId': 'APMOBAPP'},
        ],
      });
      expect(sessions.map((s) => s.sessionId), ['S2', 'S1']);
      expect(sessionDateTime(DateTime(2026, 10, 26, 12, 34)), '10/26/26, 12:34 PM');
      expect(sessionDateTime(DateTime(2026, 10, 26, 7, 4)), '10/26/26, 7:04 AM');
      final activity = SessionActivity.listFromPayload({
        'auditList': [
          {'activity': 'Login', 'status': 'success', 'startTime': '2026-10-26T07:04:00'},
        ],
      });
      expect(activity.single.status, 'SUCCESS');
    });

    test('subscriptions: modes per module and account', () {
      final sub = AlertSubscription.listFromPayload({
        'actionSubscriptionDTO': [
          {
            'subscriptionId': 'SUB1',
            'subscriptionLevel': 'ACCOUNT',
            'subscribedActions': [
              {
                'eventId': 'E0',
                'module': 'CH',
                'subscriptionLevelAccountKey': {'value': 'ACC1', 'displayValue': 'xxxx1022'},
                'subscriptionPreferences': [
                  {'destination': 'SMS'},
                  {'destination': 'SECURE_MAIL_BOX'},
                ],
              },
            ],
          },
        ],
      }).single;
      expect(sub.modesFor('CH', 'ACC1'), {
        'E0': {AlertMode.sms, AlertMode.onScreen},
      });
      expect(sub.subscribedTargets('CH'), {'ACC1'});
      expect(sub.modesFor('CH', 'ACC2'), isEmpty);
    });
  });

  group('repository', () {
    test('change password: both passwords encrypted, PUT me/credentials', () async {
      final api = _FakeApi();
      final repo = AccountSettingsRepository(api: api, crypto: _FakeCrypto());
      final r = await repo.changePassword(userName: 'obdxretail', current: 'Old@1', next: 'New#2');
      expect(r, isA<Success<PrefWriteOutcome>>());
      expect(api.calls.single.$3, {'oldPassword': 'enc(obdxretail:Old@1)', 'changedPassword': 'enc(obdxretail:New#2)'});
    });

    test('alerts: first save POSTs, later saves PUT and keep other accounts; clearing everything DELETEs', () async {
      final api = _FakeApi();
      final repo = AccountSettingsRepository(api: api, crypto: _FakeCrypto());
      final today = DateTime(2026, 10, 27);

      await repo.saveAlerts(
        user: _user,
        module: _module,
        target: _account,
        events: _events,
        selection: {
          'E0': {AlertMode.push, AlertMode.email},
        },
        today: today,
      );
      final (method, _, body) = api.calls.last;
      expect(method, 'POST');
      expect(body!['subscriptionLevel'], 'ACCOUNT');
      expect(body['subscriptionStartDate'], '2026-10-27');
      expect(body['subscriber'], {
        'id': 'obdxretail',
        'subscriberType': 'PARTY',
        'party': {'displayValue': '9090092909760982', 'value': '9090092909760982'},
      });
      final action = (body['subscribedActions'] as List).single as Map;
      expect(action['eventId'], 'E0');
      expect(action['module'], 'CH');
      expect(action['subscriptionLevelAccountKey'], {'value': 'ACC1', 'displayValue': 'xxxx1022'});
      expect([for (final p in action['subscriptionPreferences'] as List) p['destination']], ['PUSH_NOTIFICATION', 'EMAIL']);

      // An existing record with ACC2's alert: saving ACC1 keeps it.
      final existing = AlertSubscription(id: 'SUB1', level: 'ACCOUNT', actions: [
        {
          'eventId': 'E1',
          'module': 'CH',
          'subscriptionLevelAccountKey': {'value': 'ACC2'},
        },
      ]);
      await repo.saveAlerts(
        user: _user,
        module: _module,
        target: _account,
        events: _events,
        selection: {
          'E1': {AlertMode.sms},
        },
        existing: existing,
        today: today,
      );
      expect(api.calls.last.$1, 'PUT');
      expect(api.calls.last.$2, 'SUB1');
      final keys = [for (final a in api.calls.last.$3!['subscribedActions'] as List) AlertSubscription.keyOf(Map<String, dynamic>.from(a as Map))];
      expect(keys, ['ACC2', 'ACC1']);

      // Clearing ACC2's only alert leaves nothing: OBDX deletes the record.
      await repo.saveAlerts(
        user: _user,
        module: _module,
        target: _other,
        events: _events,
        selection: const {},
        existing: existing,
        today: today,
      );
      expect(api.calls.last.$1, 'DELETE');
      expect(api.calls.last.$2, 'SUB1');
    });
  });

  group('screens', () {
    late _FakeApi api;

    Future<void> pump(WidgetTester tester, Widget child, {double width = 1280}) async {
      SharedPreferences.setMockInitialValues({});
      api = _FakeApi();
      tester.view.physicalSize = Size(width, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSettingsRepositoryProvider.overrideWithValue(AccountSettingsRepository(api: api, crypto: _FakeCrypto())),
            passwordPolicyProvider.overrideWith((ref) async => _policy),
            userSessionsProvider.overrideWith((ref) async => [
                  UserSession(sessionId: 'S1', start: DateTime(2026, 10, 26, 12, 34), accessPointId: 'APINTERNET', ipAddress: '10.1.0.64'),
                ]),
            sessionActivityProvider.overrideWith((ref, id) async => [
                  SessionActivity(activity: 'Login', status: 'SUCCESS', time: DateTime(2026, 10, 26, 7, 4)),
                ]),
            alertsUserProvider.overrideWith((ref) async => _user),
            alertModulesProvider.overrideWith((ref) async => const [_module]),
            alertEventsProvider.overrideWith((ref) async => _events),
            alertSubscriptionsProvider.overrideWith((ref) async => const <AlertSubscription>[]),
            alertTargetsProvider.overrideWith((ref, id) async => const [_account, _other]),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('session summary: the table, a row expands to its transactions', (tester) async {
      await pump(tester, const SessionSummarySection());
      for (final h in ['Start Date & Time', 'End Date & Time', 'Channel', 'IP Address']) {
        expect(find.text(h), findsOneWidget);
      }
      expect(find.text('10/26/26, 12:34 PM'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
      expect(find.text('10.1.0.64'), findsOneWidget);
      expect(find.text('Login'), findsNothing);

      await tester.tap(find.text('10/26/26, 12:34 PM'));
      await tester.pumpAndSettle();
      expect(find.text('Transaction Name'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
      expect(find.text('10/26/26, 7:04 AM'), findsOneWidget);
    });

    testWidgets('change password: empty fields, live rules, mismatch, then success and Login', (tester) async {
      var login = 0;
      await pump(tester, ChangePasswordSection(userName: 'obdxretail', onCancel: () {}, onLogin: () => login++));
      expect(find.text('Please change your password for security reasons.'), findsOneWidget);
      expect(find.text('Have 5 to 20 characters'), findsOneWidget);
      expect(find.text('Have special characters (Minimum 1 mandatory) (allowed: @ #)'), findsOneWidget);
      expect(find.text('Not be one of your most recent 3 password(s).'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a value.'), findsNWidgets(3));

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Old@1x');
      await tester.enterText(fields.at(1), 'abc');
      await tester.pump();
      // Typing turns the bullets into ticks and crosses.
      expect(find.byIcon(Icons.cancel_rounded), findsWidgets);

      await tester.enterText(fields.at(1), 'Newpass#2');
      await tester.enterText(fields.at(2), 'Newpass#3');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('The Password must match!'), findsOneWidget);
      expect(api.calls, isEmpty);

      await tester.enterText(fields.at(2), 'Newpass#2');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(api.calls.single.$3, {
        'oldPassword': 'enc(obdxretail:Old@1x)',
        'changedPassword': 'enc(obdxretail:Newpass#2)',
      });
      expect(find.text('Password Changed Successfully!'), findsOneWidget);
      await tester.tap(find.text('Login'));
      expect(login, 1);
    });

    for (final (name, screen) in [
      ('session summary', const SessionSummarySection() as Widget),
      ('change password', ChangePasswordSection(userName: 'u', onCancel: () {}, onLogin: () {})),
      ('alerts', const AlertsSubscriptionSection()),
    ]) {
      testWidgets('phone: $name lays out without overflow', (tester) async {
        await pump(tester, screen, width: 400);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('alerts: user strip, Apply an account, pick channels, Save', (tester) async {
      await pump(tester, const AlertsSubscriptionSection());
      expect(find.text('9090 0929 0976 0982'), findsOneWidget);
      expect(find.text('Jayanth C'), findsOneWidget);
      expect(find.text('OBDXRETAIL'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Current and Savings Account'), findsOneWidget);
      expect(find.text('Stop/Unblock Cheque Range'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);

      // Nothing to change until an account is applied.
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Select a party, then Apply.'), findsOneWidget);

      await tester.tap(find.text('Select Party'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('xxxx1022').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Push Notification of the first alert, then Map All for the second.
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(6));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final (method, _, body) = api.calls.single;
      expect(method, 'POST');
      final actions = body!['subscribedActions'] as List;
      expect([for (final a in actions) a['eventId']], ['E0', 'E1']);
      expect([for (final p in actions[0]['subscriptionPreferences'] as List) p['destination']], ['PUSH_NOTIFICATION']);
      expect((actions[1]['subscriptionPreferences'] as List).length, 4);
      expect(find.text('Alert subscription saved.'), findsOneWidget);
    });
  });
}
