import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dxp_providers.dart';
import '../dxp_runtime.dart';
import 'dxp_screen_view.dart';

/// The DXP slot on a native Home: draws the manifest's `home` screen
/// (CONTRACT-OBDX §10). Takes no room at all when DXP is off, unavailable
/// or has no home screen, so the native Home is unchanged.
class DxpHomeSlot extends ConsumerWidget {
  const DxpHomeSlot({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(dxpRuntimeProvider);
    final home = runtime.homeScreen;
    if (runtime.status != DxpStatus.ready || home == null || !runtime.hasScreen(home)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: padding,
      child: DxpScreenView(screenId: home, embedded: true),
    );
  }
}
