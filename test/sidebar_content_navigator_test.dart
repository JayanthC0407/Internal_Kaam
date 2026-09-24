import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/widgets/sidebar_content_navigator.dart';

/// A dashboard in miniature: a sidebar, and the content area beside it.
class _Shell extends StatefulWidget {
  const _Shell({required this.navigatorKey, this.enabled = true});

  final GlobalKey<NavigatorState> navigatorKey;
  final bool enabled;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int destination = 0;

  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 200,
            child: Column(
              children: [
                const Text('SIDEBAR'),
                TextButton(
                  onPressed: () {
                    SidebarContentNavigator.closeOpenedScreens(
                      widget.navigatorKey,
                    );
                    setState(() => destination++);
                  },
                  child: const Text('next destination'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SidebarContentNavigator(
              navigatorKey: widget.navigatorKey,
              enabled: widget.enabled,
              child: _Content(destination: destination),
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.destination});

  final int destination;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('destination $destination'),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('DETAILS')),
            ),
          ),
          child: const Text('open details'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(RoutesConst.loginScreen),
          child: const Text('sign out'),
        ),
      ],
    );
  }
}

void main() {
  late GlobalKey<NavigatorState> contentKey;

  setUp(() => contentKey = GlobalKey<NavigatorState>());

  Future<void> pumpShell(WidgetTester tester, {bool enabled = true}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: _Shell(navigatorKey: contentKey, enabled: enabled),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('ROOT ${settings.name}')),
        ),
      ),
    );
  }

  testWidgets('a screen opened from the content stays beside the sidebar',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('open details'));
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsOneWidget);
    // The sidebar is neither covered nor pushed off screen...
    expect(find.text('SIDEBAR'), findsOneWidget);
    expect(
        tester.getTopLeft(find.text('DETAILS')).dx, greaterThanOrEqualTo(200));
    // ...and it still works.
    expect(find.text('next destination').hitTestable(), findsOneWidget);
  });

  testWidgets('choosing a menu item closes what was opened on top',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('open details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('next destination'));
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsNothing);
    expect(find.text('destination 1'), findsOneWidget);
  });

  testWidgets('the dashboard content updates without closing an open screen',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('open details'));
    await tester.pumpAndSettle();

    // A dashboard rebuild that does not come from the menu.
    tester.state<_ShellState>(find.byType(_Shell)).rebuild();
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsOneWidget);
  });

  testWidgets('Back closes the opened screen before leaving the dashboard',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('open details'));
    await tester.pumpAndSettle();

    // What the browser's Back button does.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsNothing);
    expect(find.text('destination 0'), findsOneWidget);
    expect(find.text('SIDEBAR'), findsOneWidget);
  });

  testWidgets(
      'an app-level route goes to the root navigator, not beside the '
      'sidebar', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('sign out'));
    await tester.pumpAndSettle();

    expect(find.text('ROOT ${RoutesConst.loginScreen}'), findsOneWidget);
    // The whole dashboard is gone, not just its content.
    expect(find.text('SIDEBAR'), findsNothing);
  });

  testWidgets('disabled (off the web), screens open full-screen as before',
      (tester) async {
    await pumpShell(tester, enabled: false);

    await tester.tap(find.text('open details'));
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.text('SIDEBAR'), findsNothing);
  });
}
