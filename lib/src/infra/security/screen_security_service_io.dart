import 'package:screen_protector/screen_protector.dart';

class ScreenSecurityService {
  ScreenSecurityService._();

  static Future<void> enable() async {
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.preventScreenshotOn();
  }

  static Future<void> disable() async {
    await ScreenProtector.preventScreenshotOff();
    await ScreenProtector.protectDataLeakageOff();
  }
}
