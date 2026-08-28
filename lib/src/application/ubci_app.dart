import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/main.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/service/navigation_service.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes.dart';
import 'package:ubci_bank/src/view/widgets/biometric_lock_overlay.dart';
import 'package:ubci_bank/src/view/widgets/session_activity_scope.dart';
import 'package:ubci_bank/src/view/widgets/session_expiry_listener.dart';

class UbciApp extends ConsumerWidget {
  const UbciApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      supportedLocales: LocaleConfig.supportedLocales,
      localeListResolutionCallback: (locales, supported) {
        for (final locale in locales ?? const <Locale>[]) {
          for (final supportedLocale in supported) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return const Locale('en');
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return SessionExpiryListener(
          child: SessionActivityScope(
            child: BiometricLockOverlay(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      scaffoldMessengerKey: mainScaffoldMessengerKey,
      navigatorKey: NavigationService.globalAppNav,
      initialRoute: '/',
      onGenerateRoute: Routes.onGenerateRoutes,
      onUnknownRoute: Routes.onUnknownRoute,
    );
  }
}
