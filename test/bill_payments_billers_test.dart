import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_bill_payments_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/bill_payments_repository.dart';

// Field names follow the UAT capture (docs/obdx/features/bill-payments.md
// §3.5); every value here is made up.

Map<String, dynamic> _item({
  required String id,
  required String nickname,
  required String type,
  String status = 'APPROVED',
  bool autopay = false,
  bool? schedulePayment,
  Map<String, dynamic>? autopayInstructions,
  Map<String, dynamic>? ebill,
  bool withRelationships = true,
  bool withBiller = true,
}) =>
    {
      'id': id,
      'billerId': 'B-$id',
      'billerName': 'Biller $id',
      'billerNickName': nickname,
      'billerType': type,
      'customerName': 'Test Customer',
      'partyId': 'P1',
      'userId': 'U1',
      'registrationStatus': status,
      'autopay': autopay,
      if (schedulePayment != null) 'schedulePayment': schedulePayment,
      'autopayInstructions': autopayInstructions ??
          {
            'debitAccount': {'value': 'X', 'displayValue': 'xx1'},
            'limitAmount': {'currency': 'GBP', 'amount': 0},
            'startDate': '2026-01-01T00:00:00',
            'frequency': 'MONTHLY',
            'paymentType': 'CASA',
          },
      'category': {
        'id': 'C1',
        'name': 'Electricity',
        'priority': 1,
        'logo': {'value': 'LOGO1', 'displayValue': 'logo'},
        'billerCount': 2,
        'subCategories': <String>[],
      },
      'location': {'id': 'L1', 'country': 'GB', 'state': 'S', 'city': 'C', 'areaName': 'Area'},
      'relationshipDetails': withRelationships
          ? [
              {'labelId': 'CONSUMER_NO', 'value': '123', 'billerRegistrationId': id},
            ]
          : <Map<String, dynamic>>[],
      if (ebill != null) 'ebill': ebill,
      if (withBiller)
        'biller': {
          'id': 'B-$id',
          'name': 'Biller $id',
          'currency': 'GBP',
          'areaCategoryDetails': [
            {'categoryName': 'Electricity', 'operationalAreaName': 'Area'},
          ],
        },
    };

Map<String, dynamic> _ebill(String dueDate) => {
      'id': 'E1',
      'billerId': 'B',
      'billerRegistartionId': 'R', // OBDX's spelling
      'generationDate': '2026-10-01T00:00:00',
      'dueDate': dueDate,
      'status': 'UNPAID',
      'totalAmount': {'currency': 'GBP', 'amount': 120},
      'planId': 'PL1',
    };

final _today = DateTime(2026, 10, 19);

class _FakeApi implements ObdxBillPaymentsApi {
  _FakeApi(this.respond);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final ResponseHandler<Map<String, dynamic>> Function(String call) respond;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchRegisteredBillers() async =>
      respond('list');

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchRegisteredBiller(String id) async =>
      respond('detail');

  @override
  Future<ResponseHandler<Map<String, dynamic>>> deleteRegisteredBiller(
    String id, {
    Map<String, dynamic>? body,
    String? challengeResponseHeader,
  }) async =>
      respond('delete');
}

ResponseHandler<Map<String, dynamic>> _wrapped(
  int status,
  Map<String, dynamic> body, {
  Map<String, List<String>> headers = const {},
}) =>
    ResponseHandler.success({
      'statusCode': status,
      'headers': headers,
      'rawBody': jsonEncode(body),
      'body': body,
    });

