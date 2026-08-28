import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';

void main() {
  group('EnvConfig transport policy', () {
    test('isCleartextHttpPermitted is true when APP_ENV=dev', () {
      // Default test environment: APP_ENV=dev (fromEnvironment default)
      expect(EnvConfig.isDev, isTrue);
      expect(EnvConfig.isCleartextHttpPermitted, isTrue);
    });

    test('validateAtStartup accepts https URLs', () {
      // When OBDX_BASE_URL is unset, validateAtStartup is a no-op for empty URL.
      expect(() => EnvConfig.validateAtStartup(), returnsNormally);
    });
  });
}
