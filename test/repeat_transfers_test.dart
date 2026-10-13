import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/payment/standing_instruction.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_payee_api.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_payments_api.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_accounts_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/network_transfer_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_transfer_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/repeat_transfers_screen.dart';

// ── Shapes of `GET payments/instructions` as OBDX's list reads them ──────

const _activeList = {
  'instructionsList': [
    {
      'externalReferenceNumber': 'SI001',
      'payeeNickName': 'Landlord',
      'amount': {'amount': 800, 'currency': 'GBP'},
      'debitAccountId': {'value': 'ACC1', 'displayValue': 'xxxxxxxxxxxx1022'},
      'startDate': '2026-10-01T00:00:00',
      'endDate': '2027-09-01T00:00:00',
      'nextExecutionDate': '2026-11-01T00:00:00',
      'freqMonths': 1,
      'statusType': 'O',
      'transactionType': 'B',
      'partyId': {'value': '000773'},
      'remarks': 'Rent',
      'maxNoOfRecords': '2',
    },
    {
      'externalReferenceNumber': 'SI002',
      'payeeNickName': 'Ana Lopez',
      'amount': {'amount': 50.5, 'currency': 'GBP'},
      'debitAccountId': {'value': 'ACC1', 'displayValue': 'xxxxxxxxxxxx1022'},
      'startDate': '20261005000000',
      'nextExecutionDate': '20261019000000',
      'freqWeeks': 2,
      'instances': 10,
      'statusType': 'O',
      'transactionType': 'X',
      'partyId': {'value': '000773'},
    },
  ],
};

const _stoppedList = {
  'instructionsList': [
    {
      'externalReferenceNumber': 'SI009',
      'payeeNickName': 'Gym',
      'amount': {'amount': 30, 'currency': 'GBP'},
      'freqMonths': 1,
      'statusType': 'C',
      'maxNoOfRecords': '1',
    },
  ],
};

const _detail = {
  'instructionDetails': {
    'paymentDetailsList': [
      {'valueDate': '2026-10-01T00:00:00', 'status': 'COM'},
      {
        'valueDate': {'dateString': '20260901000000'},
        'status': 'ERR',
        'failureReason': 'Insufficient Balance',
      },
    ],
  },
};

const _challenge = ObdxChallenge(authType: 'OTP', referenceNo: 'CH1', attemptsLeft: 3);

// ── Fakes ────────────────────────────────────────────────────────────────

/// Records the calls the repository makes; answers from [answers] in turn.
class _FakePaymentsApi implements ObdxPaymentsApi {
  _FakePaymentsApi([List<Map<String, dynamic>>? answers]) : answers = answers ?? [];

  final List<Map<String, dynamic>> answers;
  final calls = <String>[];

