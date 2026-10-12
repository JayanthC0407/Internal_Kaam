import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/payee/payee_models.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_payee_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/payee_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/view/providers/common/payee_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payees/payees_screen.dart';

// ── Shapes from OBDX `payeesv3` and `payeeGroup` (values made up) ────────

final _accountPayees = [
  PayeeSummary.fromMap(const {
    'id': 'P1',
    'payeeType': 'INTERNAL',
    'nickName': 'John',
    'name': 'John Carter',
    'accountNumber': '0102003456',
  }),
  PayeeSummary.fromMap(const {
    'id': 'P2',
    'payeeType': 'INTERNATIONAL',
    'nickName': 'Ana Lopez',
    'accountNumber': 'ES9121000418450200051332',
    'bankName': 'Banco Santander',
  }),
];

const _draftGroups = {
  'payeeGroups': [
    {
      'groupId': 'G1',
      'name': 'Rent Draft',
      'listPayees': [
        {
          'id': 'D1',
          'payeeType': 'DEMANDDRAFT',
          'nickName': 'City Housing',
          'demandDraftPayeeType': 'DOM',
          'payAtCity': 'London',
          'demandDraftDeliveryDTO': {'deliveryMode': 'BRN'},
        },
      ],
    },
  ],
};

const _p2pGroups = {
  'payeeGroups': [
    {
      'groupId': 'G2',
      'name': 'Sam',
      'listPayees': [
        {'id': 'Q1', 'nickName': 'Sam', 'transferMode': 'EMAIL', 'transferValue': 'sam@example.com'},
      ],
    },
  ],
};

class _FakePayees extends PayeesNotifier {
  _FakePayees(super.ref);

  static int refreshes = 0;

  @override
  Future<void> ensureLoaded() async => state = PayeesState(payees: _accountPayees);

  @override
  Future<void> refresh() {
    refreshes++;
    return ensureLoaded();
  }
}

/// Answers deletes in turn, recording each path and OTP header.
class _FakePayeeApi implements ObdxPayeeApi {
  _FakePayeeApi(this.answers);

  final List<Map<String, dynamic>> answers;
  final calls = <String>[];

  @override
  Future<ResponseHandler<Map<String, dynamic>>> deletePayee(
    String path, {
    String? challengeResponseHeader,
  }) async {
    calls.add('$path${challengeResponseHeader == null ? '' : ' +otp'}');
    return ResponseHandler.success(answers.removeAt(0));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _otpNeeded = {
  'statusCode': 417,
  'headers': {
    'X-CHALLENGE': ['{"referenceNo":"CH1","authType":"OTP","attemptsLeft":3}'],
  },
  'body': {},
};

const _deleted = {
  'statusCode': 200,
  'body': {
    'status': {'result': 'SUCCESSFUL', 'referenceNumber': 'R1'},
  },
};

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 1280,
  _FakePayeeApi? api,
  Map<String, dynamic> drafts = _draftGroups,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        payeesProvider.overrideWith(_FakePayees.new),
        if (api != null) payeeRepositoryProvider.overrideWithValue(PayeeRepository(payeeApi: api)),
        groupPayeesProvider.overrideWith(
          (ref, type) async => GroupPayee.listFromPayload(
            type == GroupPayee.demandDraft ? drafts : _p2pGroups,
          ),
        ),
      ],
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
  group('GroupPayee (payments/payeeGroup)', () {
    test('a demand-draft payee: draft type, where payable, delivery', () {
      final p = GroupPayee.listFromPayload(_draftGroups).single;
      expect(p.id, 'D1');
      expect(p.groupId, 'G1');
      expect(p.nickname, 'City Housing');
      expect(p.name, 'Rent Draft');
      expect(p.kind, 'Domestic draft');
      expect(p.detail, 'Payable at London · Collect at branch');
    });

    test('a peer-to-peer payee: how and where it is paid', () {
      final p = GroupPayee.listFromPayload(_p2pGroups).single;
      expect(p.nickname, 'Sam');
      expect(p.name, isNull);
      expect(p.kind, 'Email');
      expect(p.detail, 'sam@example.com');
    });

    test('groups without a payee are skipped', () {
      expect(
        GroupPayee.listFromPayload(const {
          'payeeGroups': [
            {'groupId': 'G', 'listPayees': []},
          ],
        }),
        isEmpty,
      );
      expect(GroupPayee.listFromPayload(const {}), isEmpty);
    });
  });

