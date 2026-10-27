import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_pay_models.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_bill_payments_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/bill_payments_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/billers_screen.dart';

// Pay Bill (B1) — docs/obdx/features/bill-payments.md §7. Field names follow
// the OBDX source and the UAT body capture (§3.7); all values are made up.

Map<String, dynamic> _reg(
  String id,
  String nickname,
  String type, {
  String billerId = 'B-W',
  bool autopay = false,
  Map<String, dynamic>? ebill,
  String status = 'APPROVED',
}) =>
    {
      'id': id,
      'billerId': billerId,
      'billerNickName': nickname,
      'billerType': type,
      'billerName': '$nickname Co',
      'customerName': 'Test Customer',
      'registrationStatus': status,
      'autopay': autopay,
      'location': {'id': 'L1', 'areaName': 'London'},
      'relationshipDetails': [
        {'labelId': 'CONS', 'value': '998877'},
      ],
      if (ebill != null) 'ebill': ebill,
    };

Map<String, dynamic> _master(
  String id,
  String type, {
  List<String> methods = const ['CASA', 'CREDITCARD'],
  bool latePayment = true,
}) =>
    {
      'id': id,
      'name': 'Biller $id',
      'currency': 'GBP',
      'type': type,
      'areaCategoryDetails': [
        {'categoryName': 'Utilities'},
      ],
      'specifications': [
        {'id': 'CONS', 'label': 'Consumer Number'},
      ],
      'paymentMethodsList': [for (final m in methods) {'paymentType': m}],
      'paymentOptions': {'latePayment': latePayment},
    };

final _homePower = _reg('R1', 'Home power', 'PRESENTMENT', billerId: 'B-P', autopay: true, ebill: {
  'id': 'EB1',
  'dueDate': '2099-01-10T00:00:00',
  'status': 'PARTIALPAID',
  'totalAmount': {'currency': 'GBP', 'amount': 42},
  'amountPaid': {'currency': 'GBP', 'amount': 2},
});
final _mobile = _reg('R2', 'Mobile', 'RECHARGE', billerId: 'B-M');
final _water = _reg('R3', 'Water', 'PAYMENT');
final _late = _reg('R4', 'Late bill', 'PRESENTMENT', billerId: 'B-L', ebill: {
  'id': 'EB4',
  'dueDate': '2000-01-01T00:00:00',
  'totalAmount': {'currency': 'GBP', 'amount': 5},
});

final _masters = {
  'B-W': _master('B-W', 'PAYMENT'),
  'B-P': _master('B-P', 'PRESENTMENT'),
  'B-M': _master('B-M', 'RECHARGE', methods: const ['CASA']),
  'B-L': _master('B-L', 'PRESENTMENT', latePayment: false),
};

const _casaBody = {
  'accounts': [
    {
      'id': {'value': 'ACC1', 'displayValue': 'xxxx1234'},
      'currencyCode': 'GBP',
    },
    {
      'id': {'value': 'ACC2', 'displayValue': 'xxxx5678'},
      'accountNickname': 'Main',
      'currencyCode': 'GBP',
      'defaultAccount': true,
    },
  ],
};

const _cardsBody = {
  'creditcards': [
    {
      'creditCard': {'value': 'CC1', 'displayValue': 'xxxx9999'},
      'cardOwnershipType': 'PRIMARY',
      'cardStatus': 'ACT',
    },
    {
      'creditCard': {'value': 'CC2', 'displayValue': 'xxxx0000'},
      'cardOwnershipType': 'ADDON',
      'cardStatus': 'ACT',
    },
    {
      'creditCard': {'value': 'CC3', 'displayValue': 'xxxx1111'},
      'cardOwnershipType': 'PRIMARY',
      'cardStatus': 'IAC',
    },
  ],
};

PayBillRequest _request({
  BillPayType type = BillPayType.casa,
  bool payLater = false,
  DateTime? scheduled,
  DateTime? cardExpiry,
}) {
  final reg = RegisteredBiller.fromJson(_water)!;
  final biller = BillerInfo.fromJson(_masters['B-W'])!;
  return PayBillRequest(
    registration: reg,
    biller: biller,
    type: type,
    account: const BillPayAccount(value: 'ACC2', displayNumber: 'xxxx5678', nickname: 'Main'),
    amount: 12.5,
    today: DateTime(2026, 10, 27),
    payLater: payLater,
    scheduledDate: scheduled,
    location: 'London',
    cardExpiry: cardExpiry,
  );
}