  Future<ResponseHandler<Map<String, dynamic>>> _next() async =>
      ResponseHandler.success(answers.removeAt(0));

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchInstructions({
    required String status,
    int pageSize = 50,
    int pageNumber = 1,
  }) {
    calls.add('list:$status:$pageSize:$pageNumber');
    return _next();
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchInstruction(String reference, {String? partyId}) {
    calls.add('detail:$reference:$partyId');
    return _next();
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> startInstructionStop(
    String reference,
    Map<String, dynamic> body,
  ) {
    calls.add('POST:$reference:${body['partyId']}');
    return _next();
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> confirmInstructionStop(
    String reference,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) {
    calls.add('PATCH:$reference${challengeResponseHeader == null ? '' : ':otp'}');
    return _next();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Unused implements ObdxPayeeApi, ObdxAccountsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NetworkTransferRepository _repo(_FakePaymentsApi api) =>
    NetworkTransferRepository(paymentsApi: api, payeeApi: _Unused(), accountsApi: _Unused());

/// The screens' repository: lists and history from the fixtures; stopping
/// asks for an OTP first, as the bank may.
class _FakeRepository implements NetworkTransferRepository {
  _FakeRepository({this.active = _activeList});

  final Map<String, dynamic> active;
  final stops = <String>[];
  int lists = 0;

  @override
  Future<ResponseHandler<StandingInstructionPage>> fetchInstructions(String status) async {
    lists++;
    return ResponseHandler.success(
      StandingInstructionPage.fromPayload(status == kInstructionsActive ? active : _stoppedList),
      code: 200,
    );
  }

  @override
  Future<ResponseHandler<StandingInstructionDetail>> fetchInstructionDetail(StandingInstruction i) async =>
      ResponseHandler.success(StandingInstructionDetail.fromPayload(_detail), code: 200);

  @override
  Future<ResponseHandler<InstructionStopOutcome>> stopInstruction(
    StandingInstruction instruction, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    stops.add('${instruction.reference}${otp == null ? '' : ':$otp'}');
    if (otp == null) {
      return ResponseHandler.success(const InstructionStopOutcome.otpRequired(_challenge), code: 417);
    }
    return ResponseHandler.success(const InstructionStopOutcome.stopped(reference: 'R1'), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required _FakeRepository repository,
  double width = 1280,
}) async {
  tester.view.physicalSize = Size(width, 1200);
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

void main() {
  group('reading repeat transfers', () {
    test('an instruction: schedule, status, dates, kind', () {
      final page = StandingInstructionPage.fromPayload(_activeList);
      expect(page.total, 2);
      final rent = page.items.first;
      expect(rent.reference, 'SI001');
      expect(rent.payeeName, 'Landlord');
      expect(rent.amount, 800);
      expect(rent.active, isTrue);
      expect(rent.frequencyLabel, 'Once every month');
      expect(rent.kindLabel, 'Within the bank');
      expect(rent.nextDate, DateTime(2026, 11, 1));
      expect(rent.endDate, DateTime(2027, 9));
      expect(rent.endsByCount, isFalse);
      expect(rent.partyId, '000773');
      expect(rent.debitAccountValue, 'ACC1');

      final ana = page.items.last;
      expect(ana.frequencyLabel, 'Once every 2 weeks');
      // The core's compact dates read too.
      expect(ana.startDate, DateTime(2026, 10, 5));
      expect(ana.endsByCount, isTrue);
      expect(ana.kindLabel, 'International');
    });

    test('a cancelled instruction is not active', () {
      expect(StandingInstructionPage.fromPayload(_stoppedList).items.single.active, isFalse);
    });

    test('payment history: newest first, paid or why not', () {
      final history = StandingInstructionDetail.fromPayload(_detail).history;
      expect(history.first.date, DateTime(2026, 10));
      expect(history.first.completed, isTrue);
      expect(history.last.completed, isFalse);
      expect(history.last.failureReason, 'Insufficient Balance');
    });
  });

  group('the repository', () {
    final instruction = StandingInstructionPage.fromPayload(_activeList).items.first;

    test('lists by status', () async {
      final api = _FakePaymentsApi([
        {'statusCode': 200, 'body': _activeList},
      ]);
      final result = await _repo(api).fetchInstructions(kInstructionsActive);
      expect((result as Success<StandingInstructionPage>).data!.items, hasLength(2));
      expect(api.calls, ['list:ACTIVE:50:1']);
    });

    test('stop: POST then PATCH; the OTP repeats only the PATCH', () async {
      final api = _FakePaymentsApi([
        {'statusCode': 200, 'body': {'status': {'result': 'SUCCESSFUL'}}},
        {
          'statusCode': 417,
          'headers': {
            'X-CHALLENGE': ['{"referenceNo":"CH5","authType":"OTP","attemptsLeft":3}'],
          },
          'body': {},
        },
        {'statusCode': 200, 'body': {'status': {'result': 'SUCCESSFUL', 'referenceNumber': 'R9'}}},
      ]);
      final repository = _repo(api);

      final first = await repository.stopInstruction(instruction);
      final challenge = (first as Success<InstructionStopOutcome>).data!.challenge;
      expect(challenge?.referenceNo, 'CH5');

      final second = await repository.stopInstruction(instruction, challenge: challenge, otp: '1234');
      final done = (second as Success<InstructionStopOutcome>).data!;
      expect(done.reference, 'R9');
      expect(done.pendingApproval, isFalse);
      expect(api.calls, ['POST:SI001:000773', 'PATCH:SI001', 'PATCH:SI001:otp']);
    });

    test('202 means an approver has to agree first', () async {
      final api = _FakePaymentsApi([
        {'statusCode': 200, 'body': {}},
        {'statusCode': 202, 'body': {}},
      ]);
      final result = await _repo(api).stopInstruction(instruction);
      expect((result as Success<InstructionStopOutcome>).data!.pendingApproval, isTrue);
    });

    test('a refused first step stops there', () async {
      final api = _FakePaymentsApi([
        {
          'statusCode': 400,
          'body': {
            'message': {'title': 'Cannot cancel', 'detail': 'Cannot cancel', 'type': 'ERROR'},
          },
        },
      ]);
      final result = await _repo(api).stopInstruction(instruction);
      expect(result, isA<Error<InstructionStopOutcome>>());
      expect(api.calls, ['POST:SI001:000773']);
    });
  });

  group('the screens', () {
    testWidgets('active and stopped, each with its schedule', (tester) async {
      for (final width in [1280.0, 390.0]) {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, const RepeatTransfersScreen(), repository: _FakeRepository(), width: width);
        expect(find.text('Active (2)'), findsOneWidget, reason: 'at $width');
        expect(find.text('Landlord'), findsOneWidget);
        expect(find.textContaining('Once every 2 weeks'), findsOneWidget);

        await tester.tap(find.text('Closed (1)'));
        await tester.pumpAndSettle();
        expect(find.text('Gym'), findsOneWidget);
        expect(find.text('Landlord'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('detail: schedule, history, then stop with OTP', (tester) async {
      for (final width in [1280.0, 390.0]) {
        final repository = _FakeRepository();
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, const RepeatTransfersScreen(), repository: repository, width: width);
        final listsBefore = repository.lists;

        await tester.tap(find.text('Landlord'));
        await tester.pumpAndSettle();
        expect(find.text('View Repeat Transfer'), findsOneWidget);
        expect(find.text('Once every month'), findsWidgets);
        // Next payment — in the detail (and, on web, the list behind it).
        expect(find.text('01 Nov 2026'), findsWidgets);
        expect(find.text('Insufficient Balance'), findsOneWidget);

        await tester.tap(find.text('Stop Repeat Transfer'));
        await tester.pumpAndSettle();
        expect(find.text('Are you sure you want to Stop Repeat Transfer?'), findsOneWidget);
        await tester.tap(find.text('Stop'));
        await tester.pumpAndSettle();

        expect(find.text('Verify to stop this repeat transfer'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '1234');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        expect(repository.stops, ['SI001', 'SI001:1234'], reason: 'at $width');
        expect(find.text('Repeat Transfer to Landlord stopped.'), findsOneWidget);
        // Both lists reload.
        expect(repository.lists, greaterThan(listsBefore));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('"Cancel" stops nothing', (tester) async {
      final repository = _FakeRepository();
      await _pump(tester, const RepeatTransfersScreen(), repository: repository);
      await tester.tap(find.text('Landlord'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop Repeat Transfer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.stops, isEmpty);
      expect(find.text('Stop Repeat Transfer'), findsOneWidget);
    });

    testWidgets('a stopped transfer cannot be stopped again', (tester) async {
      await _pump(tester, const RepeatTransfersScreen(), repository: _FakeRepository());
      await tester.tap(find.text('Closed (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();
      expect(find.text('View Repeat Transfer'), findsOneWidget);
      expect(find.text('Stop Repeat Transfer'), findsNothing);
    });

    testWidgets('none yet: offers to set one up', (tester) async {
      var started = 0;
      await _pump(
        tester,
        RepeatTransfersScreen(onNewTap: () => started++),
        repository: _FakeRepository(active: const {'instructionsList': []}),
      );
      expect(find.text('No repeat transfers yet'), findsOneWidget);
      // The header's button and the empty list's.
      await tester.tap(find.text('New Repeat Transfer').first);
      await tester.tap(find.text('New Repeat Transfer').last);
      expect(started, 2);
    });
  });
}
