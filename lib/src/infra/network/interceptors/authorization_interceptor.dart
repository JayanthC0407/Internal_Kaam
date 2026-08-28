import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/core/config/app_locale_holder.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/constants/app_constants.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/session/registration_session_holder.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';

class AuthorizationInterceptor extends InterceptorsWrapper {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Browsers forbid setting User-Agent from JS; skip on web to avoid console noise.
    if (!kIsWeb) {
      options.headers.putIfAbsent(
        ApiConst.userAgentKey,
        () => ApiConst.userAgent,
      );
    }
    options.headers.putIfAbsent(
      ApiConst.xRequestedWith,
      () => 'XMLHttpRequest',
    );
    options.headers['Accept-Language'] = LocaleConfig.acceptLanguageHeader(
      AppLocaleHolder.instance.languageCode,
    );
    options.headers.putIfAbsent('Accept', () {
      return 'application/json, text/javascript, */*; q=0.01';
    });

    final requestPath = options.path;
    final needsTargetUnit = !ApiConst.noTargetUnitPaths
        .any((path) => requestPath.contains(path));
    if (needsTargetUnit) {
      options.headers.putIfAbsent(
        ApiConst.xTargetUnit,
        () => AppConstants.targetUnit,
      );
    }

    if (!kIsWeb) {
      options.headers.putIfAbsent(ApiConst.connection, () => ApiConst.keepAlive);
    }

    final isAuthFree = ApiConst.noAuthPaths
        .any((path) => requestPath.contains(path));
    if (!isAuthFree) {
      final registrationAuth =
          RegistrationSessionHolder.instance.anonymousAuth;
      if (registrationAuth != null &&
          registrationAuth.accessToken.isNotEmpty) {
        options.headers[ApiConst.authorization] =
            '${registrationAuth.getTokenType} ${registrationAuth.accessToken}';
        options.headers[ApiConst.xTokenType] = 'JWT';
      } else {
        final auth = await PreferenceHelper.getInstance().getAuthorization();
        if (auth != null && auth.accessToken.isNotEmpty) {
          options.headers[ApiConst.authorization] =
              '${auth.getTokenType} ${auth.accessToken}';
          options.headers[ApiConst.xTokenType] = 'JWT';
        }
      }
    }

    super.onRequest(options, handler);
  }
}
