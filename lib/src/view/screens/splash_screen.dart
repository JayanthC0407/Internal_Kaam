import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/infra/security/biometric_unlock_policy.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/biometric_unlock_screen.dart';
import 'package:ubci_bank/src/view/viewmodel/splash_screen_vm.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashLogoPng = 'assets/images/demobank_splash.png';

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _logoSizeAnimation;
  late final Animation<double> _slideAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.68, curve: Curves.easeOut),
      ),
    );
    _logoSizeAnimation = Tween<double>(begin: 16, end: 128).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.90, curve: Curves.easeOutBack),
      ),
    );
    _slideAnimation = Tween<double>(begin: 8, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.32, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward();
    _navigationTimer = Timer(SplashScreenVm.splashDuration, () async {
      if (!mounted) return;

      final security =
          await ref.read(deviceSecurityServiceProvider).evaluate();
      if (!mounted) return;

      if (security.shouldBlock) {
        Navigator.of(context).pushReplacementNamed(
          RoutesConst.deviceBlockedScreen,
          arguments: security.threatType,
        );
        return;
      }

      if (security.shouldWarn) {
        ref.read(pendingDeviceSecurityWarningProvider.notifier).state =
            security.threatType;
      }

      final session = ref.read(sessionManagerProvider);
      final preferences = ref.read(preferenceHelperProvider);
      final biometrics = ref.read(biometricServiceProvider);
      final route = await session.resolveInitialRoute(
        preferences: preferences,
        biometrics: biometrics,
      );
      if (!mounted) return;

      if (route == RoutesConst.biometricUnlockScreen) {
        final homeArgs = await session.buildHomeArgs();
        if (!mounted) return;

        Navigator.of(context).pushReplacementNamed(
          RoutesConst.biometricUnlockScreen,
          arguments: BiometricUnlockArgs(
            homeArgs: homeArgs,
            performTokenLogin: true,
          ),
        );
        return;
      }

      if (route == RoutesConst.homeScreen) {
        final args = await session.buildHomeArgs();
        if (!mounted) return;

        final needsBiometric = await BiometricUnlockPolicy.shouldRequireUnlock(
          session: session,
          preferences: preferences,
          biometrics: biometrics,
        );
        if (!mounted) return;

        if (needsBiometric) {
          Navigator.of(context).pushReplacementNamed(
            RoutesConst.biometricUnlockScreen,
            arguments: BiometricUnlockArgs(homeArgs: args),
          );
          return;
        }

        Navigator.of(context).pushReplacementNamed(
          route,
          arguments: args,
        );
        return;
      }

      Navigator.of(context).pushReplacementNamed(route);
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).brand,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Image.asset(
                  _splashLogoPng,
                  width: _logoSizeAnimation.value,
                  height: _logoSizeAnimation.value,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.account_balance,
                    size: _logoSizeAnimation.value,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
