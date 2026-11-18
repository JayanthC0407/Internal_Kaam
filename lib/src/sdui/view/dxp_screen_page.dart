import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dxp_providers.dart';
import '../dxp_runtime.dart';
import 'dxp_screen_view.dart';

/// A published screen opened on its own page, with a back arrow
/// (CONTRACT-OBDX §10). Opened by `navigate` and by DXP menu entries.
class DxpScreenPage extends ConsumerWidget {
  const DxpScreenPage({super.key, required this.screenId});

  /// Route name of every DXP page, so `nativeRoute` can leave them all.
  static const routeName = 'dxp-screen';

  final String screenId;

  static Route<void> route(String screenId) => MaterialPageRoute<void>(
        settings: RouteSettings(name: routeName, arguments: screenId),
        builder: (_) => DxpScreenPage(screenId: screenId),
      );

  static Future<void> open(BuildContext context, String screenId) =>
      Navigator.of(context).push(route(screenId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(dxpRuntimeProvider);
    final title = runtime.cachedScreen(screenId)?['title']?.toString() ?? '';
    // The platform session ended while this page was open: nothing to draw.
    if (runtime.status != DxpStatus.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
    }
    return Scaffold(
      backgroundColor: runtime.theme.background,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: DxpScreenView(screenId: screenId)),
    );
  }
}
