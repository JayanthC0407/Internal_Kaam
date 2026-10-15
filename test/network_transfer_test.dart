import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/own_account_transfer.dart';
import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_payee_api.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_payments_api.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/network_transfer_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_transfer_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payees/payee_hub_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/multiple_transfers_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/network_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/transfers_module_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/tabs/transfer_tab_screen.dart';

// ── Data shaped like the OBDX 22.2 DTOs (values made up) ────────────────

final _account = CasaAccount.fromJson({
  'id': {'value': 'ACC1', 'displayValue': 'xxxxxxxxxxxx1022'},
  'currencyCode': 'GBP',
  'availableBalance': {'currency': 'GBP', 'amount': 5000},
});

const _internalPayee = TransferPayee(
  id: 'P1',
  name: 'John Smith',
  nickName: 'John',
  payeeType: 'INTERNAL',
  groupId: 'G1',
  accountNumber: '000000123456',
);

const _intlPayee = TransferPayee(
  id: 'P2',
  name: 'Ana Lopez',
  payeeType: 'INTERNATIONAL',
  accountNumber: 'ES9121000418450200051332',
);

final _networks = TransferNetwork.listFromPayload({
  'network': [
    {
      'code': 'INTERNAL',
      'description': 'Internal',
      'paymentType': 'INTERNAL',
      'taskCode': 'PC_F_INTRNL',
      'hasStandingInstruction': true,
      'networkCurrency': [
        {
          'currency': 'GBP',
          'minAmount': {'amount': 1},
          'maxAmount': {'amount': 10000},
        },
      ],
    },
    {'code': 'SWIFT', 'description': 'SWIFT', 'paymentType': 'INTERNATIONAL'},
    {
      'code': 'INTERNATIONALSWIFTGPI',
      'description': 'SWIFT gpi',
      'paymentType': 'INTERNATIONAL',
    },
  ],
});

NetworkTransferRequest _request({
  TransferPayee? payee,
  AdhocBeneficiary? adhoc,
  TransferKind kind = TransferKind.internal,
  String network = 'INTERNAL',
  RepeatSchedule? schedule,
  ChargeBearer charges = ChargeBearer.me,
}) =>
    NetworkTransferRequest(
      kind: kind,
      network: network,
      debitAccount: _account,
      amount: 250,
      currency: 'GBP',
      paymentDate: DateTime(2026, 10, 9),
      payee: payee,
      adhoc: adhoc,
      remarks: ' rent ',
      charges: charges,
      schedule: schedule,
    );

// ── Fakes ────────────────────────────────────────────────────────────────

class _FakeRepository implements NetworkTransferRepository {
  _FakeRepository({this.needOtp = false, this.refuseRow});

  bool needOtp;

  /// A batch row the bank refuses at validation.
  int? refuseRow;
  final validated = <NetworkTransferRequest>[];
  final submitted = <String>[];

  /// Each batch call: how many transfers it carried.
  final batches = <String>[];

  Future<ResponseHandler<T>> _ok<T>(T v) async =>
      ResponseHandler.success(v, code: 200);

  @override
  Future<ResponseHandler<List<TransferNetwork>>> fetchNetworks() => _ok(_networks);

  @override
  Future<ResponseHandler<List<TransferPayee>>> fetchPayees() =>
      _ok([_internalPayee, _intlPayee]);

  @override
  Future<ResponseHandler<List<CasaAccount>>> fetchDebitAccounts(String? taskCode) =>
      _ok([_account]);

  @override
  Future<ResponseHandler<List<TransferPurpose>>> fetchPurposes(String networkCode) =>
      _ok(networkCode == 'INTERNAL'
          ? const []
          : const [TransferPurpose(code: 'FAM', description: 'Family support')]);

  @override
  Future<ResponseHandler<List<GpiCurrency>>> fetchGpiCurrencies() =>
      _ok(const [GpiCurrency(code: 'EUR', description: 'Euro', min: 10, max: 5000)]);

  @override
  Future<ResponseHandler<List<TransferFrequency>>> fetchFrequencies() =>
      _ok(TransferFrequency.all);

  @override
  Future<ResponseHandler<PaymentChargesSummary>> fetchCharges(
    NetworkTransferRequest request,
  ) =>
      _ok(const PaymentChargesSummary(totalAmount: 2.5, currency: 'GBP'));

