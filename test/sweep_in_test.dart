import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/retail/sweep_in_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_sweep_in_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/sweep_in_repository.dart';
import 'package:ubci_bank/src/view/providers/retail/sweep_in_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/sweep_in_screen.dart';

// Shapes follow the OBDX sweep-in-instruction flow
// (docs/obdx/features/sweep-in.md). Values are made up.

SweepAccount _acc(String n, {String? product, String type = 'CSA'}) => SweepAccount(
      id: 'A$n',
      display: 'xxxx$n',
      partyName: 'SAHAM BISWA',
      balance: const MoneyAmount(amount: 10, currency: 'GBP'),
      type: type,
      productId: product,
    );

final _main = _acc('0139');
final _linked = _acc('0240');
final _free = _acc('0350');
final _wallet = _acc('0460', product: 'WALLET');
final _casa = [_main, _linked, _free, _wallet];
const _instructions = [
  SweepInstruction(instructionNumber: 'IN1', providerId: 'A0240'),
  SweepInstruction(instructionNumber: 'IN2', providerId: 'A0240'),
];

Map<String, dynamic> _batch(List<(int, Map<String, dynamic>)> parts) => {
      'batchDetailResponseDTOList': [
        for (final (i, (status, body)) in parts.indexed)
          {'sequenceId': '${i + 1}', 'status': status, 'responseText': jsonEncode(body)},
      ],
    };

