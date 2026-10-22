import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/bill_payments_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/billers_screen.dart';

// Made-up data; shapes follow docs/obdx/features/bill-payments.md §3.5.

RegisteredBiller _biller(
  String id,
  String nickname,
  String type, {
  bool autopay = false,
  Map<String, dynamic>? ebill,
}) =>
    RegisteredBiller.fromJson({
      'id': id,
      'billerId': 'B$id',
      'billerName': 'Power Co $id',
      'billerNickName': nickname,
      'billerType': type,
      'customerName': 'Test Customer',
      'registrationStatus': 'APPROVED',
      'autopay': autopay,
      'category': {'id': 'C', 'name': 'Electricity'},
      'relationshipDetails': [
        {'labelId': 'CONSUMER_NO', 'value': '998877'},
      ],
      if (ebill != null) 'ebill': ebill,
      'biller': {
        'id': 'B$id',
        'name': 'Power Co $id',
        'currency': 'GBP',
        'specifications': [
          {'id': 'CONSUMER_NO', 'label': 'Consumer Number'},
        ],
      },
    })!;

class _FakeRepo implements BillPaymentsRepository {
  _FakeRepo(this.billers);

  final List<RegisteredBiller> billers;
  int deletes = 0;

  @override
  Future<ResponseHandler<List<RegisteredBiller>>> fetchRegisteredBillers() async =>
      ResponseHandler.success(billers, code: 200);

  @override
  Future<ResponseHandler<RegisteredBiller>> fetchRegisteredBiller(String id) async =>
      ResponseHandler.success(billers.firstWhere((b) => b.id == id), code: 200);

  @override
  Future<ResponseHandler<BillerDeleteOutcome>> deleteRegisteredBiller(
    String id, {
    Map<String, dynamic>? body,
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    deletes++;
    return ResponseHandler.success(const BillerDeleteOutcome.deleted(), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepo> _pump(WidgetTester tester, {double width = 390}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeRepo([
    _biller('1', 'Home power', 'PRESENTMENT', autopay: true, ebill: {
      'dueDate': '2099-01-10T00:00:00',
      'totalAmount': {'currency': 'GBP', 'amount': 42},
    }),
    _biller('2', 'Mobile', 'RECHARGE'),
    _biller('3', 'Water', 'PAYMENT'),
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

void main() {
  testWidgets('phone: OBDX groups, labels and badges', (tester) async {
    await _pump(tester);
    expect(find.text('Billers'), findsWidgets);
    expect(find.text('Bills Presented'), findsOneWidget);
    expect(find.text('Recharge Bill Payment'), findsOneWidget);
    expect(find.text('Direct Bill Payment'), findsOneWidget);
    expect(find.text('Auto Pay'), findsOneWidget);
    expect(find.text('Bills Due'), findsOneWidget);
    expect(find.textContaining('GBP 42.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search keeps only matching groups', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'wat');
    await tester.pumpAndSettle();
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Home power'), findsNothing);
    expect(find.text('Bills Presented'), findsNothing);
  });

  testWidgets('delete is blocked while auto pay is on (OBDX rule)', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Biller').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Please close the auto pay/scheduled pay currently set up for this biller before deleting.'),
      findsOneWidget,
    );
    expect(repo.deletes, 0);
  });

  testWidgets('delete asks first, then deletes', (tester) async {
    final repo = await _pump(tester);
    // "Water" is the third row (Direct Bill Payment).
    await tester.tap(find.byIcon(Icons.more_vert_rounded).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Biller').last);
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to delete this biller?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 1);
    expect(find.text('Water deleted.'), findsOneWidget);
  });

  testWidgets('web: Biller Details names relationship fields by specification', (tester) async {
    await _pump(tester, width: 1280);
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();
    expect(find.text('Biller Details'), findsWidgets);
    expect(find.text('Consumer Number'), findsOneWidget);
    expect(find.text('998877'), findsOneWidget);
    expect(find.text('Direct Bill Payment'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
