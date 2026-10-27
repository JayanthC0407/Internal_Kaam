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

// Field names and the POST shape follow the UAT capture
// (docs/obdx/features/bill-payments.md §4); all values are made up.

Map<String, dynamic> _billerJson(String id, String name, {String type = 'PRESENTMENT'}) => {
      'id': id,
      'name': name,
      'currency': 'GBP',
      'type': type,
      'status': 'ACTIVE',
      'logo': <String, dynamic>{},
      'areaCategoryDetails': [
        {
          'billerId': id,
          'categoryId': 'CAT1',
          'categoryName': 'Electricity',
          'operationalAreaId': 'AREA1',
          'operationalAreaName': 'London',
        },
      ],
      'specifications': [
        {'id': 'CONS', 'label': 'Consumer Number', 'required': true, 'datatype': 'NUMERIC', 'priority': 1, 'maxLength': '10'},
        {'id': 'REF', 'label': 'Reference', 'required': false, 'datatype': 'ALPHANUMERIC', 'priority': 2, 'maxLength': '8'},
        {'id': 'NOLABEL', 'required': true, 'datatype': 'TEXT', 'priority': 3, 'maxLength': '5'},
      ],
      'paymentMethodsList': [
        {'id': 'P1', 'paymentType': 'CASA'},
      ],
    };

final _biller = BillerInfo.fromJson(_billerJson('B1', 'Power Co'))!;

