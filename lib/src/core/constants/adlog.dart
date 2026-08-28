import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/core/utils/log_redactor.dart';

void adLog(String message) {
  if (kDebugMode) {
    debugPrint(LogRedactor.redact(message));
  }
}

void adLogError(Object error, [StackTrace? stackTrace]) {
  if (!kDebugMode) return;
  adLog('Error: ${error.runtimeType}');
  adLog(LogRedactor.redact(error.toString()));
  if (stackTrace != null) {
    adLog(LogRedactor.redact(stackTrace.toString()));
  }
}
