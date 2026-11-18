import 'package:flutter/widgets.dart';

import '../node.dart';
import '../renderer.dart';

/// The app's own hand-built widgets that a published screen may place by
/// name: `{ "type": "AppWidget", "props": { "name": "recent-account-transactions" } }`.
///
/// The runtime does not know them; the host app provides them through this
/// scope (the Retail dashboard on a device, the Studio preview with sample
/// data). Each widget still loads its own data from OBDX through the app.
class DxpAppWidgets extends InheritedWidget {
  const DxpAppWidgets({super.key, required this.builders, required super.child});

  final Map<String, Widget Function()> builders;

  static Map<String, Widget Function()> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DxpAppWidgets>()?.builders ??
      const {};

  @override
  bool updateShouldNotify(DxpAppWidgets oldWidget) =>
      !identical(oldWidget.builders, builders);
}

Widget buildAppWidget(NodeSpec n, NodeScope s) {
  final name = n.str('name');
  return Builder(builder: (context) {
    final builder = DxpAppWidgets.of(context)[name];
    if (builder == null) {
      return UnsupportedBox(label: 'Not in this app version: $name');
    }
    return builder();
  });
}
