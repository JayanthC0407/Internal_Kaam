import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/account_settings/account_settings_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_account_settings_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/account_settings_repository.dart';
import 'package:ubci_bank/src/infra/security/obdx_password_crypto_service.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/sections/dnd_alerts_section.dart';

// Shapes follow OBDX manage-dnd-alerts (docs/obdx/features/manage-dnd-alerts.md).
// Values are made up.

final _registry = {
  'categories': [
    {'id': 1, 'name': 'Promotional'},
    {'id': 2, 'name': 'Transactional'},
    {'id': 'C3', 'name': 'Service'},
  ],
  'mapped': [2],
};

ResponseHandler<Map<String, dynamic>> _wrapped(int status, Map<String, dynamic> body,
        {Map<String, List<String>> headers = const {}}) =>
    ResponseHandler.success({'statusCode': status, 'headers': headers, 'rawBody': jsonEncode(body), 'body': body});

class _FakeApi implements ObdxAccountSettingsApi {
  _FakeApi({this.put});

  final ResponseHandler<Map<String, dynamic>>? put;
  Map<String, dynamic>? saved;
  String? eventsFor;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchDndRegistry() async => _wrapped(200, _registry);

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchDndEvents(String categoryId) async {
    eventsFor = categoryId;
    return _wrapped(200, {
      'activityEvents': [
        {'activityEventDescription': 'Offers and promotions'},
        {'activityEventDescription': 'Festive greetings'},
      ],
    });
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> saveDndRegistry(Map<String, dynamic> body,
      {String? challengeResponseHeader}) async {
    saved = body;
    return put ?? _wrapped(200, {'status': {'referenceNumber': 'DND9'}});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class _FakeCrypto implements ObdxPasswordCryptoService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('model', () {
    test('registry: categories, mapped ids; the body keeps ids as sent', () {
      final r = DndRegistry.fromPayload(_registry);
      expect(r.categories.map((c) => c.name), ['Promotional', 'Transactional', 'Service']);
      expect(r.mapped, {'2'});
      expect(r.body({'1', 'C3'}), {
        'categories': [1, 'C3'],
      });
      expect(r.body({}), {'categories': <Object>[]}, reason: 'no ticks is allowed');
      expect(dndEventsFromPayload({
        'activityEvents': [
          {'activityEventDescription': 'A'},
          {},
        ],
      }), ['A']);
    });

    test('repository: 417 → OTP, 202 → pending approval', () async {
      final r = DndRegistry.fromPayload(_registry);
      final otp = await AccountSettingsRepository(
        api: _FakeApi(put: _wrapped(417, const {}, headers: {
          'x-challenge': [jsonEncode({'referenceNo': 'OTP1', 'authType': 'OTP'})],
        })),
        crypto: _FakeCrypto(),
      ).saveDnd(r, {'1'});
      expect((otp as Success).data.challenge?.referenceNo, 'OTP1');
      final pending = await AccountSettingsRepository(
        api: _FakeApi(put: _wrapped(202, {'status': {'result': 'SUCCESSFUL'}})),
        crypto: _FakeCrypto(),
      ).saveDnd(r, {'1'});
      expect((pending as Success).data.pendingApproval, isTrue);
    });
  });

  group('section', () {
    Future<_FakeApi> pump(WidgetTester tester, {double width = 390}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _FakeApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSettingsRepositoryProvider.overrideWithValue(AccountSettingsRepository(api: api, crypto: _FakeCrypto())),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: DndAlertsSection(onCancel: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    bool ticked(WidgetTester tester, int i) => tester.widget<Checkbox>(find.byType(Checkbox).at(i)).value!;

    testWidgets('mapped ticked; name opens its events; Submit → Review (read only) → Confirm', (tester) async {
      final api = await pump(tester);
      expect(find.text('Select Category'), findsOneWidget);
      expect([ticked(tester, 0), ticked(tester, 1), ticked(tester, 2)], [false, true, false]);

      await tester.tap(find.text('Promotional'));
      await tester.pumpAndSettle();
      expect(find.text('DND Alert : Promotional'), findsOneWidget);
      expect(find.text('Offers and promotions'), findsOneWidget);
      expect(api.eventsFor, '1');
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Alerts DND'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged, isNull, reason: 'review is read only');

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(api.saved, {
        'categories': [1],
      });
      expect(find.text('Your request has been accepted.'), findsOneWidget);
      expect(find.text('DND9'), findsWidgets);
    });

    testWidgets('Back from Review keeps the ticks (web width)', (tester) async {
      await pump(tester, width: 1280);
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect([ticked(tester, 0), ticked(tester, 1), ticked(tester, 2)], [false, true, true]);
      expect(tester.takeException(), isNull);
    });
  });
}