void main() {
  group('model', () {
    test('list item: fields, embedded biller, missing schedulePayment = false', () {
      final list = RegisteredBiller.listFromPayload({
        'billerRegistrationDTOs': [
          _item(id: 'R1', nickname: 'Home power', type: 'PRESENTMENT_PAYMENT', ebill: _ebill('2026-10-25T00:00:00')),
        ],
        'status': {'result': 'SUCCESSFUL'},
      });
      final b = list.single;
      expect(b.id, 'R1');
      expect(b.type, BillerType.presentmentPayment);
      expect(b.schedulePayment, isFalse);
      expect(b.category?.logoId, 'LOGO1');
      expect(b.relationships.single.labelId, 'CONSUMER_NO');
      expect(b.ebill?.dueDate, DateTime(2026, 10, 25));
      expect(b.ebill?.totalAmount?.amount, 120);
      expect(b.biller?.categoryName, 'Electricity');
      expect(b.displayBillerName, 'Biller R1');
    });

    test('details payload has no embedded biller', () {
      final item = _item(id: 'R2', nickname: 'Water', type: 'PAYMENT', withBiller: false)
        ..remove('billerName');
      final b = RegisteredBiller.fromDetailPayload({'billerRegistration': item});
      expect(b, isNotNull);
      expect(b!.biller, isNull);
      expect(b.displayBillerName, '');
    });

    test('unknown billerType is kept as unknown', () {
      expect(BillerType.fromCode('SOMETHING_NEW'), BillerType.unknown);
      expect(BillerType.fromCode('recharge'), BillerType.recharge);
    });
  });

  group('groupBillers (OBDX hooks.js:296-336)', () {
    final billers = [
      _item(id: '1', nickname: 'zeta', type: 'PAYMENT'),
      _item(id: '2', nickname: 'Alpha', type: 'PAYMENT'),
      _item(id: '3', nickname: 'Mobile', type: 'RECHARGE'),
      _item(id: '4', nickname: 'Gas', type: 'PRESENTMENT'),
      _item(id: '5', nickname: 'Power+bill', type: 'PRESENTMENT_PAYMENT', ebill: _ebill('2026-10-25')),
      _item(id: '6', nickname: 'Power', type: 'PRESENTMENT_PAYMENT'),
      _item(id: '7', nickname: 'No rel', type: 'PAYMENT', withRelationships: false),
      _item(id: '8', nickname: 'Odd', type: 'NEW_TYPE'),
    ].map(RegisteredBiller.fromJson).whereType<RegisteredBiller>();

    final groups = groupBillers(billers);

    test('three groups in OBDX order, always present', () {
      expect(groups.keys, [BillerType.presentment, BillerType.recharge, BillerType.payment]);
    });

    test('PRESENTMENT_PAYMENT goes by ebill; no relationship / unknown type dropped', () {
      expect(groups[BillerType.presentment]!.map((b) => b.id), ['4', '5']);
      expect(groups[BillerType.recharge]!.map((b) => b.id), ['3']);
      expect(groups[BillerType.payment]!.map((b) => b.id), ['2', '6', '1']);
    });
  });

  group('status and actions (hooks.js:213-266, 476-499)', () {
    RegisteredBiller b(Map<String, dynamic> json) => RegisteredBiller.fromJson(json)!;

    test('overdue when the e-bill due date is before today', () {
      final biller = b(_item(id: '1', nickname: 'a', type: 'PRESENTMENT', ebill: _ebill('2026-10-18')));
      expect(biller.paymentStatus(_today), BillerPaymentStatus.overdue);
    });

    test('due today is not overdue', () {
      final biller = b(_item(id: '1', nickname: 'a', type: 'PRESENTMENT', ebill: _ebill('2026-10-19T10:00:00')));
      expect(biller.paymentStatus(_today), isNull);
    });

    test('auto pay badge and delete blocked', () {
      final biller = b(_item(id: '1', nickname: 'a', type: 'PRESENTMENT_PAYMENT', autopay: true));
      expect(biller.paymentStatus(_today), BillerPaymentStatus.autopay);
      expect(biller.canDelete(_today), isFalse);
    });

    test('scheduled pay only while the schedule is still active', () {
      final active = b(_item(
        id: '1',
        nickname: 'a',
        type: 'PAYMENT',
        schedulePayment: true,
        autopayInstructions: {'startDate': '2026-09-01', 'endDate': '2026-12-31'},
      ));
      final ended = b(_item(
        id: '2',
        nickname: 'b',
        type: 'PAYMENT',
        schedulePayment: true,
        autopayInstructions: {'startDate': '2026-09-01', 'endDate': '2026-10-01'},
      ));
      expect(active.paymentStatus(_today), BillerPaymentStatus.scheduledPay);
      expect(active.canDelete(_today), isFalse);
      expect(ended.paymentStatus(_today), isNull);
      expect(ended.canDelete(_today), isTrue);
    });

    test('no badge unless APPROVED; edit blocked while PENDING', () {
      final pending = b(_item(id: '1', nickname: 'a', type: 'PRESENTMENT', status: 'PENDING', autopay: true));
      expect(pending.paymentStatus(_today), isNull);
      expect(pending.canEdit, isFalse);
      expect(b(_item(id: '2', nickname: 'b', type: 'PAYMENT')).canEdit, isTrue);
    });
  });

  group('repository', () {
    test('list parses; 200 with an ERROR message becomes an error', () async {
      final ok = BillPaymentsRepository(
        api: _FakeApi((_) => _wrapped(200, {
              'billerRegistrationDTOs': [_item(id: 'R1', nickname: 'a', type: 'PAYMENT')],
              'status': {'result': 'SUCCESSFUL', 'message': {'type': 'INFO'}},
            })),
      );
      final result = await ok.fetchRegisteredBillers();
      expect(result, isA<Success<List<RegisteredBiller>>>());
      expect((result as Success<List<RegisteredBiller>>).data!.single.id, 'R1');

      final failing = BillPaymentsRepository(
        api: _FakeApi((_) => _wrapped(200, {
              'status': {
                'result': 'FAILURE',
                'message': {'type': 'ERROR', 'code': 'DIGX_X', 'title': 'Nope'},
              },
            })),
      );
      expect(await failing.fetchRegisteredBillers(), isA<Error<List<RegisteredBiller>>>());
    });

    test('delete 202 → deleted, pending approval', () async {
      final repo = BillPaymentsRepository(
        api: _FakeApi((_) => _wrapped(202, {
              'status': {'result': 'SUCCESSFUL', 'referenceNumber': 'REF1'},
            })),
      );
      final result = await repo.deleteRegisteredBiller('R1');
      final outcome = (result as Success<BillerDeleteOutcome>).data!;
      expect(outcome.pendingApproval, isTrue);
      expect(outcome.reference, 'REF1');
      expect(outcome.challenge, isNull);
    });

    test('delete 417 + X-Challenge → OTP required', () async {
      final repo = BillPaymentsRepository(
        api: _FakeApi((_) => _wrapped(
              417,
              const {},
              headers: {
                'x-challenge': [jsonEncode({'referenceNo': 'OTPREF', 'authType': 'OTP'})],
              },
            )),
      );
      final result = await repo.deleteRegisteredBiller('R1');
      final outcome = (result as Success<BillerDeleteOutcome>).data!;
      expect(outcome.challenge?.referenceNo, 'OTPREF');
      expect(outcome.invalidOtp, isFalse);
    });
  });
}