  @override
  Future<ResponseHandler<TransferValidationResult>> validate(
    NetworkTransferRequest request,
  ) {
    validated.add(request);
    return _ok(TransferValidationResult(
      systemReferenceId: 'SYS${validated.length}',
      valueDate: DateTime(2026, 10, 9),
    ));
  }

  @override
  Future<ResponseHandler<TransferSubmitOutcome>> submit(
    NetworkTransferRequest request, {
    ObdxChallenge? challenge,
    String? otp,
  }) {
    submitted.add('${request.systemReferenceId}${otp == null ? '' : ':$otp'}');
    if (needOtp && otp == null) {
      return _ok(const TransferSubmitOutcome.otpRequired(
        ObdxChallenge(authType: 'OTP', referenceNo: 'CH1', attemptsLeft: 3),
      ));
    }
    return _ok(TransferSubmitOutcome.success(
      TransferSubmitResult(referenceNumber: 'REF-${request.systemReferenceId}'),
    ));
  }

  @override
  Future<ResponseHandler<List<BatchRowResult<TransferValidationResult>>>>
      validateBatch(List<NetworkTransferRequest> requests) {
    batches.add('validate:${requests.length}');
    validated.addAll(requests);
    return _ok([
      for (final (i, _) in requests.indexed)
        i == refuseRow
            ? const BatchRowResult<TransferValidationResult>.failed(
                'Amount exceeds the daily limit.',
              )
            : BatchRowResult.ok(
                TransferValidationResult(systemReferenceId: 'SYS${i + 1}'),
              ),
    ]);
  }

