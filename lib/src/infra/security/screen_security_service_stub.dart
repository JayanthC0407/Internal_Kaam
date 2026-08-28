/// No-op on web and desktop.
class ScreenSecurityService {
  ScreenSecurityService._();

  static Future<void> enable() async {}

  static Future<void> disable() async {}
}
