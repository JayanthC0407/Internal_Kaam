import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_pay_models.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_bill_payments_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/bill_payments_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/billers_screen.dart';

// Pay Bills (B2) — docs/obdx/features/bill-payments.md §8. Shapes follow
// the OBDX source (initiate-multiple-bill-payments); values are made up.

Map<String, dynamic> _reg(String id, String nickname, String billerId, num amount) => {
      'id': id,
      'billerId': billerId,
      'billerNickName': nickname,
      'billerType': 'PRESENTMENT',
      'billerName': '$nickname Co',
      'customerName': 'Test Customer',
      'registrationStatus': 'APPROVED',
      'location': {'id': 'L1', 'areaName': 'London'},
      'relationshipDetails': [
        {'labelId': 'CONS', 'value': 'C-$id'},
      ],
      'ebill': {
        'id': 'EB-$id',
        'dueDate': '2099-01-10T00:00:00',
        'totalAmount': {'currency': 'GBP', 'amount': amount},
      },
    };

Map<String, dynamic> _master(String id, List<String> methods) => {
      'id': id,
      'name': 'Biller $id',
      'currency': 'GBP',
      'type': 'PRESENTMENT',
      'areaCategoryDetails': [
        {'categoryName': 'Utilities'},
      ],
      'specifications': [
        {'id': 'CONS', 'label': 'Consumer Number'},
      ],
      'paymentMethodsList': [for (final m in methods) {'paymentType': m}],
    };

final _power = _reg('R1', 'Home power', 'B-P', 42);
final _gas = _reg('R6', 'Gas', 'B-G', 15);
final _masters = {
  'B-P': _master('B-P', const ['CASA', 'CREDITCARD']),
  'B-G': _master('B-G', const ['CASA']),
};

const _casaBody = {
  'accounts': [
    {
      'id': {'value': 'ACC2', 'displayValue': 'xxxx5678'},
      'accountNickname': 'Main',
      'currencyCode': 'GBP',
      'defaultAccount': true,
    },
  ],
};

PayBillRequest _request(Map<String, dynamic> reg, String masterId) => PayBillRequest(
      registration: RegisteredBiller.fromJson(reg)!,
      biller: BillerInfo.fromJson(_masters[masterId])!,
      type: BillPayType.casa,
      account: const BillPayAccount(value: 'ACC2', displayNumber: 'xxxx5678', nickname: 'Main'),
      amount: 10,
      today: DateTime(2026, 10, 27),
    );