void main() {
  group('model', () {
    test('GET billers: sorted by name, maxLength parsed from a string, unlabelled specs dropped', () {
      final list = BillerInfo.listFromPayload({
        'billerDTOs': [_billerJson('B2', 'Water Co', type: 'PAYMENT'), _billerJson('B1', 'Power Co')],
      });
      expect(list.map((b) => b.name), ['Power Co', 'Water Co']);
      final b = list.first;
      expect(b.specifications.map((s) => s.id), ['CONS', 'REF']);
      expect(b.specifications.first.maxLength, 10);
      expect(b.categoryId, 'CAT1');
      expect(b.operationalAreaId, 'AREA1');
      expect(b.pickerLabel, 'Electricity | London');
      expect(b.paymentTypes, ['CASA']);
    });

    test('Manual POST body has exactly the captured keys; empty values left out', () {
      final body = AddBillerRequest(
        biller: _biller,
        nickname: ' Home ',
        customerName: 'Test Customer',
        relationshipValues: {'CONS': '12345', 'REF': ''},
      ).toJson();
      expect(body.keys.toSet(), {
        'billerId', 'billerNickName', 'billerType', 'customerName', 'category', 'location',
        'relationshipDetails', 'autopay', 'schedulePayment', 'autopayInstructions',
      });
      expect(body['billerNickName'], 'Home');
      expect(body['category'], {'id': 'CAT1'});
      expect(body['location'], {'id': 'AREA1'});
      expect(body['relationshipDetails'], [
        {'value': '12345', 'labelId': 'CONS'},
      ]);
      expect(body['autopay'], isFalse);
      final ai = body['autopayInstructions'] as Map;
      expect(ai.keys.toSet(), {'paymentType', 'debitAccount', 'limitAmount', 'startDate', 'endDate', 'frequency'});
      expect(ai['paymentType'], isNull);
    });

    test('field rules use OBDX patterns and lengths', () {
      expect(BillerFieldRules.nickname(''), BillerFieldError.required);
      expect(BillerFieldRules.nickname('A' * 21), BillerFieldError.tooLong);
      expect(BillerFieldRules.nickname('Home @ 1'), BillerFieldError.invalid);
      expect(BillerFieldRules.nickname("Mum's flat-2 (A/B)"), isNull);
      expect(BillerFieldRules.customerName('A' * 35), isNull);
      final cons = _biller.specifications.first;
      expect(BillerFieldRules.spec(cons, ''), BillerFieldError.required);
      expect(BillerFieldRules.spec(cons, '12a'), BillerFieldError.numeric);
      expect(BillerFieldRules.spec(cons, '12345678901'), BillerFieldError.tooLong);
      final ref = _biller.specifications[1];
      expect(BillerFieldRules.spec(ref, ''), isNull);
      expect(BillerFieldRules.spec(ref, 'AB-1'), BillerFieldError.alphanumeric);
    });
  });

  group('repository: OBDX framework behaviour on writes', () {
    BillPaymentsRepository repo(int status, Map<String, dynamic> body, {Map<String, List<String>> headers = const {}}) =>
        BillPaymentsRepository(api: _FakeApi(_wrapped(status, body, headers: headers)));
    final request = AddBillerRequest(
      biller: _biller,
      nickname: 'Home',
      customerName: 'Test',
      relationshipValues: const {'CONS': '1'},
    );

    test('201 (UAT) → added, with the new registration', () async {
      final result = await repo(201, {
        'status': {'result': 'SUCCESSFUL', 'message': {'type': 'INFO'}},
        'billerRegistration': {'id': 'R9', 'billerId': 'B1', 'billerNickName': 'Home', 'billerType': 'PRESENTMENT', 'registrationStatus': 'APPROVED'},
      }).addBiller(request);
      final outcome = (result as Success<BillerAddOutcome>).data!;
      expect(outcome.biller?.id, 'R9');
      expect(outcome.pendingApproval, isFalse);
    });

    test('417 + X-Challenge → OTP required (OTP off in UAT today, on in OBDX)', () async {
      final result = await repo(417, const {}, headers: {
        'x-challenge': [jsonEncode({'referenceNo': 'OTP1', 'authType': 'OTP'})],
      }).addBiller(request);
      expect((result as Success<BillerAddOutcome>).data!.challenge?.referenceNo, 'OTP1');
    });

    test('APPROVAL_STATUS: INITIATED → pending approval, for add and delete', () async {
      const headers = {
        'APPROVAL_STATUS': ['INITIATED'],
      };
      final added = await repo(200, {'status': {'result': 'SUCCESSFUL'}}, headers: headers).addBiller(request);
      expect((added as Success<BillerAddOutcome>).data!.pendingApproval, isTrue);
      final deleted = await repo(200, {'status': {'result': 'SUCCESSFUL'}}, headers: headers).deleteRegisteredBiller('R1');
      expect((deleted as Success<BillerDeleteOutcome>).data!.pendingApproval, isTrue);
    });

    test('DELETE 200 (UAT) → deleted with the reference number', () async {
      final result = await repo(200, {
        'status': {'result': 'SUCCESSFUL', 'referenceNumber': 'REF7', 'message': {'type': 'INFO', 'code': 'X'}},
      }).deleteRegisteredBiller('R1');
      final outcome = (result as Success<BillerDeleteOutcome>).data!;
      expect(outcome.reference, 'REF7');
      expect(outcome.pendingApproval, isFalse);
    });
  });

  testWidgets('Billers → Add Billers → Review → Confirm → back to Billers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [billPaymentsRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleConfig.supportedLocales,
          home: const BillersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.listLoads, 1);

    // The page action (the empty list's help card has one too).
    await tester.tap(find.text('Add Billers').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Please Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Power Co').last);
    await tester.pumpAndSettle();
    // Required → the design's "Required" tag: Biller Name, Nickname,
    // Consumer Number, Customer Name (Reference is optional).
    expect(find.text('Consumer Number'), findsWidgets); // label + hint
    expect(find.text('Required'), findsNWidgets(4));
    expect(find.text('Required fields'), findsOneWidget);

    // Submit with nothing filled: OBDX-style errors, no step change.
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Consumer Number is required.'), findsOneWidget);

    // Design order: Nickname, the biller's fields, Customer Name.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Home');
    await tester.enterText(fields.at(1), '12345');
    await tester.enterText(fields.at(3), 'Test Customer');
    await tester.pumpAndSettle();
    expect(find.text('Required fields'), findsNothing, reason: 'nothing required is empty');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('You initiated a request for add biller. Please review details before you confirm!'), findsWidgets);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(fake.added?.toJson()['relationshipDetails'], [
      {'value': '12345', 'labelId': 'CONS'},
    ]);
    expect(find.text('Biller added successfully.'), findsOneWidget);

    await tester.tap(find.text('Back to Billers'));
    await tester.pumpAndSettle();
    expect(fake.listLoads, 2, reason: 'the Billers list is fetched again');
    expect(tester.takeException(), isNull);
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
  Future<ResponseHandler<Map<String, dynamic>>> addRegisteredBiller(
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) async =>
      response;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> deleteRegisteredBiller(
    String id, {
    Map<String, dynamic>? body,
    String? challengeResponseHeader,
  }) async =>
      response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements BillPaymentsRepository {
  int listLoads = 0;
  AddBillerRequest? added;

  @override
  Future<ResponseHandler<List<RegisteredBiller>>> fetchRegisteredBillers() async {
    listLoads++;
    return ResponseHandler.success(const <RegisteredBiller>[], code: 200);
  }

  @override
  Future<ResponseHandler<List<BillerInfo>>> fetchBillers() async =>
      ResponseHandler.success([_biller], code: 200);

  @override
  Future<ResponseHandler<BillerAddOutcome>> addBiller(
    AddBillerRequest request, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    added = request;
    return ResponseHandler.success(const BillerAddOutcome.added(), code: 201);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
