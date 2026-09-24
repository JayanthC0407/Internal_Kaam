/// Payload for OBDX customer-lookup registration
/// (`POST /digx-common/user/v1/registration`).
///
/// Matches live RegistrationDTO used by digx-ui (party/account verification).
/// Username/password are created later via emailed link — not sent here.
class RegistrationRequest {
  const RegistrationRequest({
    required this.firstName,
    required this.lastName,
    required this.emailId,
    required this.partyId,
    required this.dateOfBirth,
    required this.accountType,
    required this.accountNumber,
    this.debitCardNumber,
  });

  final String firstName;
  final String lastName;
  final String emailId;

  /// Customer Id on the registration form.
  final String partyId;

  /// ISO date `yyyy-MM-dd`.
  final String dateOfBirth;
  final String accountType;
  final String accountNumber;
  final String? debitCardNumber;

  RegistrationRequest copyWith({String? accountType}) {
    return RegistrationRequest(
      firstName: firstName,
      lastName: lastName,
      emailId: emailId,
      partyId: partyId,
      dateOfBirth: dateOfBirth,
      accountType: accountType ?? this.accountType,
      accountNumber: accountNumber,
      debitCardNumber: debitCardNumber,
    );
  }

  Map<String, dynamic> toJson() {
    final debit = debitCardNumber?.replaceAll(RegExp(r'\s+'), '');
    return {
      'registrationId': null,
      'firstName': firstName,
      'lastName': lastName,
      'emailId': emailId,
      'partyId': partyId,
      'dateOfBirth': dateOfBirth,
      'customer': null,
      'accountType': accountType,
      'phone': {
        'areaCode': null,
        'number': null,
        'extension': null,
      },
      'remarks': null,
      'token': null,
      'registrationStatus': null,
      'accountNumber': accountNumber,
      'username': null,
      'password': null,
      'creditCardNumber': null,
      'creditCardNameOnCard': null,
      'creditCardExpiryDate': null,
      'creditCardCVVNumber': null,
      'debitCardNumber': (debit == null || debit.isEmpty) ? null : debit,
      'debitCardPin': null,
      'userGroups': <dynamic>[],
      'targetUnit': null,
    };
  }
}