void main() {
  group('model', () {
    test('a batch part: OBDX success and failure reading', () {
      final ok = BillBatchRow.fromPart(200, {
        'status': {'result': 'SUCCESSFUL', 'externalReferenceNumber': 'EXT1', 'referenceNumber': 'REF1'},
        'billPayment': {'id': 'BP1'},
      }, const {});
      expect(ok.completed, isTrue);
      expect((ok.externalReference, ok.paymentId, ok.referenceNumber), ('EXT1', 'BP1', 'REF1'));

      final approval = BillBatchRow.fromPart(202, const {}, const {'APPROVAL_STATUS': 'INITIATED'});
      expect((approval.succeeded, approval.pendingApproval, approval.approvalInitiated), (true, true, true));

      // status.message.detail first, then validationError, then message.title.
      expect(
        BillBatchRow.fromPart(400, {
          'status': {'message': {'detail': 'Detail text'}},
          'message': {'title': 'Title text'},
        }, const {}).failureReason,
        'Detail text',
      );
      expect(
        BillBatchRow.fromPart(400, {
          'message': {
            'title': 'Title text',
            'validationError': [
              {'errorMessage': 'Field text'},
            ],
          },
        }, const {}).failureReason,
        'Field text',
      );
      expect(
        BillBatchRow.fromPart(400, {
          'message': {'code': 'DIGX_FL_015', 'title': 'Applicable limits not found for this transaction.'},
        }, const {}).failureReason,
        'Applicable limits not found for this transaction.',
      );
    });

    test('a batch part sends attachmentId only once a file was uploaded', () {
      expect(_request(_power, 'B-P').toJson(multiple: true).containsKey('attachmentId'), isFalse);
      expect(_request(_power, 'B-P').toJson().containsKey('attachmentId'), isTrue, reason: 'pay-bill always does');
    });

    test('debit cards: ISSUED in the several-bills flow, ACTIVATED / ACTIVE in pay-bill', () {
      const body = {
        'accounts': [
          {
            'debitCards': [
              {'cardNo': {'value': 'D1', 'displayValue': 'xx11'}, 'cardStatus': 'ISSUED'},
              {'cardNo': {'value': 'D2', 'displayValue': 'xx22'}, 'cardStatus': 'ACTIVE'},
            ],
          },
        ],
      };
      expect(BillPayAccount.listFromPayload(BillPayType.debitCard, body, multiple: true).map((d) => d.value), ['D1']);
      expect(BillPayAccount.listFromPayload(BillPayType.debitCard, body).map((d) => d.value), ['D2']);
    });
  });

  group('repository', () {
    test('one batch, a part per bill; rows matched by sequenceId', () async {
      final api = _FakeApi(_wrapped(200, {
        'status': {'result': 'SUCCESSFUL'},
        'batchDetailResponseDTOList': [
          {
            'sequenceId': '1',
            'status': 400,
            'header': <String, dynamic>{},
            'responseText': jsonEncode({'message': {'title': 'Second failed'}}),
          },
          {
            'sequenceId': '0',
            'status': 200,
            'header': <String, dynamic>{},
            'responseText': jsonEncode({
              'status': {'result': 'SUCCESSFUL', 'externalReferenceNumber': 'EXT1'},
            }),
          },
        ],
      }));
      final result = await BillPaymentsRepository(api: api).payBills([_request(_power, 'B-P'), _request(_gas, 'B-G')]);
      expect(api.items.map((i) => (i.method, i.uri, i.applicationId)), [
        ('POST', '/ebillPayments', 'digx-payments/ebpp'),
        ('POST', '/ebillPayments', 'digx-payments/ebpp'),
      ]);
      expect(api.items[1].body!['billerRegistrationId'], 'R6');
      final rows = (result as Success<BillBatchOutcome>).data!.rows!;
      expect(rows[0].completed, isTrue);
      expect(rows[0].externalReference, 'EXT1');
      expect(rows[1].failureReason, 'Second failed');
    });

    test('417 + X-Challenge on the batch → one OTP; a missing answer → status 0', () async {
      final otp = await BillPaymentsRepository(
        api: _FakeApi(_wrapped(417, const {}, headers: {
          'x-challenge': [jsonEncode({'referenceNo': 'OTP1', 'authType': 'OTP'})],
        })),
      ).payBills([_request(_power, 'B-P')]);
      expect((otp as Success<BillBatchOutcome>).data!.challenge?.referenceNo, 'OTP1');

      final missing = await BillPaymentsRepository(
        api: _FakeApi(_wrapped(200, {
          'status': {'result': 'SUCCESSFUL'},
          'batchDetailResponseDTOList': <dynamic>[],
        })),
      ).payBills([_request(_power, 'B-P')]);
      expect((missing as Success<BillBatchOutcome>).data!.rows!.single.status, 0);
    });
  });

  group('screen', () {
    Future<_PayRepo> pump(WidgetTester tester, {double width = 390, List<BillBatchRow>? rows}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _PayRepo([_power, _gas], rows: rows);
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
      await tester.tap(find.text('Select all to Pay'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Pay'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('phone: cards → Save rules → Review → status → Billers', (tester) async {
      final repo = await pump(tester);
      expect(find.text('Pay Bills'), findsWidgets);
      // Bill 1 open, bill 2 collapsed; CASA listed with PC_F_INTRNL.
      expect(find.text('Save'), findsOneWidget);
      expect(repo.accountQueries.first, (BillPayType.casa, 'PC_F_INTRNL'));

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Please save all unsaved payments.'), findsOneWidget);
      // Let the message go: on a phone it covers the Submit button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsNothing, reason: 'bill 1 collapsed');

      // Bill 2 was never given an account: Submit opens it (OBDX would send it without one).
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Select an account to proceed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('You have initiated 2 bill payments. Please review the details before you confirm!'), findsWidgets);
      expect(find.text('C-R1'), findsOneWidget);
      expect(find.text('C-R6'), findsOneWidget, reason: "each bill's own details (OBDX shows bill 1's)");

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      // Billers' order: Gas, then Home power.
      expect(repo.paid!.map((r) => r.registration.id), ['R6', 'R1']);
      expect(repo.paid!.map((r) => r.amount), [15, 42]);
      expect(find.text('Multiple Bill Payment Status'), findsWidgets);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Applicable limits not found for this transaction.'), findsOneWidget);
      expect(find.textContaining('EXT1'), findsOneWidget);

      await tester.tap(find.text('Pay Another Bill'));
      await tester.pumpAndSettle();
      expect(find.text('Select all to Pay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Default this account for all" fills bill 2; Delete removes a bill', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.byTooltip('Default this account for all the bill payments records'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget, reason: 'bill 2 got the account without opening');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repo.paid![1].account.value, 'ACC2');
    });

    testWidgets('Delete Bill Payment, not for the last bill', (tester) async {
      await pump(tester);
      expect(find.byTooltip('Delete Bill Payment'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Delete Bill Payment').last);
      await tester.pumpAndSettle();
      expect(find.text('Home power'), findsNothing);
      expect(find.byTooltip('Delete Bill Payment'), findsNothing);
    });

    testWidgets('web: status table; approval → "Reference No." and "Initiated"', (tester) async {
      await pump(
        tester,
        width: 1280,
        rows: const [
          BillBatchRow(status: 202, approvalInitiated: true, referenceNumber: 'REF1'),
          BillBatchRow(status: 202, referenceNumber: 'REF2'),
        ],
      );
      await tester.tap(find.byTooltip('Default this account for all the bill payments records'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      for (final h in ['Biller Name', 'Category', 'From Account', 'Amount', 'Reference No.', 'Status']) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      expect(find.text('Initiated'), findsOneWidget);
      expect(find.text('Pending for approval'), findsNWidgets(2));
      expect(find.text('REF2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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
  List<ObdxBatchItem> items = const [];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> payBills(
    List<ObdxBatchItem> items, {
    String? challengeResponseHeader,
    String? boundary,
  }) async {
    this.items = items;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PayRepo implements BillPaymentsRepository {
  _PayRepo(this.billers, {this.rows});

  final List<Map<String, dynamic>> billers;
  final List<BillBatchRow>? rows;
  List<PayBillRequest>? paid;
  final accountQueries = <(BillPayType, String?)>[];

  @override
  Future<ResponseHandler<List<RegisteredBiller>>> fetchRegisteredBillers() async =>
      ResponseHandler.success([for (final b in billers) RegisteredBiller.fromJson(b)!], code: 200);

  @override
  Future<ResponseHandler<BillerInfo>> fetchBiller(String billerId) async =>
      ResponseHandler.success(BillerInfo.fromJson(_masters[billerId])!, code: 200);

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchOperationalArea(String id) async =>
      ResponseHandler.success({'operationalArea': {'areaName': 'London'}}, code: 200);

  @override
  Future<ResponseHandler<List<BillPayAccount>>> fetchPayAccounts(
    BillPayType type, {
    String? taskCode = billPayTaskCode,
    bool multiple = false,
  }) async {
    accountQueries.add((type, taskCode));
    return ResponseHandler.success(BillPayAccount.listFromPayload(type, _casaBody, multiple: multiple), code: 200);
  }

  @override
  Future<ResponseHandler<BillBatchOutcome>> payBills(
    List<PayBillRequest> requests, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    paid = requests;
    return ResponseHandler.success(
      BillBatchOutcome.done(rows ??
          const [
            BillBatchRow(status: 200, externalReference: 'EXT1', paymentId: 'BP1'),
            BillBatchRow(status: 400, failureReason: 'Applicable limits not found for this transaction.'),
          ]),
      code: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
