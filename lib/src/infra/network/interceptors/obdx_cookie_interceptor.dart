import 'package:cookie_jar/cookie_jar.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';

class ObdxCookieInterceptor implements CookieJar {
  @override
  bool get ignoreExpires => false;

  @override
  Future<void> delete(Uri uri, [bool withDomainSharedCookie = false]) async {}

  @override
  Future<void> deleteAll() async {
    await PreferenceHelper.getInstance().clearCookies();
  }

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) async {
    return PreferenceHelper.getInstance().getCookies();
  }

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {
    if (cookies.isEmpty) return;
    await PreferenceHelper.getInstance().saveCookies(cookies);
  }
}
