import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_bank/src/application/demo_bank_app.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DemoBankApp()),
    );
    await tester.pump();

    expect(find.byType(DemoBankApp), findsOneWidget);
  });
}
