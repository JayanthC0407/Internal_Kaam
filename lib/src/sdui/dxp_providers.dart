import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dxp_runtime.dart';

/// One DXP runtime for the app. Started by a dashboard after the OBDX login
/// and stopped when that dashboard closes (CONTRACT-OBDX §1.1).
final dxpRuntimeProvider = ChangeNotifierProvider<DxpRuntime>(
  (ref) => DxpRuntime(),
);
