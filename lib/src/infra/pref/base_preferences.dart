import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/src/core/extensions/extensions.dart';

class BasePreferences {
  Future<bool> getBool(String key) async {
    final p = await _prefs;
    return p.getBool(key).orFalse();
  }

  Future<void> setBool(String key, bool value) async {
    final p = await _prefs;
    await p.setBool(key, value);
  }

  Future<String> getString(String key) async {
    final p = await _prefs;
    return p.getString(key).orEmpty();
  }

  Future<void> setString(String key, String value) async {
    final p = await _prefs;
    await p.setString(key, value);
  }

  Future<bool> remove(String key) async {
    final p = await _prefs;
    return p.remove(key);
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
}
