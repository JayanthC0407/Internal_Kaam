import 'package:demo_bank/src/infra/security/mobile_device_info_service.dart';

/// The User-Agent the Android / iOS app sends to OBDX.
///
/// OBDX tells its mobile app from a browser by the User-Agent: its Cordova
/// app sends the phone's own WebView User-Agent with `obdx-mobile` appended
/// (the channel checks for that marker in
/// `framework/js/base-models/platform-resolver.js` and
/// `platform/authentication/JWTAuthenticator.js`), and the server records
/// the session's device and touch point from it. A desktop browser string
/// here made every app login show up in admin as Internet / browser, so
/// this builds the same shape OBDX's app sends: the device's OS and model,
/// then [marker].
///
/// Web never uses this — browsers send their own User-Agent.
class MobileUserAgent {
  MobileUserAgent._();

  /// What OBDX looks for to treat a request as its mobile app.
  static const marker = 'obdx-mobile';

  static Future<String>? _value;

  /// Built once per app run from the device's details.
  static Future<String> get value => _value ??= _build();

  static Future<String> _build() async {
    try {
      return forDevice(await MobileDeviceInfoService.instance.collect());
    } catch (_) {
      // Device details unavailable: still identify as the mobile app.
      return 'Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 (KHTML, like Gecko) Mobile Safari/537.36 $marker';
    }
  }

  /// The User-Agent for [device], as an Android or iOS WebView sends it,
  /// followed by [marker].
  static String forDevice(MobileDevicePayload device) {
    String clean(String s) => s.replaceAll(RegExp(r'[;()\r\n]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final version = clean(device.osVersion);
    if (device.os == 'IOS') {
      final model = clean(device.model).toLowerCase().contains('ipad') ? 'iPad' : 'iPhone';
      final ios = version.replaceAll('.', '_');
      final cpu = model == 'iPad' ? 'CPU OS $ios' : 'CPU iPhone OS $ios';
      return 'Mozilla/5.0 ($model; $cpu like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 $marker';
    }
    return 'Mozilla/5.0 (Linux; Android $version; ${clean(device.model)}) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Version/4.0 Mobile Safari/537.36 $marker';
  }
}
