import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/l10n/error_localizations.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

extension ResponseHandlerUserMessage<T> on ResponseHandler<T> {
  String resolveUserMessage({
    AppLocalizations? l10n,
    String? fallback,
  }) {
    final generic = fallback ?? l10n?.errorGeneric ?? 'Something went wrong';

    if (this is Error<T>) {
      final error = this as Error<T>;
      if (l10n != null && error.obdxError != null) {
        return l10n.messageForObdxError(error.obdxError!);
      }
      return error.error ?? generic;
    }
    if (this is NetworkError<T>) {
      final networkError = this as NetworkError<T>;
      if (l10n != null && networkError.obdxError != null) {
        return l10n.messageForObdxError(networkError.obdxError!);
      }
      return l10n?.errorNetwork ??
          'Unable to connect. Please check your internet connection and try again.';
    }
    if (this is ExceptionError<T>) {
      return l10n?.errorUnexpected ??
          'An unexpected error occurred. Please try again.';
    }
    return generic;
  }
}
