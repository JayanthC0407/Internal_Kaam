import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/retail/certificate_models.dart';
import 'package:ubci_bank/src/core/models/retail/nomination_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/nominations_repository.dart';
import 'package:ubci_bank/src/view/providers/retail/nominations_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/nominations/nominations_screen.dart';

// Shapes follow OBDX nominee components (docs/obdx/features/nominations.md).
// Values are made up.

Map<String, dynamic> _acc(String n, String holding, bool registered) => {
      'id': {'value': 'A$n', 'displayValue': 'xxxx$n'},
      'partyName': 'SAHAM BISWA',
      'holdingPattern': holding,
      'nomineeRegistered': registered,
    };

final _rows = NominationRow.listFromPayload({
  'accounts': [
    _acc('0139', 'SINGLE', false),
    _acc('0240', 'SINGLE', true),
    _acc('0350', 'JOINT', true),
    _acc('0460', 'JOINT', false),
  ],
});

void main() {
  group('model', () {
    test('categories from roles, in role order', () {
      expect(NominationCategory.fromRoles(['TDRole', 'CASARole', 'RDRole', 'CASARole']), [
        NominationCategory.termDeposits,
        NominationCategory.casa,
        NominationCategory.recurringDeposits,
      ]);
    });

    test('action by holding pattern and registration (OBDX actionLabels)', () {
      expect(_rows.map((r) => r.action), [
        NomineeAction.add,
        NomineeAction.viewEdit,
        NomineeAction.view,
        NomineeAction.knowMore,
      ]);
      expect(_rows.first.primaryHolder, 'SAHAM BISWA');
    });

    test('nominee, guardian for a minor, enum descriptions', () {
      final n = Nominee.fromPayload({
        'nomineeDTO': {
          'name': 'Riya',
          'dateOfBirth': '2015-02-01T00:00:00',
          'relation': 'D',
          'minor': true,
          'address': {'line1': '1 Main St', 'city': 'Leeds', 'country': 'GB', 'zipCode': 'LS1'},
          'guardian': {'name': 'Asha', 'address': {'line1': '2 Side St'}},
        },
      })!;
      expect(n.guardianName, 'Asha');
      expect(n.address.lines('United Kingdom'), ['1 Main St', 'Leeds', 'United Kingdom', 'LS1']);
      final relations = nomineeEnumDescriptions({
        'enumRepresentations': [
          {
            'data': [
              {'value': 'D', 'code': 'x', 'description': 'Daughter'},
            ],
          },
        ],
      }, key: 'value');
      expect(relations, {'D': 'Daughter'});
    });
  });

  group('screen', () {
    Future<_FakeRepo> pump(WidgetTester tester, {double width = 390, List<String> roles = const ['CASARole']}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [nominationsRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: NominationsScreen(roles: roles),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('Specific: the chosen account only; Add is not built; Reset', (tester) async {
      await pump(tester);
      expect(find.text('Current & Savings'), findsOneWidget);
      expect(find.text('xxxx0139'), findsOneWidget, reason: 'the first account, picked');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      // Phone card: holding pattern and nominee on one line.
      expect(find.text('Single  •  Not Registered'), findsOneWidget);
      expect(find.text('xxxx0240'), findsNothing, reason: 'Specific Account shows the chosen one only');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Add Nominee · This feature will be available soon.'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Add'), findsNothing);
    });

    testWidgets('All Accounts (web): the table; Know More shows the note', (tester) async {
      await pump(tester, width: 1280);
      await tester.tap(find.text('All Accounts'));
      await tester.pumpAndSettle();
      expect(find.text('Account Number'), findsNothing, reason: 'no account picker for All');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      for (final h in ['Primary Holder Name', 'Holding Pattern', 'Nominee', 'Action']) {
        expect(find.text(h), findsOneWidget, reason: h);
      }
      expect(find.text('View/Edit'), findsOneWidget);
      expect(find.text('Joint'), findsNWidgets(2));
      await tester.tap(find.text('Know More'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Demo Bank branch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('View/Edit: View Nominee with names; Edit / Delete not built; Back', (tester) async {
      final repo = await pump(tester);
      await tester.tap(find.text('All Accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View/Edit'));
      await tester.pumpAndSettle();
      expect(repo.nomineeFor, 'A0240');
      expect(find.text('View Nominee'), findsWidgets);
      expect(find.text('Daughter'), findsOneWidget);
      expect(find.textContaining('United Kingdom'), findsOneWidget);
      expect(find.text('Guardian Details'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete · This feature will be available soon.'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Nominations'), findsWidgets);
    });

    testWidgets('View (joint): no Edit or Delete', (tester) async {
      await pump(tester);
      await tester.tap(find.text('All Accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });
  });
}

class _FakeRepo implements NominationsRepository {
  String? nomineeFor;

  @override
  Future<ResponseHandler<List<CertificateAccount>>> fetchPickerAccounts(NominationCategory c) async =>
      ResponseHandler.success(const [CertificateAccount(id: 'A0139', display: 'xxxx0139')], code: 200);

  @override
  Future<ResponseHandler<List<NominationRow>>> fetchRows(NominationCategory c) async =>
      ResponseHandler.success(_rows, code: 200);

  @override
  Future<ResponseHandler<Nominee>> fetchNominee(String accountId) async {
    nomineeFor = accountId;
    return ResponseHandler.success(
      Nominee.fromPayload({
        'nomineeDTO': {
          'name': 'Riya',
          'dateOfBirth': '2015-02-01T00:00:00',
          'relation': 'D',
          'minor': true,
          'address': {'line1': '1 Main St', 'city': 'Leeds', 'country': 'GB'},
          'guardian': {'name': 'Asha', 'address': {'line1': '2 Side St'}},
        },
      })!,
      code: 200,
    );
  }

  @override
  Future<ResponseHandler<Map<String, String>>> fetchRelations() async =>
      ResponseHandler.success(const {'D': 'Daughter'}, code: 200);

  @override
  Future<ResponseHandler<Map<String, String>>> fetchCountries() async =>
      ResponseHandler.success(const {'GB': 'United Kingdom'}, code: 200);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