  @override
  Future<ResponseHandler<BatchSubmitOutcome>> submitBatch(
    List<NetworkTransferRequest> requests, {
    ObdxChallenge? challenge,
    String? otp,
  }) {
    batches.add('submit:${requests.length}${otp == null ? '' : ':$otp'}');
    if (needOtp && otp == null) {
      return _ok(const BatchSubmitOutcome.otpRequired(
        ObdxChallenge(authType: 'OTP', referenceNo: 'CH1', attemptsLeft: 3),
      ));
    }
    return _ok(BatchSubmitOutcome.done([
      for (final r in requests)
        BatchRowResult.ok(
          TransferSubmitResult(referenceNumber: 'REF-${r.systemReferenceId}'),
        ),
    ]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records which endpoint and headers a call used.
class _FakePaymentsApi implements ObdxPaymentsApi {
  _FakePaymentsApi(this.answer);

  final Map<String, dynamic> answer;
  final calls = <String>[];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> postPayNetwork(
    Map<String, dynamic> body, {
    bool validateOnly = false,
    String? challengeResponseHeader,
  }) async {
    calls.add('network${validateOnly ? ':validate' : ''}');
    return ResponseHandler.success(answer);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> postPayNetworkInstruction(
    Map<String, dynamic> body, {
    bool validateOnly = false,
    String? challengeResponseHeader,
  }) async {
    calls.add('instruction${validateOnly ? ':validate' : ''}');
    return ResponseHandler.success(answer);
  }

  final batchItems = <List<ObdxBatchItem>>[];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> postBatch(
    List<ObdxBatchItem> items, {
    required String batchType,
    String? challengeResponseHeader,
    String? boundary,
  }) async {
    batchItems.add(items);
    calls.add('batch:$batchType${challengeResponseHeader == null ? '' : ':otp'}');
    return ResponseHandler.success(answer);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Unused implements ObdxPayeeApi, ObdxAccountsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NetworkTransferRepository _repo(_FakePaymentsApi api) => NetworkTransferRepository(
      paymentsApi: api,
      payeeApi: _Unused(),
      accountsApi: _Unused(),
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required _FakeRepository repository,
  double width = 1280,
  double height = 1500,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [networkTransferRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleConfig.supportedLocales,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('the request body (NetworkPaymentDTO)', () {
    test('an existing payee: by id with a source, so the server fills it in', () {
      final json = _request(payee: _internalPayee).toJson();
      expect(json['paymentType'], 'INTERNAL');
      expect(json['network'], 'INTERNAL');
      expect(json['adhocPayment'], isFalse);
      expect(json['source'], 'PAYEE');
      expect((json['payee'] as Map)['id'], 'P1');
      expect((json['payee'] as Map)['payeeType'], 'INTERNAL');
      expect(json['debitAccountId'], {'displayValue': 'xxxxxxxxxxxx1022', 'value': 'ACC1'});
      expect(json['amount'], {'currency': 'GBP', 'amount': 250.0});
      expect(json['paymentDate'], '2026-10-09T00:00:00');
      expect(json['remarks'], 'rent');
      expect(json.containsKey('frequency'), isFalse);
    });

    test('an adhoc domestic payee: clearing code, no address', () {
      final json = _request(
        kind: TransferKind.domestic,
        network: 'NEFT',
        adhoc: const AdhocBeneficiary(
          kind: TransferKind.domestic,
          accountNumber: '5566778899',
          name: 'Ravi Kumar',
          bankCode: 'HDFC0001234',
        ),
      ).toJson();
      expect(json['adhocPayment'], isTrue);
      expect(json.containsKey('source'), isFalse);
      final bene = (json['beneficiary'] as List).single as Map;
      expect(bene['creditAccountId'], '5566778899');
      expect(bene['beneficiaryName'], 'Ravi Kumar');
      final bank = (bene['beneficiaryBankDetails'] as List).single as Map;
      expect(bank['bankDetailsType'], 'NAC');
      expect(bank['nationalClringCod'], 'HDFC0001234');
      expect(bank['bic2'], 'HDFC0001234');
      expect(bank['nationalClringCodType'], 'NEFT');
      expect(bene.containsKey('addressDTO'), isFalse);
    });

    test('an adhoc international payee: SWIFT and address; charges shared', () {
      final json = _request(
        kind: TransferKind.international,
        network: 'SWIFT',
        charges: ChargeBearer.shared,
        adhoc: const AdhocBeneficiary(
          kind: TransferKind.international,
          accountNumber: 'ES9121000418450200051332',
          name: 'Ana Lopez',
          bankCode: 'CAIXESBB',
          addressLine1: '1 Calle Mayor',
          city: 'Madrid',
          country: 'ES',
        ),
      ).toJson();
      expect(json['paymentType'], 'INTERNATIONAL');
      expect(json['charges'], 'U');
      final bene = (json['beneficiary'] as List).single as Map;
      final bank = (bene['beneficiaryBankDetails'] as List).single as Map;
      expect(bank['bankDetailsType'], 'SWI');
      expect(bank['swiftCode'], 'CAIXESBB');
      expect(((bene['addressDTO'] as List).single as Map)['country'], 'ES');
    });

    test('no SWIFT code: the bank by name and address (SPE)', () {
      const adhoc = AdhocBeneficiary(
        kind: TransferKind.international,
        accountNumber: '123',
        name: 'X',
        bankName: 'Small Bank',
      );
      expect(adhoc.codeType, BankCodeType.nameAndAddress);
    });

    test('a repeat transfer: the _SI type and a schedule', () {
      final json = _request(
        payee: _internalPayee,
        schedule: RepeatSchedule(
          frequency: TransferFrequency.byCode('MONTHLY')!,
          startDate: DateTime(2026, 11, 1),
          instances: 3,
        ),
      ).toJson();
      expect(json['paymentType'], 'INTERNAL_SI');
      expect(json['frequency'], 'MONTHLY');
      expect(json['startDate'], '2026-11-01T00:00:00');
      // 3 monthly transfers: Nov, Dec, Jan — the server's calculateEndDate.
      expect(json['endDate'], '2027-01-01T00:00:00');
      expect(json['instances'], 3);
      expect(json['paymentDate'], '2026-11-01T00:00:00');
    });

    test('frequencies step as the server computes them', () {
      final start = DateTime(2026, 1, 31);
      expect(TransferFrequency.byCode('FORNIGHT')!.nth(start, 3), DateTime(2026, 2, 28));
      expect(TransferFrequency.byCode('DAILY')!.nth(start, 2), DateTime(2026, 2, 1));
      expect(TransferFrequency.byCode('QUARTERLY')!.nth(start, 2).month, 5);
    });
  });

  group('parsing', () {
    test('networks: task codes, standing instructions and limits', () {
      final internal = _networks.first;
      expect(internal.taskCode, 'PC_F_INTRNL');
      expect(internal.hasStandingInstruction, isTrue);
      expect(internal.limitFor('GBP')!.max, 10000);
      expect(_networks.map((n) => n.code), contains(kGpiNetworkCode));
    });

    test('payees: usable rows only, with their kind', () {
      final payee = TransferPayee.fromJson({
        'id': 'P9',
        'name': 'Ravi',
        'payeeType': 'GENERICDOMESTIC',
        'accountNumber': '5566778899',
      })!;
      expect(payee.kind, TransferKind.domestic);
      expect(payee.maskedAccount, '••8899');
      expect(TransferPayee.fromJson({'name': 'no id'}), isNull);
    });

    test('purposes, GPI currencies, banks', () {
      expect(
        TransferPurpose.listFromPayload({
          'purposes': [
            {'purposeCode': 'FAM', 'purposeDescription': 'Family support'},
          ],
        }).single.description,
        'Family support',
      );
      final eur = GpiCurrency.listFromPayload({
        'currencyList': [
          {'code': 'EUR', 'minAmount': {'amount': 10}, 'maxAmount': {'amount': 5000}},
        ],
      }).single;
      expect(eur.max, 5000);
      expect(
        TransferBank.fromPayload({'name': 'CITI BANK', 'branchName': 'London'})!.name,
        'CITI BANK',
      );
    });
  });

  group('the OBDX batch (Multiple Transfers)', () {
    test('the body is the multipart the OBDX web builds', () {
      final body = ObdxBatchEncoder.encode(
        [
          const ObdxBatchItem(
            method: 'POST',
            uri: '/payments/pay/network',
            applicationId: 'digx-payments/payment',
            body: {'amount': 1},
            headers: {'X-Validate-Only': 'true'},
          ),
          const ObdxBatchItem(
            method: 'POST',
            uri: '/payments/pay/network',
            applicationId: 'digx-payments/payment',
            body: {'amount': 2},
          ),
        ],
        '--OBDXbatchabc',
      );
      expect(
        body,
        '----OBDXbatchabc\r\n'
        'Content-Id: 0\r\n'
        'Content-Type: application/json\r\n'
        'X-Validate-Only: true\r\n'
        'Application-Id: digx-payments/payment\r\n'
        '\r\nPOST /payments/pay/network HTTP/1.1\r\n'
        '\r\n{"amount":1}\r\n'
        '----OBDXbatchabc\r\n'
        'Content-Id: 1\r\n'
        'Content-Type: application/json\r\n'
        'Application-Id: digx-payments/payment\r\n'
        '\r\nPOST /payments/pay/network HTTP/1.1\r\n'
        '\r\n{"amount":2}\r\n'
        '----OBDXbatchabc--\r\n',
      );
      expect(ObdxBatchEncoder.newBoundary(), startsWith('--OBDXbatch'));
    });

    test('answers are read in request order, approvals noticed', () {
      final results = ObdxBatchItemResult.listFromPayload({
        'batchDetailResponseDTOList': [
          {
            'sequenceId': '1',
            'status': 202,
            'responseText': '{"status":{"result":"SUCCESSFUL"}}',
            'header': {'APPROVAL_STATUS': 'INITIATED'},
          },
          {
            'sequenceId': '0',
            'status': 200,
            'responseText': '{"systemReferenceId":"S0"}',
          },
          {'sequenceId': 'x', 'status': 200},
        ],
      });
      expect(results.map((r) => r.sequenceId), [0, 1]);
      expect(results[0].body['systemReferenceId'], 'S0');
      expect(results[0].pendingApproval, isFalse);
      expect(results[1].succeeded, isTrue);
      expect(results[1].pendingApproval, isTrue);
    });

    test('validate: one CMFT batch, each part validate-only, per-row answers',
        () async {
      final api = _FakePaymentsApi({
        'statusCode': 200,
        'body': {
          'status': {'result': 'SUCCESSFUL'},
          'batchDetailResponseDTOList': [
            {
              'sequenceId': '0',
              'status': 200,
              'responseText': '{"systemReferenceId":"S0"}',
            },
            {
              'sequenceId': '1',
              'status': 400,
              'responseText': '{"message":{"title":"Insufficient funds",'
                  '"detail":"Insufficient funds","type":"ERROR"}}',
            },
          ],
        },
      });
      final result = await _repo(api).validateBatch([
        _request(payee: _internalPayee),
        _request(payee: _intlPayee),
      ]);
      expect(api.calls, ['batch:CMFT']);
      final items = api.batchItems.single;
      expect(items.map((i) => i.uri), everyElement('/payments/pay/network'));
      expect(items.map((i) => i.headers['X-Validate-Only']), everyElement('true'));
      expect(items.first.body!['payee'], isNotNull);

      final rows = (result as Success<List<BatchRowResult<TransferValidationResult>>>).data!;
      expect(rows[0].ok, isTrue);
      expect(rows[0].value!.systemReferenceId, 'S0');
      expect(rows[1].ok, isFalse);
      expect(rows[1].error, isNotEmpty);
    });

    test('submit: one OTP for the whole batch', () async {
      final api = _FakePaymentsApi({
        'statusCode': 417,
        'headers': {
          'X-CHALLENGE': ['{"referenceNo":"CH5","authType":"OTP","attemptsLeft":3}'],
        },
        'body': {},
      });
      final result = await _repo(api).submitBatch([
        _request(payee: _internalPayee),
        _request(payee: _intlPayee),
      ]);
      expect(api.calls, ['batch:MFT']);
      final outcome = (result as Success<BatchSubmitOutcome>).data!;
      expect(outcome.challenge!.referenceNo, 'CH5');
      expect(outcome.invalidOtp, isFalse);
    });

    test('submit: references, approvals and a row the bank did not answer',
        () async {
      final api = _FakePaymentsApi({
        'statusCode': 200,
        'body': {
          'status': {'result': 'SUCCESSFUL'},
          'batchDetailResponseDTOList': [
            {
              'sequenceId': '0',
              'status': 200,
              'responseText': '{"status":{"result":"SUCCESSFUL",'
                  '"referenceNumber":"R1"}}',
            },
            {
              'sequenceId': '1',
              'status': 202,
              'responseText': '{"status":{"result":"SUCCESSFUL",'
                  '"referenceNumber":"R2"}}',
              'header': {'APPROVAL_STATUS': 'INITIATED'},
            },
          ],
        },
      });
      final result = await _repo(api).submitBatch(
        [for (var i = 0; i < 3; i++) _request(payee: _internalPayee)],
        challenge: const ObdxChallenge(authType: 'OTP', referenceNo: 'CH5'),
        otp: '1234',
      );
      expect(api.calls, ['batch:MFT:otp']);
      final rows = (result as Success<BatchSubmitOutcome>).data!.rows;
      expect(rows[0].value!.referenceNumber, 'R1');
      expect(rows[1].pendingApproval, isTrue);
      expect(rows[2].ok, isFalse);
    });
  });

  group('the repository', () {
    test('a repeat transfer validates on networkInstruction', () async {
      final api = _FakePaymentsApi({
        'statusCode': 200,
        'body': {'systemReferenceId': 'S1'},
      });
      await _repo(api).validate(_request(
        payee: _internalPayee,
        schedule: RepeatSchedule(
          frequency: TransferFrequency.all.first,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 12, 1),
        ),
      ));
      await _repo(api).validate(_request(payee: _internalPayee));
      expect(api.calls, ['instruction:validate', 'network:validate']);
    });

    test("a 417 with the bank's challenge asks for the OTP", () async {
      final api = _FakePaymentsApi({
        'statusCode': 417,
        'headers': {
          'X-CHALLENGE': ['{"referenceNo":"CH9","authType":"OTP","attemptsLeft":2}'],
        },
        'body': {},
      });
      final result = await _repo(api).submit(_request(payee: _internalPayee));
      final outcome = (result as Success<TransferSubmitOutcome>).data!;
      expect(outcome.requiresOtp, isTrue);
      expect(outcome.challenge!.referenceNo, 'CH9');
    });

    test('a 201 from a repeat transfer is a success', () async {
      final api = _FakePaymentsApi({
        'statusCode': 201,
        'body': {
          'status': {'result': 'SUCCESSFUL', 'referenceNumber': 'R77'},
          'systemReferenceId': 'S1',
        },
      });
      final result = await _repo(api).submit(_request(
        payee: _internalPayee,
        schedule: RepeatSchedule(
          frequency: TransferFrequency.all.first,
          startDate: DateTime(2026, 11, 1),
          instances: 2,
        ),
      ));
      expect((result as Success<TransferSubmitOutcome>).data!.result!.referenceNumber, 'R77');
    });
  });

  group('the screens', () {
    testWidgets('the Transfers menu: its seven items, web and phone', (tester) async {
      for (final width in [1280.0, 390.0]) {
        await _pump(tester, const TransfersModuleScreen(),
            repository: _FakeRepository(), width: width);
        for (final item in [
          'Transfers - Existing Payee',
          'Transfers - Adhoc Payee',
          'Repeat Transfers - Existing Payee',
          'Repeat Transfers - Adhoc Payee',
          'Other Transfers',
          'International Low Value Payment',
          'Multiple Transfers',
        ]) {
          expect(find.text(item), findsOneWidget, reason: '$item at $width');
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('an existing-payee transfer, through OTP to done', (tester) async {
      final repository = _FakeRepository(needOtp: true);
      await _pump(
        tester,
        const NetworkTransferScreen(mode: NetworkTransferMode.existingPayee),
        repository: repository,
        width: 390,
        height: 2000,
      );
      await _tap(tester, 'Choose a payee');
      await _tap(tester, 'John');
      await _tap(tester, 'Choose an account');
      await _tap(tester, '•••• 1022 · GBP');
      await tester.enterText(find.byType(TextField).first, '250');
      await _tap(tester, 'Continue');

      // The bank validated it; the review shows its charges.
      expect(repository.validated.single.payee!.id, 'P1');
      expect(repository.validated.single.network, 'INTERNAL');
      expect(find.text('Review and confirm'), findsOneWidget);
      // Charges, and the total debit — amount plus charges.
      expect(find.text('GBP 2.50'), findsWidgets);
      expect(find.text('GBP 252.50'), findsWidgets);
      expect(find.text('Total debit'), findsWidgets);

      await _tap(tester, 'Confirm transfer');
      await tester.enterText(find.byType(TextField).last, '1234');
      await _tap(tester, 'Verify');
      expect(repository.submitted, ['SYS1', 'SYS1:1234']);
      expect(find.text('Transfer submitted'), findsOneWidget);
      expect(find.text('REF-SYS1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing details are pointed out', (tester) async {
      await _pump(
        tester,
        const NetworkTransferScreen(mode: NetworkTransferMode.adhocPayee),
        repository: _FakeRepository(),
      );
      await _tap(tester, 'Continue');
      expect(find.text('Enter the account number.'), findsOneWidget);
      expect(find.text('Enter the account name.'), findsOneWidget);
      expect(find.text("Enter the payee's email address."), findsOneWidget);
    });

    testWidgets('adhoc: account numbers must match, the email must be valid', (tester) async {
      await _pump(
        tester,
        const NetworkTransferScreen(mode: NetworkTransferMode.adhocPayee),
        repository: _FakeRepository(),
        height: 1800,
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '0102003456'); // Account Number
      await tester.enterText(fields.at(1), '0102003457'); // Confirm Account Number
      await tester.enterText(fields.at(2), 'Sam Lee'); // Account Name
      await tester.enterText(fields.at(3), 'not-an-email'); // Payee Email Id
      await _tap(tester, 'Continue');
      expect(find.text('Account numbers do not match.'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter the account name.'), findsNothing);
    });

    testWidgets('an adhoc international payee asks for SWIFT and country',
        (tester) async {
      await _pump(
        tester,
        const NetworkTransferScreen(mode: NetworkTransferMode.adhocPayee),
        repository: _FakeRepository(),
        width: 390,
        height: 2200,
      );
      await _tap(tester, 'International');
      expect(find.text('SWIFT / BIC Code'), findsOneWidget);
      expect(find.text('Country *'), findsOneWidget);
      expect(find.text('Correspondence Charges *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a repeat transfer asks for a schedule', (tester) async {
      await _pump(
        tester,
        const NetworkTransferScreen(mode: NetworkTransferMode.repeatExistingPayee),
        repository: _FakeRepository(),
        height: 2000,
      );
      await _tap(tester, 'Choose a payee');
      await _tap(tester, 'John');
      // OBDX's names, under the designer's "Repeat Transfer" section.
      expect(find.text('Repeat Transfer *'), findsOneWidget);
      expect(find.text('Frequency *'), findsOneWidget);
      expect(find.text('Start Date *'), findsOneWidget);
      await _tap(tester, 'Continue');
      expect(find.text('Choose the frequency.'), findsOneWidget);
      expect(find.text('Choose the start date.'), findsOneWidget);
    });

    testWidgets('Low Value Payment: international payees and GPI currencies',
        (tester) async {
      await _pump(
        tester,
        const NetworkTransferScreen(mode: NetworkTransferMode.internationalLowValue),
        repository: _FakeRepository(),
        height: 2000,
      );
      await _tap(tester, 'Choose a payee');
      // Only the international payee is offered.
      expect(find.text('Ana Lopez'), findsOneWidget);
      expect(find.text('John'), findsNothing);
      await _tap(tester, 'Ana Lopez');
      await _tap(tester, 'Choose a currency');
      expect(find.textContaining('Euro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Multiple Transfers: one batch, one OTP for all', (tester) async {
      final repository = _FakeRepository(needOtp: true);
      await _pump(
        tester,
        const MultipleTransfersScreen(),
        repository: repository,
        width: 390,
        height: 2200,
      );
      await _tap(tester, 'Choose an account');
      await _tap(tester, '•••• 1022 · GBP');
      for (var i = 0; i < 2; i++) {
        await _tap(tester, 'Choose a payee');
        await _tap(tester, i == 0 ? 'John' : 'Ana Lopez');
      }
      final amounts = find.byType(TextField);
      await tester.enterText(amounts.at(0), '100');
      await tester.enterText(amounts.at(1), '50');
      await _tap(tester, 'Continue');
      expect(repository.batches, ['validate:2']);
      await _tap(tester, 'Confirm 2 transfers');
      // The bank asks once, for both.
      expect(find.text('Verify 2 transfers'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '1234');
      await _tap(tester, 'Verify');
      expect(repository.batches, ['validate:2', 'submit:2', 'submit:2:1234']);
      expect(find.text('All transfers submitted'), findsOneWidget);
      expect(find.text('REF-SYS1'), findsOneWidget);
      expect(find.text('REF-SYS2'), findsOneWidget);
      expect(repository.submitted, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Transfer hub starts each way to pay', (tester) async {
      final started = <String>[];
      for (final width in [1280.0, 390.0]) {
        started.clear();
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          Scaffold(
            body: TransferTabScreen(
              onTransferTap: (mode, payee) => started.add('${mode.name}:${payee?.id}'),
              onOtherTransfersTap: () => started.add('other'),
              onMultipleTransfersTap: () => started.add('multiple'),
              onPayeeHubTap: () => started.add('payees'),
              onRepeatTransfersTap: () => started.add('repeat'),
            ),
          ),
          repository: _FakeRepository(),
          width: width,
          height: 1600,
        );
        // The payee strip: a saved payee, and "New".
        await _tap(tester, 'John');
        await _tap(tester, 'Adhoc Payee');
        // OBDX's Transfers menu, in its order, then Manage.
        for (final tile in [
          'Transfers - Existing Payee',
          'Transfers - Adhoc Payee',
          'Repeat Transfers - Existing Payee',
          'Repeat Transfers - Adhoc Payee',
          'Other Transfers',
          'International Low Value Payment',
          'Multiple Transfers',
          'Payee',
          'Repeat Transfers Inquiry',
        ]) {
          await _tap(tester, tile);
        }
        expect(started, [
          'existingPayee:P1',
          'adhocPayee:null',
          'existingPayee:null',
          'adhocPayee:null',
          'repeatExistingPayee:null',
          'repeatAdhocPayee:null',
          'other',
          'internationalLowValue:null',
          'multiple',
          'payees',
          'repeat',
        ], reason: 'at $width');
        // Not built yet — shown, but not offered as a way to pay.
        expect(find.text('Payment Status Inquiry'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Payees: pay a saved payee, add each kind', (tester) async {
      final tapped = <String>[];
      for (final width in [1280.0, 390.0]) {
        tapped.clear();
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          PayeeHubScreen(
            embedded: true,
            onBack: () {},
            onPayTap: (p) => tapped.add('pay:${p.id}'),
            onManagePayeesTap: () => tapped.add('manage'),
            onAddAccountPayeeTap: () => tapped.add('account'),
            onAddDraftPayeeTap: () => tapped.add('draft'),
            onAddPeerToPeerPayeeTap: () => tapped.add('p2p'),
          ),
          repository: _FakeRepository(),
          width: width,
          height: 1400,
        );
        expect(find.text('John'), findsOneWidget);
        expect(find.text('Ana Lopez'), findsOneWidget);
        await tester.tap(find.byTooltip('Pay Ana Lopez'));
        await tester.pumpAndSettle();
        await _tap(tester, 'Manage Payees');
        await _tap(tester, 'Add Account Payee');
        await _tap(tester, 'Add Draft Payee');
        await _tap(tester, 'Add Peer To Peer Payee');
        expect(tapped, ['pay:P2', 'manage', 'account', 'draft', 'p2p'], reason: 'at $width');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a payee picked on the hub is already chosen', (tester) async {
      await _pump(
        tester,
        const NetworkTransferScreen(
          mode: NetworkTransferMode.existingPayee,
          initialPayee: _internalPayee,
        ),
        repository: _FakeRepository(),
      );
      expect(find.text('John'), findsWidgets);
      expect(find.text('Choose a payee'), findsNothing);
      // The rest of the form is open straight away.
      expect(find.text('Choose an account'), findsOneWidget);
    });

    testWidgets("the designer's sections: adhoc and existing payee", (tester) async {
      await _pump(
        tester,
        const NetworkTransferScreen(mode: NetworkTransferMode.adhocPayee),
        repository: _FakeRepository(),
        height: 1800,
      );
      for (final label in [
        'Payment Type *',
        'Payee Details *',
        'Account Number *',
        'Confirm Account Number *',
        'Account Name *',
        'Payee Email Id *',
        'Transfer Details *',
        'Credit Account Currency *',
        'Schedule Transfer *',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final chip in ['Internal', 'Domestic', 'International']) {
        expect(find.text(chip), findsOneWidget);
      }
      await _tap(tester, 'Domestic');
      expect(find.text('BIC Code *'), findsOneWidget);

      // A saved payee: chosen from the list — no payment type, no account
      // fields, no credit currency.
      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        const NetworkTransferScreen(mode: NetworkTransferMode.existingPayee),
        repository: _FakeRepository(),
      );
      expect(find.text('Choose a payee'), findsOneWidget);
      expect(find.text('Payment Type *'), findsNothing);
      expect(find.text('Account Number *'), findsNothing);
      expect(find.text('Credit Account Currency *'), findsNothing);
    });

    testWidgets('on a phone the button stays at the bottom', (tester) async {
      await _pump(
        tester,
        const NetworkTransferScreen(mode: NetworkTransferMode.existingPayee),
        repository: _FakeRepository(),
        width: 390,
        height: 844,
      );
      await _tap(tester, 'Choose a payee');
      await _tap(tester, 'John');
      await tester.enterText(find.byType(TextField).first, '250');
      await tester.pumpAndSettle();
      final button = tester.getRect(find.widgetWithText(PayPrimaryButton, 'Continue'));
      expect(button.bottom, greaterThan(844 - 40));
      // The running amount sits above it.
      expect(find.text('Sending GBP 250.00 to John'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("Multiple Transfers: a refused row says why and stays put",
        (tester) async {
      final repository = _FakeRepository(refuseRow: 1);
      await _pump(
        tester,
        const MultipleTransfersScreen(),
        repository: repository,
        width: 1280,
        height: 2200,
      );
      await _tap(tester, 'Choose an account');
      await _tap(tester, '•••• 1022 · GBP');
      for (var i = 0; i < 2; i++) {
        await _tap(tester, 'Choose a payee');
        await _tap(tester, i == 0 ? 'John' : 'Ana Lopez');
      }
      final amounts = find.byType(TextField);
      await tester.enterText(amounts.at(0), '100');
      await tester.enterText(amounts.at(1), '50');
      await _tap(tester, 'Continue');
      expect(find.text('Amount exceeds the daily limit.'), findsOneWidget);
      expect(find.text('Review and confirm'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
