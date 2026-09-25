import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations_en.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/view/screens/common/navigation/dashboard_navigation.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_nav_content.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/retail_nav.dart';

const _items = [
  DashboardNavItem(id: 'home', label: 'Home', icon: Icons.home_rounded),
  DashboardNavItem(
    id: 'accounts',
    label: 'Accounts',
    icon: Icons.account_balance_outlined,
    children: [
      DashboardNavItem(
        id: 'accounts.casa',
        label: 'CASA',
        icon: Icons.account_balance_wallet_outlined,
      ),
      DashboardNavItem(
        id: 'accounts.loans',
        label: 'Loans',
        icon: Icons.request_quote_outlined,
      ),
    ],
  ),
  DashboardNavItem(id: 'more', label: 'More', icon: Icons.more_horiz_rounded),
];

Future<List<String>> _pumpSidebar(
  WidgetTester tester, {
  String? selectedId = 'home',
}) async {
  final selected = <String>[];
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Row(
          children: [
            DashboardNavigationSidebar(
              items: _items,
              selectedId: selectedId,
              onSelected: selected.add,
              footer: const DashboardNavFooter(
                label: 'Security',
                icon: Icons.lock_outline_rounded,
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return selected;
}

void main() {
  group('DashboardNavigationSidebar', () {
    testWidgets('choosing an item reports its id', (tester) async {
      final selected = await _pumpSidebar(tester);

      await tester.tap(find.text('More'));
      expect(selected, ['more']);
      expect(find.text('Security'), findsOneWidget);
    });

    testWidgets('a group opens and closes instead of being selected',
        (tester) async {
      final selected = await _pumpSidebar(tester);
      expect(find.text('CASA'), findsNothing);

      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();
      expect(find.text('CASA'), findsOneWidget);
      expect(selected, isEmpty);

      await tester.tap(find.text('Loans'));
      expect(selected, ['accounts.loans']);

      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();
      expect(find.text('CASA'), findsNothing);
    });

    testWidgets('a selected sub-item keeps its group open', (tester) async {
      await _pumpSidebar(tester, selectedId: 'accounts.casa');

      expect(find.text('CASA'), findsOneWidget);
    });

    testWidgets(
        'collapsed, it is an icon rail, and a group goes to its '
        'first entry', (tester) async {
      final selected = await _pumpSidebar(tester);

      await tester.tap(find.byTooltip('Collapse menu'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing);
      expect(find.byTooltip('Expand menu'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.account_balance_outlined));
      expect(selected, ['accounts.casa']);
    });
  });

  testWidgets('DashboardNavDrawer closes before reporting the choice',
      (tester) async {
    final selected = <String>[];
    final scaffold = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          key: scaffold,
          drawer: DashboardNavDrawer(
            items: _items,
            selectedId: 'home',
            onSelected: selected.add,
          ),
          body: const SizedBox(),
        ),
      ),
    );
    scaffold.currentState!.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(selected, ['more']);
    expect(scaffold.currentState!.isDrawerOpen, isFalse);
  });

  group('each user type brings its own entries', () {
    test('Retail', () {
      final ids = [
        for (final item in RetailNav.items(AppLocalizationsEn())) item.id,
      ];
      expect(ids, [
        RetailNav.home,
        RetailNav.insights,
        RetailNav.transfer,
        RetailNav.rewards,
        RetailNav.accounts,
        RetailNav.more,
      ]);
    });

    test('Corporate — every destination, Home first, ids round-trip', () {
      final items = CorpNavDestination.navItems;
      expect(items, hasLength(CorpNavDestination.values.length));
      expect(items.first.id, CorpNavDestination.home.name);
      for (final item in items) {
        expect(CorpNavDestination.fromNavId(item.id)?.name, item.id);
      }
      // Retail's groups are Retail's.
      expect(items.any((item) => item.isGroup), isFalse);
    });
  });
}
