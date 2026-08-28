import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/application/ubci_app.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: UbciApp()),
    );
    await tester.pump();

    expect(find.byType(UbciApp), findsOneWidget);
  });
}
