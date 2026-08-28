enum DeviceThreatType {
  none,
  compromisedDevice,
  emulator,
}

class DeviceSecurityAssessment {
  const DeviceSecurityAssessment({
    required this.threatType,
    required this.shouldBlock,
    required this.shouldWarn,
  });

  final DeviceThreatType threatType;
  final bool shouldBlock;
  final bool shouldWarn;

  bool get isSecure => threatType == DeviceThreatType.none;

  static const secure = DeviceSecurityAssessment(
    threatType: DeviceThreatType.none,
    shouldBlock: false,
    shouldWarn: false,
  );
}
