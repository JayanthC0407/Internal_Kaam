import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_bill_payments_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/bill_payments_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/billers_screen.dart';

// PUT shape: OBDX modify-biller-review/model.js:27-50 (bill-payments.md
// §6.3). Values are made up.

RegisteredBiller _biller(
  String id,
  String nickname, {
  bool autopay = false,
  bool schedule = false,
  String? paymentType,
  String type = 'PAYMENT',
}) =>
    RegisteredBiller.fromJson({
      'id': id,
      'billerId': 'B$id',
      'billerName': 'Water Co',
      'billerNickName': nickname,
      'billerType': type,
      'customerName': 'Test Customer',
      'registrationStatus': 'APPROVED',
      'autopay': autopay,
      'schedulePayment': schedule,
      'autopayInstructions': {if (paymentType != null) 'paymentType': paymentType},
      'category': {'id': 'C', 'name': 'Water'},
      'location': {'id': 'L', 'areaName': 'Camden', 'city': 'London'},
      'relationshipDetails': [
        {'labelId': 'X', 'value': '1'},
      ],
      'biller': {
        'id': 'B$id',
        'name': 'Water Co',
        'paymentMethodsList': [
          {'paymentType': 'DEBITCARD'},
          {'paymentType': 'CASA'},
        ],
      },
    })!;

void main() {
  group('model', () {
    test('PUT body has exactly OBDX template keys; Manual values', () {
      final body = EditBillerRequest(biller: _biller('R1', 'Old', paymentType: 'CASA'), nickname: ' New Name ').toJson();
      expect(body.keys.toSet(), {
        'billerRegistrationId', 'billerNickName', 'autopay', 'schedulePayment',
        'autopayInstructions', 'cardExpiryDate', 'paymentEndDate',
      });
      expect(body['billerRegistrationId'], 'R1');
      expect(body['billerNickName'], 'New Name');
      expect(body['autopay'], isFalse);
      expect(body['schedulePayment'], isFalse);
      final ai = body['autopayInstructions'] as Map;
      expect(ai.keys.toSet(), {'debitAccount', 'limitAmount', 'startDate', 'frequency', 'paymentType', 'endDate'});
      expect(ai['paymentType'], 'CASA', reason: "the registration's own payment type");
    });

    test('paymentType falls back to the biller\'s first payment method', () {
      final body = EditBillerRequest(biller: _biller('R1', 'Old'), nickname: 'X').toJson();
      expect((body['autopayInstructions'] as Map)['paymentType'], 'DEBITCARD');
    });

    test('edit nickname: letters, digits, spaces only (stricter than Add)', () {
      expect(BillerFieldRules.editNickname('Home Water 2'), isNull);
      expect(BillerFieldRules.editNickname("Mum's flat"), BillerFieldError.invalid);
      expect(BillerFieldRules.nickname("Mum's flat"), isNull, reason: 'Add Billers allows it');
      expect(BillerFieldRules.editNickname('A' * 21), BillerFieldError.tooLong);
      expect(BillerFieldRules.editNickname('  '), BillerFieldError.required);
    });

    test('hasPaymentInstruction: auto pay or schedule', () {
      expect(_biller('1', 'a').hasPaymentInstruction, isFalse);
      expect(_biller('1', 'a', autopay: true).hasPaymentInstruction, isTrue);
      expect(_biller('1', 'a', schedule: true).hasPaymentInstruction, isTrue);
    });
  });

  group('repository', () {
    final request = EditBillerRequest(biller: _biller('R1', 'Old'), nickname: 'New');
    BillPaymentsRepository repo(int status, Map<String, dynamic> body, {Map<String, List<String>> headers = const {}}) =>
        BillPaymentsRepository(api: _FakeApi(_wrapped(status, body, headers: headers)));

    test('200 → updated with the reference', () async {
      final result = await repo(200, {
        'status': {'result': 'SUCCESSFUL', 'referenceNumber': 'REF9', 'message': {'type': 'INFO'}},
      }).updateBiller(request);
      final outcome = (result as Success<BillerEditOutcome>).data!;
      expect(outcome.reference, 'REF9');
      expect(outcome.pendingApproval, isFalse);
    });

    test('417 + X-Challenge → OTP; APPROVAL_STATUS → pending', () async {
      final otp = await repo(417, const {}, headers: {
        'x-challenge': [jsonEncode({'referenceNo': 'O1'})],
      }).updateBiller(request);
      expect((otp as Success<BillerEditOutcome>).data!.challenge?.referenceNo, 'O1');
      final pending = await repo(200, {'status': {'result': 'SUCCESSFUL'}}, headers: {
        'APPROVAL_STATUS': ['INITIATED'],
      }).updateBiller(request);
      expect((pending as Success<BillerEditOutcome>).data!.pendingApproval, isTrue);
    });
  });

  Future<_FakeRepo> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo([
      _biller('R1', 'Water', paymentType: 'CASA'),
      _biller('R2', 'Power', autopay: true, type: 'PRESENTMENT'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [billPaymentsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleConfig.supportedLocales,
          home: const BillersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> openEdit(WidgetTester tester, String nickname) async {
    final tile = find.ancestor(of: find.text(nickname), matching: find.byType(InkWell)).first;
    await tester.tap(find.descendant(of: tile, matching: find.byIcon(Icons.more_horiz_rounded)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Biller').last);
    await tester.pumpAndSettle();
  }

  testWidgets('Edit (Manual): nickname rule → Review → Confirm → Done → list reloads', (tester) async {
    final repo = await pump(tester);
    await openEdit(tester, 'Water');
    expect(find.text('Biller Nickname(Nickname should be unique) *'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget, reason: 'Edit screen label for PAYMENT');

    await tester.enterText(find.byType(TextField), 'Water-2');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Nickname can comprise alphanumerics (A-Z any case, 0-9)&,/,-"space'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Water Home');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(
      find.text('You initiated a request for update biller. Please review details before you confirm!'),
      findsWidgets,
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo.updated?.toJson()['billerNickName'], 'Water Home');
    expect(find.text('Biller updated successfully.'), findsOneWidget);

    await tester.tap(find.text('Back to Billers'));
    await tester.pumpAndSettle();
    expect(repo.listLoads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit is refused for an Auto Pay biller (v1, bill-payments.md §6.4)', (tester) async {
    final repo = await pump(tester);
    await openEdit(tester, 'Power');
    expect(find.text('Editing billers with Auto Pay or Scheduled Pay will be available soon.'), findsOneWidget);
    expect(find.text('Submit'), findsNothing);
    expect(repo.updated, isNull);
  });
}

ResponseHandler<Map<String, dynamic>> _wrapped(
  int status,
  Map<String, dynamic> body, {
  Map<String, List<String>> headers = const {},
}) =>
    ResponseHandler.success({'statusCode': status, 'headers': headers, 'rawBody': jsonEncode(body), 'body': body});

class _FakeApi implements ObdxBillPaymentsApi {
  _FakeApi(this.response);

  final ResponseHandler<Map<String, dynamic>> response;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> updateRegisteredBiller(
    String id,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) async =>
      response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements BillPaymentsRepository {
  _FakeRepo(this.billers);

  final List<RegisteredBiller> billers;
  int listLoads = 0;
  EditBillerRequest? updated;

  @override
  Future<ResponseHandler<List<RegisteredBiller>>> fetchRegisteredBillers() async {
    listLoads++;
    return ResponseHandler.success(billers, code: 200);
  }

  @override
  Future<ResponseHandler<BillerEditOutcome>> updateBiller(
    EditBillerRequest request, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    updated = request;
    return ResponseHandler.success(const BillerEditOutcome.updated(), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
