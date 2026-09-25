import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_grid_span.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_card_surface.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_tile_grid.dart';

List<List<int>> _spans(List<int> input) => [
      for (final row in DashboardGridSpan.packRows(input))
        [for (final cell in row) cell.span],
    ];

List<List<int>> _indices(List<int> input) => [
      for (final row in DashboardGridSpan.packRows(input))
        [for (final cell in row) cell.index],
    ];

void main() {
  group('DashboardGridSpan.resolve', () {
    test('the app size comes first', () {
      expect(
        DashboardGridSpan.resolve(
          preferred: 4,
          catalogWidth: '8',
          style: 'oj-lg-12',
          fallback: 6,
        ),
        4,
      );
    });

    test('then the catalog, then the saved style, then the fallback', () {
      expect(
        DashboardGridSpan.resolve(
          catalogWidth: '8',
          style: 'oj-lg-12',
          fallback: 6,
        ),
        8,
      );
      expect(DashboardGridSpan.resolve(style: 'oj-lg-3', fallback: 6), 3);
      expect(DashboardGridSpan.resolve(fallback: 6), 6);
    });

    test('a size the user chose beats the app size', () {
      expect(
        DashboardGridSpan.resolve(
          preferred: 6,
          style: 'oj-lg-12 user-sized',
          fallback: 4,
        ),
        12,
      );
    });

    test('but an unmarked saved size still does not', () {
      // What earlier builds wrote for everything they could not size.
      expect(
        DashboardGridSpan.resolve(
          preferred: 6,
          style: 'oj-lg-12',
          fallback: 4,
        ),
        6,
      );
    });

    test('ignores out-of-range values', () {
      expect(
        DashboardGridSpan.resolve(preferred: 13, catalogWidth: '', fallback: 6),
        6,
      );
    });
  });

  group('DashboardGridSpan.withSpan', () {
    test('writes a class where there was none', () {
      expect(DashboardGridSpan.withSpan(null, 'oj-lg', 4), 'oj-lg-4');
    });

    test('replaces only this breakpoint\'s class', () {
      expect(
        DashboardGridSpan.withSpan('oj-sm-12 oj-lg-12 extra', 'oj-lg', 4),
        'oj-sm-12 oj-lg-4 extra',
      );
    });

    test('a re-save keeps a user-chosen size marked', () {
      expect(
        DashboardGridSpan.withSpan('oj-lg-12 user-sized', 'oj-lg', 12),
        'oj-lg-12 user-sized',
      );
    });
    test('appends when this breakpoint has no class yet', () {
      expect(
        DashboardGridSpan.withSpan('oj-sm-12', 'oj-md', 6),
        'oj-sm-12 oj-md-6',
      );
    });
  });

  group('DashboardGridSpan.packRows', () {
    test('fills rows in order', () {
      expect(_spans([8, 4, 4, 4, 4]), [
        [8, 4],
        [4, 4, 4],
      ]);
    });

    test('never reorders to fill a gap', () {
      // [4, 12, 4] must not become [4, 4] + [12]: order is the user's.
      expect(_indices([4, 12, 4]), [
        [0],
        [1],
        [2],
      ]);
    });

    test('widens a short row so it ends without a hole', () {
      expect(_spans([4, 4]), [
        [6, 6],
      ]);
      expect(_spans([8, 8]), [
        [12],
        [12],
      ]);
      expect(_spans([6, 4]), [
        [8, 4],
      ]);
    });

    test('every row is exactly full', () {
      for (final input in [
        [4, 8, 4, 4, 6],
        [3, 3, 3],
        [5, 5, 5, 5],
        [12, 1],
      ]) {
        for (final row in _spans(input)) {
          expect(row.fold<int>(0, (a, b) => a + b), 12, reason: '$input');
        }
      }
    });
  });

  group('DashboardTileGrid', () {
    Future<void> pumpGrid(WidgetTester tester, List<DashboardTile> tiles) {
      tester.view.physicalSize = const Size(1240, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 1240,
                child: DashboardTileGrid(tiles: tiles, gap: 20),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('tiles sit side by side, all as tall as the tallest',
        (tester) async {
      await pumpGrid(tester, const [
        DashboardTile(
          span: 8,
          framed: false,
          child: SizedBox(key: Key('a'), height: 80),
        ),
        DashboardTile(
          span: 4,
          framed: false,
          child: SizedBox(key: Key('b'), height: 300),
        ),
      ]);

      final a = tester.getRect(find.byKey(const Key('a')));
      final b = tester.getRect(find.byKey(const Key('b')));
      // Same row...
      expect(a.top, b.top);
      expect(a.right, lessThan(b.left));
      // ...and the short one is stretched to the tall one's height.
      expect(a.height, b.height);
      // 8 : 4 columns.
      expect(a.width / b.width, closeTo(2.0, 0.1));
    });

    testWidgets('the tiles of a full row reach exactly the edge',
        (tester) async {
      await pumpGrid(tester, const [
        DashboardTile(
          span: 4,
          framed: false,
          child: SizedBox(key: Key('a'), height: 10),
        ),
        DashboardTile(
          span: 4,
          framed: false,
          child: SizedBox(key: Key('b'), height: 10),
        ),
        DashboardTile(
          span: 4,
          framed: false,
          child: SizedBox(key: Key('c'), height: 10),
        ),
      ]);

      // Three 4s fit one row — no rounding pushes the third onto a new one.
      final a = tester.getRect(find.byKey(const Key('a')));
      final c = tester.getRect(find.byKey(const Key('c')));
      expect(c.top, a.top);
      expect(c.right, closeTo(1240, 0.01));
    });

    testWidgets('a lone narrow tile widens to fill its row', (tester) async {
      await pumpGrid(tester, const [
        DashboardTile(
          span: 4,
          framed: false,
          child: SizedBox(key: Key('a'), height: 10),
        ),
      ]);

      expect(tester.getRect(find.byKey(const Key('a'))).width, 1240);
    });

    testWidgets('a tile whose content grows later grows its row',
        (tester) async {
      // Regression: tiles laid out at a tight height became relayout
      // boundaries, so content that grew afterwards — the accounts card
      // once its data arrived — overflowed instead of growing the row.
      final grow = ValueNotifier<double>(60);
      addTearDown(grow.dispose);

      await pumpGrid(tester, [
        DashboardTile(
          span: 6,
          child: ValueListenableBuilder<double>(
            valueListenable: grow,
            builder: (_, height, __) => Column(
              children: [SizedBox(key: const Key('grows'), height: height)],
            ),
          ),
        ),
        const DashboardTile(
          span: 6,
          framed: false,
          child: SizedBox(key: Key('neighbour'), height: 40),
        ),
      ]);

      grow.value = 400;
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('grows'))).height,
        400,
      );
      // The neighbour follows it down.
      expect(
        tester.getSize(find.byKey(const Key('neighbour'))).height,
        greaterThanOrEqualTo(400),
      );
    });

    testWidgets('lays out widgets that do not support intrinsic sizing',
        (tester) async {
      // A LayoutBuilder or a GridView inside would throw under
      // IntrinsicHeight; the row lays out for real instead.
      await pumpGrid(tester, [
        DashboardTile(
          span: 6,
          child: LayoutBuilder(
            builder: (context, constraints) => const SizedBox(height: 120),
          ),
        ),
        DashboardTile(
          span: 6,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: const [Text('1'), Text('2'), Text('3')],
          ),
        ),
      ]);

      expect(tester.takeException(), isNull);
    });

    testWidgets('a widget\'s own card steps aside inside a tile',
        (tester) async {
      const ownCard = BoxDecoration(color: Color(0xFFFF0000));

      await pumpGrid(tester, const [
        DashboardTile(
          span: 12,
          child: DashboardCardSurface(
            decoration: ownCard,
            child: SizedBox(key: Key('inside'), height: 40),
          ),
        ),
      ]);

      // Only the tile's shared card is drawn — no card inside a card.
      final decorated = tester.widgetList<Container>(find.byType(Container));
      expect(decorated.where((c) => c.decoration == ownCard), isEmpty);
    });

    testWidgets('and keeps its own card outside a tile', (tester) async {
      const ownCard = BoxDecoration(color: Color(0xFFFF0000));

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardCardSurface(
            decoration: ownCard,
            child: SizedBox(height: 40),
          ),
        ),
      );

      final decorated = tester.widgetList<Container>(find.byType(Container));
      expect(decorated.where((c) => c.decoration == ownCard), hasLength(1));
    });

    Future<void> pumpColumns(
      WidgetTester tester,
      List<DashboardTile> tiles, {
      double width = 1240,
    }) {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardTileGrid(
                tiles: tiles,
                layout: DashboardGridLayout.twoColumns,
                collapseBelow: 920,
              ),
            ),
          ),
        ),
      );
    }

    DashboardTile box(String key, double height) => DashboardTile(
          span: 6,
          framed: false,
          child: SizedBox(key: Key(key), height: height),
        );

    testWidgets('two columns place tiles left, right, left, …', (tester) async {
      // The fixed Retail home: accounts | spendings, then loan tracker
      // under accounts, transactions under spendings.
      await pumpColumns(tester, [
        box('accounts', 460),
        box('spendings', 460),
        box('loans', 270),
        box('transactions', 600),
        box('quick', 300),
      ]);

      Rect rect(String key) => tester.getRect(find.byKey(Key(key)));
      expect(rect('accounts').left, rect('loans').left);
      expect(rect('loans').left, rect('quick').left);
      expect(rect('spendings').left, rect('transactions').left);
      expect(rect('spendings').left, greaterThan(rect('accounts').right));
    });

    testWidgets('each column stacks at its own pace — nothing is stretched',
        (tester) async {
      await pumpColumns(tester, [
        box('accounts', 460),
        box('spendings', 460),
        box('loans', 270),
        box('transactions', 600),
        box('quick', 300),
      ]);

      Rect rect(String key) => tester.getRect(find.byKey(Key(key)));
      // The short loan tracker keeps its height, rather than being pulled
      // to the transactions list's...
      expect(rect('loans').height, 270);
      // ...and the next tile on the left starts right below it.
      expect(rect('quick').top, rect('loans').bottom + 20);
    });

    testWidgets('a full-width tile spans both columns and splits them',
        (tester) async {
      // Corporate's Account Summary table, between half-width widgets.
      await pumpColumns(tester, [
        box('accounts', 300),
        box('quick', 200),
        box('finance', 150),
        const DashboardTile(
          span: 12,
          framed: false,
          child: SizedBox(key: Key('summary'), height: 100),
        ),
        box('currency', 120),
        box('pickup', 120),
      ]);

      Rect rect(String key) => tester.getRect(find.byKey(Key(key)));
      final summary = rect('summary');
      // Across the whole width...
      expect(summary.left, rect('accounts').left);
      expect(summary.right, rect('quick').right);
      // ...below both columns of what came before it, however uneven.
      expect(summary.top, greaterThan(rect('finance').bottom));
      expect(summary.top, greaterThan(rect('quick').bottom));
      // Two columns resume after it, starting on the left again.
      expect(rect('currency').top, greaterThan(summary.bottom));
      expect(rect('currency').left, rect('accounts').left);
      expect(rect('pickup').left, rect('quick').left);
      expect(rect('pickup').top, rect('currency').top);
    });

    testWidgets('below the collapse width, one column', (tester) async {
      await pumpColumns(
        tester,
        [box('a', 50), box('b', 50)],
        width: 800,
      );

      Rect rect(String key) => tester.getRect(find.byKey(Key(key)));
      expect(rect('a').width, 800);
      expect(rect('b').top, greaterThan(rect('a').bottom));
    });

    testWidgets('frames tiles in the grid\'s card style', (tester) async {
      const retailCard = BoxDecoration(color: Color(0xFF00FF00));
      tester.view.physicalSize = const Size(1240, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardTileGrid(
              tileDecoration: (_) => retailCard,
              tiles: const [DashboardTile(span: 12, child: SizedBox())],
            ),
          ),
        ),
      );

      final decorated = tester.widgetList<Container>(find.byType(Container));
      expect(decorated.where((c) => c.decoration == retailCard), hasLength(1));
    });

    Future<void> holdAndDrag(
        WidgetTester tester, Finder from, Finder to) async {
      // Measured before the drag starts: while it is under way the tile is
      // drawn faded in its place, which a finder would also match.
      final start = tester.getCenter(from);
      final end = tester.getCenter(to);
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(start, end, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('holding a tile and dropping it on another moves it',
        (tester) async {
      final moves = <List<String>>[];
      tester.view.physicalSize = const Size(1240, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DashboardTileGrid(
              layout: DashboardGridLayout.twoColumns,
              onMove: (dragged, target) => moves.add([dragged, target]),
              tiles: const [
                DashboardTile(
                  span: 6,
                  dragId: 'a',
                  child: SizedBox(key: Key('a'), height: 120),
                ),
                DashboardTile(
                  span: 6,
                  dragId: 'b',
                  child: SizedBox(key: Key('b'), height: 120),
                ),
                DashboardTile(
                  span: 6,
                  child: SizedBox(key: Key('pinned'), height: 120),
                ),
              ],
            ),
          ),
        ),
      );

      await holdAndDrag(
        tester,
        find.byKey(const Key('a')),
        find.byKey(const Key('b')),
      );
      expect(moves, [
        ['a', 'b'],
      ]);

      // A tile without an id — pinned content — is not a place to drop.
      await holdAndDrag(
        tester,
        find.byKey(const Key('a')),
        find.byKey(const Key('pinned')),
      );
      expect(moves, hasLength(1));
    });

    testWidgets('dragging near the bottom edge scrolls the dashboard',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: DashboardTileGrid(
                onMove: (_, __) {},
                tiles: [
                  for (var i = 0; i < 8; i++)
                    DashboardTile(
                      span: 12,
                      framed: false,
                      dragId: 't$i',
                      // Painted, so a press on it lands on something.
                      child: ColoredBox(
                        color: const Color(0xFFEEEEEE),
                        child: SizedBox(key: Key('t$i'), height: 250),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(controller.offset, 0);

      final start = tester.getCenter(find.byKey(const Key('t0')));
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // Down to the bottom edge, and hold there.
      for (var i = 1; i <= 10; i++) {
        await gesture
            .moveTo(Offset(start.dx, start.dy + (590 - start.dy) * i / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(controller.offset, greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a quick tap is not a drag', (tester) async {
      final moves = <List<String>>[];
      var tapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardTileGrid(
              onMove: (dragged, target) => moves.add([dragged, target]),
              tiles: [
                DashboardTile(
                  span: 6,
                  dragId: 'a',
                  child: TextButton(
                    onPressed: () => tapped++,
                    child: const Text('open'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The widget's own buttons keep working.
      expect(tapped, 1);
      expect(moves, isEmpty);
    });

    testWidgets('draws a title for a widget that has none', (tester) async {
      await pumpGrid(tester, const [
        DashboardTile(
          span: 12,
          title: 'My Accounts',
          child: SizedBox(height: 40),
        ),
      ]);

      expect(find.text('My Accounts'), findsOneWidget);
    });
  });
}
