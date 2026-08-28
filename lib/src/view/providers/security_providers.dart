import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/infra/security/device_security_models.dart';
import 'package:ubci_bank/src/infra/security/device_security_service.dart';

final deviceSecurityServiceProvider = Provider(
  (_) => DeviceSecurityService.instance,
);

/// Set on splash when device security is in warn mode; consumed on login.
final pendingDeviceSecurityWarningProvider =
    StateProvider<DeviceThreatType?>((ref) => null);
