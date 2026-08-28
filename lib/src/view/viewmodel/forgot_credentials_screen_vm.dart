import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';
import 'package:ubci_bank/src/core/models/forgot_credentials_pending.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/forgot_credentials_providers.dart';
import 'package:ubci_bank/src/view/providers/repository_providers.dart';

class ForgotCredentialsScreenVm {
  ForgotCredentialsScreenVm(this._ref);

  final Ref _ref;

  Future<ResponseHandler<ForgotCredentialsFlowResult>?> startForgotUsername({
    required String emailId,
    required String dateOfBirth,
  }) {
    return _run(
      () => _ref.read(forgotCredentialsRepositoryProvider).startForgotUsername(
            emailId: emailId,
            dateOfBirth: dateOfBirth,
          ),
    );
  }

  Future<ResponseHandler<ForgotCredentialsFlowResult>?> startForgotPassword({
    required String userId,
    required String dateOfBirth,
  }) {
    return _run(
      () => _ref.read(forgotCredentialsRepositoryProvider).startForgotPassword(
            userId: userId,
            dateOfBirth: dateOfBirth,
          ),
    );
  }

  Future<ResponseHandler<ForgotCredentialsFlowResult>?> submitOtp({
    required String otp,
  }) {
    return _run(
      () => _ref.read(forgotCredentialsRepositoryProvider).submitOtp(otp: otp),
      otpFallback: true,
    );
  }

  Future<bool> resendOtp() async {
    _ref.read(forgotIsLoadingProvider.notifier).state = true;
    _ref.read(forgotErrorMessageProvider.notifier).state = null;

    try {
      if (!EnvConfig.isConfigured) {
        EnvConfig.logMissingBaseUrlIfNeeded();
        final l10n = await AppLocalizationsHelper.current();
        _ref.read(forgotErrorMessageProvider.notifier).state =
            l10n.errorApiNotConfigured;
        return false;
      }

      final result =
          await _ref.read(forgotCredentialsRepositoryProvider).resendOtp();

      final l10n = await AppLocalizationsHelper.current();
      if (result is Success<void>) {
        return true;
      }
      if (result is Error<void>) {
        _ref.read(forgotErrorMessageProvider.notifier).state =
            result.resolveUserMessage(
                l10n: l10n, fallback: l10n.errorOtpInvalid);
      } else if (result is NetworkError<void>) {
        _ref.read(forgotErrorMessageProvider.notifier).state =
            result.resolveUserMessage(l10n: l10n);
      } else if (result is ExceptionError<void>) {
        _ref.read(forgotErrorMessageProvider.notifier).state =
            result.resolveUserMessage(l10n: l10n);
      }
      return false;
    } catch (_) {
      final l10n = await AppLocalizationsHelper.current();
      _ref.read(forgotErrorMessageProvider.notifier).state = l10n.errorUnexpected;
      return false;
    } finally {
      _ref.read(forgotIsLoadingProvider.notifier).state = false;
    }
  }

  Future<void> abandon() async {
    await _ref.read(forgotCredentialsRepositoryProvider).clear();
    _ref.read(forgotIsLoadingProvider.notifier).state = false;
    _ref.read(forgotErrorMessageProvider.notifier).state = null;
  }

  Future<ResponseHandler<ForgotCredentialsFlowResult>?> _run(
    Future<ResponseHandler<ForgotCredentialsFlowResult>> Function() action, {
    bool otpFallback = false,
  }) async {
    _ref.read(forgotIsLoadingProvider.notifier).state = true;
    _ref.read(forgotErrorMessageProvider.notifier).state = null;

    try {
      if (!EnvConfig.isConfigured) {
        EnvConfig.logMissingBaseUrlIfNeeded();
        final l10n = await AppLocalizationsHelper.current();
        _ref.read(forgotErrorMessageProvider.notifier).state =
            l10n.errorApiNotConfigured;
        return null;
      }

      final result = await action();
      final l10n = await AppLocalizationsHelper.current();
      _applyError(result, l10n, otpFallback: otpFallback);
      return result;
    } catch (_) {
      final l10n = await AppLocalizationsHelper.current();
      _ref.read(forgotErrorMessageProvider.notifier).state = l10n.errorUnexpected;
      return null;
    } finally {
      _ref.read(forgotIsLoadingProvider.notifier).state = false;
    }
  }

  void _applyError(
    ResponseHandler<ForgotCredentialsFlowResult> result,
    AppLocalizations l10n, {
    required bool otpFallback,
  }) {
    final fallback =
        otpFallback ? l10n.errorOtpInvalid : l10n.errorGeneric;
    if (result is Error<ForgotCredentialsFlowResult>) {
      _ref.read(forgotErrorMessageProvider.notifier).state =
          result.resolveUserMessage(l10n: l10n, fallback: fallback);
    } else if (result is NetworkError<ForgotCredentialsFlowResult>) {
      _ref.read(forgotErrorMessageProvider.notifier).state =
          result.resolveUserMessage(l10n: l10n);
    } else if (result is ExceptionError<ForgotCredentialsFlowResult>) {
      _ref.read(forgotErrorMessageProvider.notifier).state =
          result.resolveUserMessage(l10n: l10n);
    }
  }
}