  group('Manage payees', () {
    testWidgets('each kind on its tab; account payees can be paid', (tester) async {
      for (final width in [1280.0, 390.0]) {
        final paid = <String>[];
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          PayeesScreen(embedded: true, onBack: () {}, onPayTap: (p) => paid.add(p.id)),
          width: width,
        );
        expect(find.text('Accounts (2)'), findsOneWidget, reason: 'at $width');
        expect(find.text('John'), findsOneWidget);
        expect(find.text('Ana Lopez'), findsOneWidget);
        await tester.tap(find.byTooltip('Pay John'));
        expect(paid, ['P1']);

        await tester.tap(find.text('Drafts (1)'));
        await tester.pumpAndSettle();
        expect(find.text('City Housing'), findsOneWidget);
        // Drafts can't be paid by a transfer — no "Pay".
        expect(find.byTooltip('Pay City Housing'), findsNothing);

        await tester.tap(find.text('Peer to peer (1)'));
        await tester.pumpAndSettle();
        expect(find.text('Sam'), findsOneWidget);
        expect(find.textContaining('sam@example.com'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('search finds payees by bank, not just nickname', (tester) async {
      await _pump(tester, PayeesScreen(embedded: true, onBack: () {}));
      await tester.enterText(find.byType(TextField), 'santander');
      await tester.pumpAndSettle();
      expect(find.text('Ana Lopez'), findsOneWidget);
      expect(find.text('John'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No payee matches "zzz".'), findsOneWidget);
    });

    testWidgets('Add payee asks which kind, then opens it', (tester) async {
      final added = <AddPayeeFlow>[];
      await _pump(
        tester,
        PayeesScreen(embedded: true, onBack: () {}, onAddPayee: added.add),
      );
      await tester.tap(find.text('Add payee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demand draft'));
      await tester.pumpAndSettle();
      expect(added, [AddPayeeFlow.demandDraft]);
    });
  });

  group('deleting a payee', () {
    test('each type has the path OBDX deletes it on', () {
      String? path(String type, {String? group = 'G1'}) =>
          PayeeDeleteTarget(payeeType: type, payeeId: 'P1', groupId: group).path;
      expect(path('INTERNAL'), 'payeesv3/internal/P1');
      expect(path('INTERNATIONAL'), 'payeesv3/international/P1');
      expect(path('GENERICDOMESTIC'), 'payeesv3/domestic/P1');
      expect(path('DOMESTIC'), 'payeeGroup/G1/payees/domestic/P1');
      expect(path('PEERTOPEER'), 'payeeGroup/G1/payees/peerToPeer/P1');
      expect(path('DEMANDDRAFT'), 'payeeGroup/G1/payees/demandDraft/P1');
      // Group paths need the group; unknown types can't be deleted.
      expect(path('DEMANDDRAFT', group: null), isNull);
      expect(path('SOMETHINGELSE'), isNull);
      expect(GroupPayee.listFromPayload(_draftGroups).single.type, GroupPayee.demandDraft);
      expect(GroupPayee.listFromPayload(_p2pGroups).single.type, GroupPayee.peerToPeer);
    });

    test('the bank asks for an OTP, then deletes', () async {
      final api = _FakePayeeApi([Map.of(_otpNeeded), Map.of(_deleted)]);
      final repository = PayeeRepository(payeeApi: api);
      const target = PayeeDeleteTarget(payeeType: 'INTERNAL', payeeId: 'P1');

      final first = await repository.deletePayee(target);
      final challenge = (first as Success<PayeeDeleteOutcome>).data!.challenge;
      expect(challenge?.referenceNo, 'CH1');

      final second = await repository.deletePayee(target, challenge: challenge, otp: '1234');
      final done = (second as Success<PayeeDeleteOutcome>).data!;
      expect(done.challenge, isNull);
      expect(done.reference, 'R1');
      expect(done.pendingApproval, isFalse);
      expect(api.calls, ['payeesv3/internal/P1', 'payeesv3/internal/P1 +otp']);
    });

    test('202 means an approver has to agree first', () async {
      final api = _FakePayeeApi([
        {'statusCode': 202, 'body': {}},
      ]);
      final result = await PayeeRepository(payeeApi: api).deletePayee(
        const PayeeDeleteTarget(payeeType: 'DEMANDDRAFT', payeeId: 'D1', groupId: 'G1'),
      );
      expect((result as Success<PayeeDeleteOutcome>).data!.pendingApproval, isTrue);
      expect(api.calls, ['payeeGroup/G1/payees/demandDraft/D1']);
    });

    testWidgets('confirm, verify, deleted — and the list refreshes', (tester) async {
      for (final width in [1280.0, 390.0]) {
        _FakePayees.refreshes = 0;
        final api = _FakePayeeApi([Map.of(_otpNeeded), Map.of(_deleted)]);
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, PayeesScreen(embedded: true, onBack: () {}), width: width, api: api);

        await tester.tap(find.byTooltip('More for John'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete payee'));
        await tester.pumpAndSettle();
        expect(find.text('Delete John?'), findsOneWidget);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Verify to delete John'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '1234');
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        expect(api.calls, ['payeesv3/internal/P1', 'payeesv3/internal/P1 +otp'], reason: 'at $width');
        expect(find.text('John deleted.'), findsOneWidget);
        expect(_FakePayees.refreshes, 1);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('cancel sends nothing', (tester) async {
      final api = _FakePayeeApi([]);
      await _pump(tester, PayeesScreen(embedded: true, onBack: () {}), api: api);
      await tester.tap(find.byTooltip('More for Ana Lopez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete payee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
      expect(find.text('Ana Lopez'), findsOneWidget);
    });
  });

  group('the group warning', () {
    const sharedGroup = {
      'payeeGroups': [
        {
          'groupId': 'G9',
          'name': 'Family',
          'listPayees': [
            {'id': 'D1', 'payeeType': 'DEMANDDRAFT', 'nickName': 'Mum', 'demandDraftPayeeType': 'DOM'},
            {'id': 'D2', 'payeeType': 'DEMANDDRAFT', 'nickName': 'Dad', 'demandDraftPayeeType': 'DOM'},
          ],
        },
      ],
    };

    test('a group knows how many payees it holds', () {
      expect(GroupPayee.listFromPayload(sharedGroup).single.groupSize, 2);
      expect(GroupPayee.listFromPayload(_draftGroups).single.groupSize, 1);
    });

    Future<void> openDelete(WidgetTester tester, String name, Map<String, dynamic> drafts) async {
      await _pump(tester, PayeesScreen(embedded: true, onBack: () {}), drafts: drafts, api: _FakePayeeApi([]));
      await tester.tap(find.textContaining('Drafts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More for $name'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete payee'));
      await tester.pumpAndSettle();
    }

    testWidgets('a payee sharing its group is warned about', (tester) async {
      await openDelete(tester, 'Mum', sharedGroup);
      expect(
        find.text('Mum is in the group "Family" with 1 other payee. '
            'The bank may delete the whole group, including that payee.'),
        findsOneWidget,
      );
    });

    testWidgets('a payee alone in its group is not', (tester) async {
      await openDelete(tester, 'City Housing', _draftGroups);
      expect(find.textContaining('whole group'), findsNothing);
      expect(find.text('Delete City Housing?'), findsOneWidget);
    });
  });
}
