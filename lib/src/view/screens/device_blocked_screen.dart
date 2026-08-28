import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/infra/security/device_security_models.dart';
import 'package:ubci_bank/src/view/widgets/secure_screen.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

class DeviceBlockedScreen extends StatelessWidget {
  const DeviceBlockedScreen({
    super.key,
    required this.threatType,
  });

  final DeviceThreatType threatType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final message = switch (threatType) {
      DeviceThreatType.emulator => l10n.deviceBlockedEmulatorMessage,
      DeviceThreatType.compromisedDevice => l10n.deviceBlockedCompromisedMessage,
      DeviceThreatType.none => l10n.deviceBlockedCompromisedMessage,
    };

    return SecureScreen(
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.of(context).brandDark,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(responsive.formHorizontalPadding + 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: responsive.formMaxWidth),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: responsive.isCompactHeight ? 56 : 72,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.deviceBlockedTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        l10n.deviceBlockedSupport,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
