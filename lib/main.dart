import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/application/ubci_app.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';
import 'package:ubci_bank/src/core/config/ssl_pin_config.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';

final mainScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.validateAtStartup();
  EnvConfig.logMissingBaseUrlIfNeeded();
  EnvConfig.logWebCorsHintIfNeeded();
  SslPinConfig.validateAtStartup();
  await PreferenceHelper.getInstance().ensureInitialized();
  runApp(const ProviderScope(child: UbciApp()));
}
