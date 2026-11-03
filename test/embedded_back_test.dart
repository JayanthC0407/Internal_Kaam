import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:demo_bank/src/view/widgets/embedded_back.dart';

void main() {
  test('a claim is seen by a later microtask, then cleared on the next event', () async {
    expect(EmbeddedBack.wasClaimed, isFalse);
    EmbeddedBack.claim();
    final seen = Completer<bool>();
    scheduleMicrotask(() => seen.complete(EmbeddedBack.wasClaimed));
    expect(await seen.future, isTrue, reason: 'the dashboard reads it in a microtask');
    await Future<void>.delayed(Duration.zero);
    expect(EmbeddedBack.wasClaimed, isFalse, reason: 'never swallows a later Back press');
  });
}
