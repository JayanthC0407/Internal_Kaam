import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'src/core/config/locale_config.dart';
import 'src/core/theme/app_theme.dart';
import 'src/sdui/preview/dxp_preview_app.dart';
import 'src/sdui/render/renderer.dart';
import 'src/view/screens/retail/dxp/retail_app_widgets.dart';
import 'src/view/screens/retail/dxp/retail_preview_samples.dart';

/// Entry point of the DXP Studio preview: a web build of this app's DXP
/// renderer plus Retail's own Home widgets, which draw from sample data
/// (no OBDX, login or session). Built and installed into the platform by
/// `scripts/build_dxp_preview.sh`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A widget that throws shows a small box instead of the red error screen.
  ErrorWidget.builder =
      (details) => const UnsupportedBox(label: 'This item could not be shown');
  runApp(ProviderScope(
    overrides: RetailPreviewSamples.overrides,
    child: DxpPreviewApp(
      appWidgets: RetailAppWidgets.builders,
      appTheme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleConfig.supportedLocales,
    ),
  ));
}
