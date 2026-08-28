class AppConstants {
  static const String socketException = 'SocketException';
  static const String xRequestId = 'x-request-id';
  static const String userName = 'userName';
  static const String password = 'password';
  static const String targetUnit = 'OBDX_BU';
  static const String defaultPhoneCountryCode = String.fromEnvironment(
    'DEFAULT_PHONE_COUNTRY_CODE',
    defaultValue: '91',
  );
}
