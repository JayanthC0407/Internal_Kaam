import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_trade_finance_repository.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_detail_screen.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';

final _lc = CorpLetterOfCredit.fromJson({
  'id': 'IMP001',
  'lcType': 'Import',
  'status': 'ACTIVE',
  'expiryStatus': 'NON_EXPIRED',
  'partyName': 'Contoso Imports',
  'counterPartyName': 'Northwind Exports',
  'productName': 'Import LC Usance',
  'expiryDate': '2027-03-31T00:00:00',
  'amount': {'currency': 'GBP', 'amount': 454566},
  'charges': [],
})!;

class _FakeRepository implements CorpTradeFinanceRepository {
  @override
  Future<ResponseHandler<CorpLetterOfCredit>> fetchLetterOfCredit(
    String id, {
    String? versionNo,
  }) async =>
      ResponseHandler.success(_lc, code: 200);

  @override
  Future<ResponseHandler<LcLookups>> fetchLookups() async =>
      ResponseHandler.success(LcLookups.empty, code: 200);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester, {
  double width = 1100,
  bool canInitiate = true,
  List<String>? pushed,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        corpTradeFinanceRepositoryProvider
            .overrideWithValue(_FakeRepository()),
        lcPermissionsProvider.overrideWithValue(
          LcPermissions(
            viewImport: true,
            viewExport: true,
            initiate: canInitiate,
            amend: true,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          pushed?.add(settings.name!);
          return MaterialPageRoute(builder: (_) => const SizedBox());
        },
        // A page underneath, so Back has somewhere to go.
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LcDetailScreen(
                      args: LcDetailArgs(
                        lcId: 'IMP001',
                        lcType: LcType.importLc,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('the import LC detail bottom bar', () {
    testWidgets('Copy & Initiate and Back, as on OBDX', (tester) async {
      await _pump(tester);
      expect(find.text('Copy & Initiate'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Amend LC'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Copy & Initiate opens Initiate LC', (tester) async {
      final pushed = <String>[];
      await _pump(tester, pushed: pushed);
      await tester.tap(find.text('Copy & Initiate'));
      await tester.pumpAndSettle();
      expect(pushed, contains(CorpRoutesConst.lcInitiateScreen));
    });

    testWidgets('Back closes the detail', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(LcDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('without initiate permission, only Back', (tester) async {
      await _pump(tester, canInitiate: false);
      expect(find.text('Copy & Initiate'), findsNothing);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('fits a phone', (tester) async {
      await _pump(tester, width: 390);
      expect(find.text('Copy & Initiate'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
