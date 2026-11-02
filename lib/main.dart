import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:demo_bank/src/application/demo_bank_app.dart';
import 'package:demo_bank/src/core/config/env_config.dart';
import 'package:demo_bank/src/core/config/ssl_pin_config.dart';
import 'package:demo_bank/src/infra/pref/preference_helper.dart';

final mainScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.validateAtStartup();
  EnvConfig.logMissingBaseUrlIfNeeded();
  EnvConfig.logWebCorsHintIfNeeded();
  SslPinConfig.validateAtStartup();
  await PreferenceHelper.getInstance().ensureInitialized();
  runApp(const ProviderScope(child: DemoBankApp()));
}