void main() {
  group('model', () {
    test('lists: linked = providers of the instructions; link = the rest, no self, no wallet', () {
      final lists = SweepLists.build(type: SweepType.casa, selectedId: 'A0139', instructions: _instructions, accounts: _casa);
      expect(lists.linked.map((l) => l.account.id), ['A0240']);
      expect(lists.linked.single.instructionNumber, 'IN1', reason: "OBDX deletes the provider's first instruction");
      expect(lists.providers.map((a) => a.id), ['A0350']);
      expect(lists.notices, isEmpty);
    });

    test('lists: OBDX notices', () {
      final one = SweepLists.build(type: SweepType.casa, selectedId: 'A0139', instructions: const [], accounts: [_main]);
      expect(one.notices, [SweepNotice.noCasaAccounts, SweepNotice.allLinked]);
      final noTd = SweepLists.build(type: SweepType.td, selectedId: 'A0139', instructions: const [], accounts: const []);
      expect(noTd.notices, [SweepNotice.noDeposits, SweepNotice.allLinked]);
    });

    test('batch parts: POST sweepInInstructions on digx-common/dda with OBDX body', () {
      final items = sweepLinkItems('A0139', [_free]);
      final text = ObdxBatchEncoder.encode(items, 'B');
      expect(text, contains('Application-Id: digx-common/dda'));
      expect(text, contains('POST /demandDeposit/A0139/sweepInInstructions HTTP/1.1'));
      expect(text, contains('{"providerAccountId":{"value":"A0350"},"providerAccountType":"CSA"}'));
    });

    test('result rows: Completed by externalReferenceId; failure reason when not 201', () {
      final rows = SweepResultRow.listFrom(
        _batch([
          (201, {'externalReferenceId': 'REF1'}),
          (400, {'message': {'detail': 'Provider not allowed'}}),
          (200, {'externalReferenceId': 'REF3'}),
        ]),
        [_free, _linked, _main],
      );
      expect(rows.map((r) => r.completed), [true, false, true]);
      expect(rows.map((r) => r.reference), ['REF1', '-', 'REF3']);
      expect(rows[1].failureReason, 'Provider not allowed');
      expect(rows[2].failed, isTrue, reason: 'OBDX: any status other than 201');
      expect(const SweepLinkOutcome.done().anyFailed, isFalse);
    });
  });

  group('repository (OBDX framework behaviour)', () {
    test('link: 417 → OTP; 200 → rows; delink: externalReferenceId, 202 pending', () async {
      final otp = await SweepInRepository(
        api: _FakeApi(_wrapped(417, const {}, headers: {
          'x-challenge': [jsonEncode({'referenceNo': 'OTP1', 'authType': 'OTP'})],
        })),
      ).link('A0139', [_free]);
      expect((otp as Success<SweepLinkOutcome>).data!.challenge?.referenceNo, 'OTP1');

      final api = _FakeApi(_wrapped(200, _batch([(201, {'externalReferenceId': 'REF1'})])));
      final done = await SweepInRepository(api: api).link('A0139', [_free]);
      expect((done as Success<SweepLinkOutcome>).data!.rows.single.reference, 'REF1');
      expect(api.items!.single.uri, '/demandDeposit/A0139/sweepInInstructions');

      final delink = await SweepInRepository(api: _FakeApi(_wrapped(200, {'externalReferenceId': 'DEL1'})))
          .delink('A0139', 'IN1');
      expect((delink as Success<SweepDelinkOutcome>).data!.reference, 'DEL1');
      final pending = await SweepInRepository(api: _FakeApi(_wrapped(202, {'status': {'result': 'SUCCESSFUL'}})))
          .delink('A0139', 'IN1');
      expect((pending as Success<SweepDelinkOutcome>).data!.pendingApproval, isTrue);
    });
  });

  group('screen', () {
    Future<_FakeRepo> pump(WidgetTester tester, {double width = 390}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sweepInRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: Scaffold(body: SweepInScreen(onExit: () {}, onHome: () => repo.home = true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('link: tick, Review (New), Confirm, status from Click Here (phone)', (tester) async {
      final repo = await pump(tester);
      expect(find.text('Linked Accounts'), findsOneWidget);
      expect(find.text('Link Accounts'), findsOneWidget);
      expect(find.text('xxxx0240'), findsOneWidget);
      expect(find.text('xxxx0460'), findsNothing, reason: 'wallet');

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Please select at least one account for linking.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Current and Savings'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repo.linked, ['A0350']);
      expect(find.text('Sweep-In Request Submitted successfully.'), findsOneWidget);
      await tester.tap(find.text('Click Here'));
      await tester.pumpAndSettle();
      expect(find.text('REF1'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      expect(repo.home, isTrue);
    });

    testWidgets('delete: confirm, delink result, Manage Sweep-In', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to delink this account?'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repo.delinked, 'IN1');
      expect(find.text('Your request has been accepted.'), findsOneWidget);
      expect(find.text('DEL1'), findsOneWidget);
      await tester.tap(find.text('Manage Sweep-In'));
      await tester.pumpAndSettle();
      expect(find.text('Link Accounts'), findsOneWidget);
    });

    testWidgets('Term Deposit (web): deposits wording, no balance, OBDX notice', (tester) async {
      await pump(tester, width: 1280);
      expect(find.text('Select'), findsOneWidget, reason: 'table header on web');
      expect(find.text('Balance'), findsOneWidget);
      await tester.tap(find.text('Term Deposit'));
      await tester.pumpAndSettle();
      expect(find.text('Linked Deposits'), findsOneWidget);
      expect(find.text('No linked deposits to display.'), findsOneWidget);
      expect(find.textContaining('You need to have at least one Term Deposit'), findsOneWidget);
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

class _FakeApi implements ObdxSweepInApi {
  _FakeApi(this.response);

  final ResponseHandler<Map<String, dynamic>> response;
  List<ObdxBatchItem>? items;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> linkProviders(
    List<ObdxBatchItem> items, {
    String? challengeResponseHeader,
    String? boundary,
  }) async {
    this.items = items;
    return response;
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> deleteInstruction(
    String accountId,
    String instructionNumber, {
    String? challengeResponseHeader,
  }) async =>
      response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements SweepInRepository {
  List<String>? linked;
  String? delinked;
  bool home = false;

  @override
  Future<ResponseHandler<List<SweepAccount>>> fetchPickerAccounts() async =>
      ResponseHandler.success([_main, _linked], code: 200);

  @override
  Future<ResponseHandler<SweepLists>> fetchLists(String accountId, SweepType type) async => ResponseHandler.success(
        SweepLists.build(
          type: type,
          selectedId: accountId,
          instructions: type == SweepType.casa ? _instructions : const [],
          accounts: type == SweepType.casa ? _casa : const [],
        ),
        code: 200,
      );

  @override
  Future<ResponseHandler<SweepLinkOutcome>> link(
    String accountId,
    List<SweepAccount> providers, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    linked = [for (final p in providers) p.id];
    return ResponseHandler.success(
      SweepLinkOutcome.done(rows: SweepResultRow.listFrom(_batch([(201, {'externalReferenceId': 'REF1'})]), providers)),
      code: 200,
    );
  }

  @override
  Future<ResponseHandler<SweepDelinkOutcome>> delink(
    String accountId,
    String instructionNumber, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    delinked = instructionNumber;
    return ResponseHandler.success(const SweepDelinkOutcome.done(reference: 'DEL1'), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
