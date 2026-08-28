import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';
import 'package:ubci_bank/src/core/models/registration_flow_result.dart';
import 'package:ubci_bank/src/core/models/registration_request.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/registration_providers.dart';
import 'package:ubci_bank/src/view/providers/repository_providers.dart';

class RegistrationScreenVm {
  RegistrationScreenVm(this._ref);

  final Ref _ref;

  Future<RegistrationStartResult?> startRegistration({
    required RegistrationRequest request,
    required AppLocalizations l10n,
  }) async {
    _ref.read(registrationIsLoadingProvider.notifier).state = true;
    _ref.read(registrationErrorMessageProvider.notifier).state = null;

    if (!EnvConfig.isConfigured) {
      EnvConfig.logMissingBaseUrlIfNeeded();
      _ref.read(registrationIsLoadingProvider.notifier).state = false;
      _ref.read(registrationErrorMessageProvider.notifier).state =
          l10n.errorApiNotConfigured;
      return null;
    }

    final result = await _ref
        .read(registrationRepositoryProvider)
        .startRegistration(request: request);

    _ref.read(registrationIsLoadingProvider.notifier).state = false;

    if (result is Success<RegistrationStartResult>) {
      final data = result.data;
      if (data != null) {
        _applyAttemptsLeft(data.attemptsLeft);
        _ref.read(registrationIdProvider.notifier).state = data.registrationId;
      }
      return data;
    }

    await _assignError(result, l10n.registrationFailed);
    return null;
  }

  Future<bool> verifyCode({
    required String code,
    required AppLocalizations l10n,
  }) async {
    _ref.read(registrationIsLoadingProvider.notifier).state = true;
    _ref.read(registrationErrorMessageProvider.notifier).state = null;

    final result = await _ref
        .read(registrationRepositoryProvider)
        .authenticate(verificationCode: code);

    _ref.read(registrationIsLoadingProvider.notifier).state = false;

    if (result is Success<RegistrationAuthResult>) {
      final data = result.data;
      if (data != null) {
        if (data.isVerified) {
          _applyAttemptsLeft(data.attemptsLeft);
          return true;
        }
        // Wrong OTP: OBDX often echoes attemptsLeft: 0 (same shape as a
        // successful verify). Applying that locks OtpChallengeBody. Only trust
        // a positive remaining count; otherwise keep the previous value — and
        // clear a spurious 0 so the user can retry.
        _applyAttemptsLeftAfterFailedVerify(data.attemptsLeft);
        _ref.read(registrationErrorMessageProvider.notifier).state =
            l10n.registrationVerificationFailed;
      }
      return false;
    }

    await _assignError(result, l10n.registrationVerificationFailed);
    return false;
  }

  Future<RegistrationStartResult?> resendCode({
    required AppLocalizations l10n,
  }) async {
    _ref.read(registrationIsLoadingProvider.notifier).state = true;
    _ref.read(registrationErrorMessageProvider.notifier).state = null;

    final result =
        await _ref.read(registrationRepositoryProvider).resendVerificationCode();

    _ref.read(registrationIsLoadingProvider.notifier).state = false;

    if (result is Success<RegistrationStartResult>) {
      final data = result.data;
      if (data != null) {
        _applyAttemptsLeft(data.attemptsLeft);
        _ref.read(registrationIdProvider.notifier).state = data.registrationId;
      }
      return data;
    }

    await _assignError(result, l10n.registrationResendFailed);
    return null;
  }

  Future<void> abandon() async {
    await _ref.read(registrationRepositoryProvider).abandon();
    _ref.read(registrationAttemptsLeftProvider.notifier).state = null;
    _ref.read(registrationIdProvider.notifier).state = null;
    _ref.read(registrationErrorMessageProvider.notifier).state = null;
  }

  void _applyAttemptsLeft(int? attemptsLeft) {
    // Never persist 0 from start/resend — that disables the OTP pin before the
    // user can type. Real lockout is signaled via DIGX_AUTH_0004 / error path.
    if (attemptsLeft == null || attemptsLeft <= 0) return;
    _ref.read(registrationAttemptsLeftProvider.notifier).state = attemptsLeft;
  }

  void _applyAttemptsLeftAfterFailedVerify(int? attemptsLeft) {
    if (attemptsLeft != null && attemptsLeft > 0) {
      _ref.read(registrationAttemptsLeftProvider.notifier).state = attemptsLeft;
      return;
    }
    final current = _ref.read(registrationAttemptsLeftProvider);
    if (current != null && current <= 0) {
      _ref.read(registrationAttemptsLeftProvider.notifier).state = null;
    }
  }

  Future<void> _assignError(
    ResponseHandler<dynamic> result,
    String fallback,
  ) async {
    final resolvedL10n = await AppLocalizationsHelper.current();
    if (result is Error) {
      _ref.read(registrationErrorMessageProvider.notifier).state =
          result.resolveUserMessage(l10n: resolvedL10n, fallback: fallback);
    } else if (result is NetworkError) {
      _ref.read(registrationErrorMessageProvider.notifier).state =
          result.resolveUserMessage(l10n: resolvedL10n);
    } else if (result is ExceptionError) {
      _ref.read(registrationErrorMessageProvider.notifier).state =
          result.resolveUserMessage(l10n: resolvedL10n);
    } else {
      _ref.read(registrationErrorMessageProvider.notifier).state = fallback;
    }
  }
}