void main() {
  group('model (OBDX pay-bill rules)', () {
    test('Confirm body: the 25 keys of the UAT capture, OBDX shapes', () {
      final json = _request().toJson();
      expect(json.keys.toSet(), {
        'attachmentId', 'billAmount', 'billId', 'billPaymentRelDetails', 'billerId', 'billerName',
        'billerRegistration', 'billerRegistrationId', 'billerType', 'cardExpiryDate', 'category', 'categoryId',
        'customerName', 'debitAccount', 'id', 'location', 'locationId', 'partyId', 'payLater', 'paymentDate',
        'paymentHostStatus', 'paymentStatus', 'paymentType', 'planId', 'recurring',
      });
      expect(json['debitAccount'], {'value': 'ACC2', 'displayValue': 'xxxx5678 - Main'});
      expect(json['billAmount'], {'currency': 'GBP', 'amount': 12.5});
      expect(json['paymentDate'], '2026-10-27T00:00:00');
      expect(json['payLater'], 'false', reason: 'a string in OBDX');
      expect(json['recurring'], 'false');
      expect(json['paymentStatus'], 'COM');
      expect(json['paymentType'], 'CASA');
      expect(json['billerType'], 'PAYMENT');
      expect(json['billerRegistrationId'], 'R3');
      expect(json['category'], 'Utilities');
      expect(json['location'], 'London');
      expect(json['billPaymentRelDetails'], [
        {'labelId': 'CONS', 'value': '998877'},
      ]);
      expect(json['billerRegistration'], {
        'billerNickName': 'Water',
        'autopayInstructions': {'frequency': null, 'endDate': null},
        'subcategory': '',
      });
      expect(json['cardExpiryDate'], isNull);
      expect(json['attachmentId'], isNull);
    });

    test('Later sends the scheduled date; a credit card sends its expiry', () {
      final later = _request(payLater: true, scheduled: DateTime(2026, 11, 3)).toJson();
      expect(later['payLater'], 'true');
      expect(later['paymentDate'], '2026-11-03T00:00:00');
      final card = _request(
        type: BillPayType.creditCard,
        cardExpiry: BillPayRules.cardExpiryLastDay(2, 2028),
      ).toJson();
      expect(card['paymentType'], 'CREDITCARD');
      expect(card['cardExpiryDate'], '2028-02-29T00:00:00');
    });

    test('amount rule: > 0, 13 digits, 2 decimals (validateAmount)', () {
      expect(BillPayRules.amount(''), BillAmountError.required);
      expect(BillPayRules.amount('0'), BillAmountError.notPositive);
      expect(BillPayRules.amount('-3'), BillAmountError.notPositive);
      expect(BillPayRules.amount('12.345'), BillAmountError.invalid);
      expect(BillPayRules.amount('12345678901234'), BillAmountError.invalid);
      expect(BillPayRules.amount('abc'), BillAmountError.invalid);
      expect(BillPayRules.amount('1234567890123.99'), isNull);
      expect(BillPayRules.amount('12.5'), isNull);
    });

    test('prefill: PARTIALPAID → total − paid, else the total', () {
      final partPaid = RegisteredBiller.fromJson(_homePower)!.ebill;
      expect(BillPayRules.prefill(partPaid), 40);
      expect(BillPayRules.prefill(RegisteredBiller.fromJson(_late)!.ebill), 5);
      expect(BillPayRules.prefill(null), isNull);
    });

    test('card expiry: valid through the last day of its month', () {
      expect(BillPayRules.cardExpiryValid(10, 2026, DateTime(2026, 10, 31)), isTrue);
      expect(BillPayRules.cardExpiryValid(9, 2026, DateTime(2026, 10, 1)), isFalse);
    });

    test('checks before the form (showPayBill)', () {
      final today = DateTime(2026, 10, 27);
      RegisteredBiller r(Map<String, dynamic> j) => RegisteredBiller.fromJson(j)!;
      BillerInfo b(String id) => BillerInfo.fromJson(_masters[id])!;
      expect(payBillGate(r(_late), b('B-L'), single: true, today: today), PayBillGate.latePaymentBlocked);
      // Select all to Pay with one bill skips them for presentment billers.
      expect(payBillGate(r(_late), b('B-L'), single: false, today: today), PayBillGate.open);
      expect(payBillGate(r(_homePower), b('B-P'), single: true, today: today), PayBillGate.autopayWarning);
      expect(payBillGate(r(_homePower), b('B-P'), single: false, today: today), PayBillGate.open);
      // OBDX opens nothing here (bug); the app opens the form.
      expect(payBillGate(r({..._homePower, 'autopay': false}), b('B-P'), single: true, today: today), PayBillGate.open);
      expect(
        payBillGate(r({..._water, 'schedulePayment': true}), b('B-W'), single: true, today: today),
        PayBillGate.scheduledWarning,
      );
    });

    test('Payment Type to start with: registration, else Account, else first', () {
      expect(BillPayType.initial([BillPayType.creditCard, BillPayType.casa], 'CREDITCARD'), BillPayType.creditCard);
      expect(BillPayType.initial([BillPayType.creditCard, BillPayType.casa], null), BillPayType.casa);
      expect(BillPayType.initial([BillPayType.debitCard, BillPayType.creditCard], null), BillPayType.debitCard);
    });

    test('Pay From parsers: default account first; PRIMARY + ACT cards; active debit cards', () {
      final casa = BillPayAccount.listFromPayload(BillPayType.casa, _casaBody);
      expect(BillPayAccount.initial(casa, null)?.value, 'ACC2');
      expect(BillPayAccount.initial(casa, 'ACC1')?.value, 'ACC1');
      expect(BillPayAccount.listFromPayload(BillPayType.creditCard, _cardsBody).map((c) => c.value), ['CC1']);
      final debit = BillPayAccount.listFromPayload(BillPayType.debitCard, {
        'accounts': [
          {
            'debitCards': [
              {'cardNo': {'value': 'D1', 'displayValue': 'xx11'}, 'cardStatus': 'ACTIVATED'},
              {'cardNo': {'value': 'D2', 'displayValue': 'xx22'}, 'cardStatus': 'BLOCKED'},
            ],
          },
        ],
      });
      expect(debit.map((d) => d.value), ['D1']);
    });

    test('location: areaName, else "city,state,country"', () {
      final reg = RegisteredBiller.fromJson(_water)!;
      expect(billLocationLabel({'operationalArea': {'areaName': 'Soho'}}, reg), 'Soho');
      expect(billLocationLabel({'operationalArea': {'city': 'Leeds', 'state': 'Yorks', 'country': 'UK'}}, reg), 'Leeds,Yorks,UK');
      expect(billLocationLabel(null, reg), 'London', reason: "the registration's own");
    });
  });

  group('repository (OBDX framework behaviour)', () {
    BillPaymentsRepository repo(int status, Map<String, dynamic> body, {Map<String, List<String>> headers = const {}}) =>
        BillPaymentsRepository(api: _FakeApi(_wrapped(status, body, headers: headers)));

    test('200 → done with status.referenceNumber', () async {
      final r = await repo(200, {
        'status': {'result': 'SUCCESSFUL', 'referenceNumber': 'PAY9'},
      }).payBill(_request());
      final outcome = (r as Success<BillPayOutcome>).data!;
      expect(outcome.reference, 'PAY9');
      expect(outcome.pendingApproval, isFalse);
    });

    test('417 + X-Challenge → OTP; 202 → pending approval', () async {
      final otp = await repo(417, const {}, headers: {
        'x-challenge': [jsonEncode({'referenceNo': 'OTP1', 'authType': 'OTP'})],
      }).payBill(_request());
      expect((otp as Success<BillPayOutcome>).data!.challenge?.referenceNo, 'OTP1');
      final pending = await repo(202, {'status': {'result': 'SUCCESSFUL'}}).payBill(_request());
      expect((pending as Success<BillPayOutcome>).data!.pendingApproval, isTrue);
    });

    test('UAT DIGX_FL_015 shows OBDX\'s own text', () {
      final error = ObdxErrorMapper.fromHttpResponse(400, {
        'result': 'SUCCESSFUL',
        'message': {'code': 'DIGX_FL_015', 'type': 'ERROR', 'title': 'Applicable limits not found for this transaction.'},
      });
      expect(error.userMessage, contains('Applicable limits not found for this transaction.'));
    });

    test('upload: contentDTOList[0].contentId becomes attachmentId; none → failure', () async {
      const file = BillAttachment(name: 'bill.pdf', bytes: [1, 2, 3]);
      final ok = await repo(200, {
        'status': {'result': 'SUCCESSFUL'},
        'contentDTOList': [
          {'contentId': {'value': 'C1', 'displayValue': 'C1'}},
        ],
      }).uploadAttachment(file);
      expect((ok as Success<BillAttachmentOutcome>).data!.contentId, {'value': 'C1', 'displayValue': 'C1'});
      final empty = await repo(200, {'status': {'result': 'SUCCESSFUL'}}).uploadAttachment(file);
      expect(empty, isA<ExceptionError<BillAttachmentOutcome>>());
    });

    test('attachment rules: 15 MB, OBDX types, one case only', () {
      expect(BillAttachmentRules.allowedName('bill.PDF'), isTrue);
      expect(BillAttachmentRules.allowedName('bill.Pdf'), isFalse);
      expect(BillAttachmentRules.allowedName('bill.exe'), isFalse);
      expect(BillAttachmentRules.maxBytes, 15 * 1024 * 1024);
    });
  });

  group('screen', () {
    Future<_PayRepo> pump(WidgetTester tester, {double width = 390, List<Map<String, dynamic>>? billers, bool pending = false}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _PayRepo(billers ?? [_homePower, _mobile, _water], pending: pending);
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

    Future<void> tapRowPay(WidgetTester tester, String nickname) async {
      final row = find.ancestor(of: find.text(nickname), matching: find.byType(InkWell)).first;
      await tester.tap(find.descendant(of: row, matching: find.widgetWithText(OutlinedButton, 'Pay')));
      await tester.pumpAndSettle();
    }

    testWidgets('phone: Pay → form → amount rules → Review → Confirm → Done → Billers', (tester) async {
      final repo = await pump(tester);
      await tapRowPay(tester, 'Water');
      expect(find.text('Pay Bill'), findsWidgets);
      expect(find.text('998877'), findsOneWidget);
      expect(find.text('London'), findsOneWidget);
      expect(find.text('Note: This biller accepts payment via Account and Credit Cards'), findsOneWidget);
      // The default account is picked.
      expect(find.text('xxxx5678 - Main'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Payment Amount is required.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '12.345');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Amount should be lesser than 1 trillion'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '12.50');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('You initiated a request for bill payments. Please review details before you confirm!'), findsWidgets);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final body = repo.paid!.toJson();
      expect(body['billAmount'], {'currency': 'GBP', 'amount': 12.5});
      expect(body['debitAccount'], {'value': 'ACC2', 'displayValue': 'xxxx5678 - Main'});
      expect(find.text('Request submitted successfully.'), findsOneWidget);
      expect(find.text('PAY1'), findsOneWidget);

      await tester.tap(find.text('Pay Another Bill'));
      await tester.pumpAndSettle();
      expect(find.text('Select all to Pay'), findsOneWidget);
      expect(repo.listLoads, 2, reason: 'the list reloads after a payment');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Recharge: a plan sets the amount and locks it', (tester) async {
      final repo = await pump(tester);
      await tapRowPay(tester, 'Mobile');
      expect(find.text('Recharge Amount'), findsOneWidget);
      await tester.tap(find.text('Select Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Talk 10').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '10');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repo.paid!.toJson()['planId'], 'P1');
      expect(repo.paid!.toJson()['billAmount'], {'currency': 'GBP', 'amount': 10.0});
    });

    testWidgets('Later needs a Scheduled Date', (tester) async {
      await pump(tester);
      await tapRowPay(tester, 'Water');
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Scheduled Date is required.'), findsOneWidget);
    });

    testWidgets('Credit Cards: expiry required, then sent with the card', (tester) async {
      final repo = await pump(tester);
      await tapRowPay(tester, 'Water');
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Credit Cards').last);
      await tester.pumpAndSettle();
      expect(find.text('xxxx9999'), findsOneWidget, reason: 'PRIMARY + ACT only');
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Expiry Month is required.'), findsOneWidget);

      final year = DateTime.now().year + 1;
      await tester.tap(find.text('Expiry Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expiry Year'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$year').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final body = repo.paid!.toJson();
      expect(body['paymentType'], 'CREDITCARD');
      expect(body['debitAccount']['value'], 'CC1');
      expect(body['cardExpiryDate'], '$year-12-31T00:00:00');
    });

    testWidgets('Auto Pay biller: OBDX warning; Cancel stays on Billers, Continue opens the form', (tester) async {
      await pump(tester);
      await tapRowPay(tester, 'Home power');
      expect(find.textContaining('This bill is registered for auto payment.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Select all to Pay'), findsOneWidget);

      await tapRowPay(tester, 'Home power');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      // PARTIALPAID: 42 − 2.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '40');
    });

    testWidgets('Select all to Pay with one bill opens the form without the warning', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Select all to Pay'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Pay'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This bill is registered for auto payment.'), findsNothing);
      expect(find.text('Payment Amount'), findsOneWidget);
    });

    testWidgets('late payment not allowed: blocked with OBDX message', (tester) async {
      await pump(tester, billers: [_late]);
      await tapRowPay(tester, 'Late bill');
      expect(find.text('Last Date of Bill Payment has Passed. Late Payment not allowed by Biller!'), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(find.text('Late bill'), findsOneWidget);
      expect(find.text('Payment Amount'), findsNothing);
    });

    testWidgets('approval: "Pay Bill submitted for approval."', (tester) async {
      await pump(tester, pending: true);
      await tapRowPay(tester, 'Water');
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Pay Bill submitted for approval.'), findsOneWidget);
    });

    testWidgets('server refusal: OBDX message, stays on Review', (tester) async {
      final repo = await pump(tester);
      repo.refuse = 'Applicable limits not found for this transaction.';
      await tapRowPay(tester, 'Water');
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Applicable limits not found for this transaction.'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('a presentment biller without a bill has no Pay', (tester) async {
      await pump(tester, billers: [_reg('R5', 'No bill', 'PRESENTMENT', billerId: 'B-P'), _water]);
      final row = find.ancestor(of: find.text('No bill'), matching: find.byType(InkWell)).first;
      expect(find.descendant(of: row, matching: find.widgetWithText(OutlinedButton, 'Pay')), findsNothing);
    });

    testWidgets('web: form, Review with Detailed Bill', (tester) async {
      await pump(tester, width: 1280);
      await tapRowPay(tester, 'Home power');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed Bill'));
      await tester.pumpAndSettle();
      expect(find.text('Biller Number'), findsOneWidget);
      expect(find.text('EB1'), findsOneWidget);
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

  @override
  Future<ResponseHandler<Map<String, dynamic>>> payBill(
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) async =>
      response;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> uploadAttachment({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? challengeResponseHeader,
  }) async =>
      response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PayRepo implements BillPaymentsRepository {
  _PayRepo(this.billers, {this.pending = false});

  final List<Map<String, dynamic>> billers;
  final bool pending;
  int listLoads = 0;
  PayBillRequest? paid;

  /// Set: Confirm fails with this OBDX message.
  String? refuse;

  @override
  Future<ResponseHandler<List<RegisteredBiller>>> fetchRegisteredBillers() async {
    listLoads++;
    return ResponseHandler.success([for (final b in billers) RegisteredBiller.fromJson(b)!], code: 200);
  }

  @override
  Future<ResponseHandler<RegisteredBiller>> fetchRegisteredBiller(String id) async =>
      ResponseHandler.success(RegisteredBiller.fromJson(billers.firstWhere((b) => b['id'] == id))!, code: 200);

  @override
  Future<ResponseHandler<BillerInfo>> fetchBiller(String billerId) async =>
      ResponseHandler.success(BillerInfo.fromJson(_masters[billerId])!, code: 200);

  @override
  Future<ResponseHandler<List<BillPlan>>> fetchPlans(String billerId) async => ResponseHandler.success(
        BillPlan.listFromPayload({
          'planDTOs': [
            {'id': 'P1', 'description': 'Talk 10', 'amount': {'currency': 'GBP', 'amount': 10}},
          ],
        }),
        code: 200,
      );

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchOperationalArea(String id) async =>
      ResponseHandler.success({'operationalArea': {'areaName': 'London'}}, code: 200);

  @override
  Future<ResponseHandler<List<BillPayAccount>>> fetchPayAccounts(BillPayType type) async => ResponseHandler.success(
        BillPayAccount.listFromPayload(type, type == BillPayType.creditCard ? _cardsBody : _casaBody),
        code: 200,
      );

  @override
  Future<ResponseHandler<BillPayOutcome>> payBill(
    PayBillRequest request, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    if (refuse != null) return ResponseHandler.error(400, refuse);
    paid = request;
    return ResponseHandler.success(BillPayOutcome.done(reference: 'PAY1', pendingApproval: pending), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
