import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Enables browser-managed cookies (Set-Cookie / Cookie) for cross-origin OBDX.
void applyWebCredentials(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
