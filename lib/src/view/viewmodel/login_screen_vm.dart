import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/config/env_config.dart';
import 'package:ubci_bank/src/core/models/login_flow_result.dart';
import 'package:ubci_bank/src/core/models/login_trace.dart';
import 'package:ubci_bank/src/core/models/otp_login_pending.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/login_providers.dart';
import 'package:ubci_bank/src/view/providers/repository_providers.dart';

class LoginScreenVm {
  LoginScreenVm(this._ref);

  final Ref _ref;

  Future<ResponseHandler<LoginFlowResult>?> login({
    required String userName,
    required String password,
  }) async {
    _ref.read(loginIsLoadingProvider.notifier).state = true;
    _ref.read(loginErrorMessageProvider.notifier).state = null;

    try {
      if (!EnvConfig.isConfigured) {
        EnvConfig.logMissingBaseUrlIfNeeded();
        final l10n = await AppLocalizationsHelper.current();
        _ref.read(loginErrorMessageProvider.notifier).state =
            l10n.errorApiNotConfigured;
        return null;
      }

      final result = await _ref.read(authRepositoryProvider).performLogin(
            userName: userName,
            password: password,
          );

      final l10n = await AppLocalizationsHelper.current();
      _applyLoginError(result, l10n);
      return result;
    } catch (_) {
      final l10n = await AppLocalizationsHelper.current();
      _ref.read(loginErrorMessageProvider.notifier).state = l10n.errorUnexpected;
      return null;
    } finally {
      _ref.read(loginIsLoadingProvider.notifier).state = false;
    }
  }

  void _applyLoginError(
    ResponseHandler<LoginFlowResult> result,
    AppLocalizations l10n,
  ) {
    if (result is Error<LoginFlowResult>) {
      _ref.read(loginErrorMessageProvider.notifier).state =
          result.resolveUserMessage(l10n: l10n, fallback: l10n.errorLoginFailed);
    } else if (result is NetworkError<LoginFlowResult>) {
      _ref.read(loginErrorMessageProvider.notifier).state =
          result.resolveUserMessage(l10n: l10n);
    } else if (result is ExceptionError<LoginFlowResult>) {
      _ref.read(loginErrorMessageProvider.notifier).state =
          result.resolveUserMessage(l10n: l10n);
    } else if (result is Success<LoginFlowResult>) {
      final flow = result.data;
      if (flow?.isComplete == true) {
        final statusCode =
            flow!.trace!.loginResponse['statusCode'] as int? ?? 0;
        if (statusCode < 200 || statusCode >= 300) {
          final loginResponse = flow.trace!.loginResponse;
          _ref.read(loginErrorMessageProvider.notifier).state =
              ObdxErrorMapper.messageFromBody(
            loginResponse['body'] ?? loginResponse['rawBody'],
            statusCode: statusCode,
            l10n: l10n,
          );
        }
      }
    }
  }
}

class OtpLoginScreenVm {
  OtpLoginScreenVm(this._ref);

  final Ref _ref;

  Future<ResponseHandler<LoginTrace>?> submitOtp({
    required OtpLoginPending pending,
    required String otp,
  }) async {
    _ref.read(otpIsLoadingProvider.notifier).state = true;
    _ref.read(otpErrorMessageProvider.notifier).state = null;

    try {
      final result = await _ref.read(authRepositoryProvider).submitLoginOtp(
            pending: pending,
            otp: otp,
          );

      final l10n = await AppLocalizationsHelper.current();

      if (result is Error<LoginTrace>) {
        _ref.read(otpErrorMessageProvider.notifier).state =
            result.resolveUserMessage(
                l10n: l10n, fallback: l10n.errorOtpInvalid);
      } else if (result is NetworkError<LoginTrace>) {
        _ref.read(otpErrorMessageProvider.notifier).state =
            result.resolveUserMessage(l10n: l10n);
      } else if (result is ExceptionError<LoginTrace>) {
        _ref.read(otpErrorMessageProvider.notifier).state =
            result.resolveUserMessage(l10n: l10n);
      }

      return result;
    } catch (_) {
      final l10n = await AppLocalizationsHelper.current();
      _ref.read(otpErrorMessageProvider.notifier).state = l10n.errorUnexpected;
      return null;
    } finally {
      _ref.read(otpIsLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> resendOtp({
    required OtpLoginPending pending,
  }) async {
    _ref.read(otpIsLoadingProvider.notifier).state = true;
    _ref.read(otpErrorMessageProvider.notifier).state = null;

    try {
      final result = await _ref.read(authRepositoryProvider).resendLoginOtp(
            pending: pending,
          );

      final l10n = await AppLocalizationsHelper.current();

      if (result is Success<void>) {
        return true;
      }
      if (result is Error<void>) {
        _ref.read(otpErrorMessageProvider.notifier).state =
            result.resolveUserMessage(
                l10n: l10n, fallback: l10n.errorOtpInvalid);
      } else if (result is NetworkError<void>) {
        _ref.read(otpErrorMessageProvider.notifier).state =
            result.resolveUserMessage(l10n: l10n);
      } else if (result is ExceptionError<void>) {
        _ref.read(otpErrorMessageProvider.notifier).state =
            result.resolveUserMessage(l10n: l10n);
      }
      return false;
    } catch (_) {
      final l10n = await AppLocalizationsHelper.current();
      _ref.read(otpErrorMessageProvider.notifier).state = l10n.errorUnexpected;
      return false;
    } finally {
      _ref.read(otpIsLoadingProvider.notifier).state = false;
    }
  }
}
