/// Result of `POST /digx-common/user/v1/registration`.
class RegistrationStartResult {
  const RegistrationStartResult({
    required this.registrationId,
    this.attemptsLeft,
    this.customer = false,
    this.partyVerified = false,
    this.accountVerified = false,
    this.debitCardVerified = false,
    this.tokenValid = false,
  });

  final String registrationId;

  /// Remaining OTP attempts from the start response. Null when the API omits it.
  final int? attemptsLeft;
  final bool customer;
  final bool partyVerified;
  final bool accountVerified;
  final bool debitCardVerified;
  final bool tokenValid;

  factory RegistrationStartResult.fromJson(Map<String, dynamic> json) {
    final dto = json['registrationDTO'];
    final dtoMap = dto is Map ? Map<String, dynamic>.from(dto) : const {};
    final registrationId =
        (dtoMap['registrationId'] ?? json['registrationId'] ?? '').toString();

    bool verified(String key) {
      final block = json[key];
      if (block is Map && block['verificationStatus'] == true) return true;
      return false;
    }

    return RegistrationStartResult(
      registrationId: registrationId,
      attemptsLeft: _parseAttempts(
        json['attemptsLeft'] ?? dtoMap['attemptsLeft'],
      ),
      customer: dtoMap['customer'] == true,
      partyVerified: verified('partyVerificationResponse'),
      accountVerified: verified('accountVerificationResponse'),
      debitCardVerified: verified('debitCardVerificationResponse'),
      tokenValid: json['tokenValid'] == true,
    );
  }
}

/// Result of `PUT .../registration/{id}/authentication`.
class RegistrationAuthResult {
  const RegistrationAuthResult({
    required this.registrationId,
    required this.tokenValid,
    this.attemptsLeft,
    this.registrationStatus,
  });

  final String registrationId;
  final bool tokenValid;

  /// Remaining OTP attempts after verify. Null when omitted — callers must keep
  /// the previous count (never treat missing as 0, which locks the OTP UI).
  final int? attemptsLeft;
  final String? registrationStatus;

  bool get isVerified =>
      tokenValid ||
      (registrationStatus?.toUpperCase() == 'VER');

  factory RegistrationAuthResult.fromJson(Map<String, dynamic> json) {
    final dto = json['registrationDTO'];
    final dtoMap = dto is Map ? Map<String, dynamic>.from(dto) : const {};

    return RegistrationAuthResult(
      registrationId:
          (dtoMap['registrationId'] ?? json['registrationId'] ?? '').toString(),
      tokenValid: json['tokenValid'] == true,
      attemptsLeft: _parseAttempts(
        json['attemptsLeft'] ?? dtoMap['attemptsLeft'],
      ),
      registrationStatus: dtoMap['registrationStatus']?.toString(),
    );
  }
}

int? _parseAttempts(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
