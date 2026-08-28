import 'package:ubci_bank/src/infra/security/device_security_models.dart';

/// Web/desktop stub — device integrity checks are mobile-only.
class DeviceSecurityService {
  DeviceSecurityService._();

  static final DeviceSecurityService instance = DeviceSecurityService._();

  Future<DeviceSecurityAssessment> evaluate() async {
    return DeviceSecurityAssessment.secure;
  }
}
