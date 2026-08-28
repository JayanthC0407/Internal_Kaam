/// Normalized OBDX / HTTP failure for repositories and view models.
class ObdxError {
  const ObdxError({
    required this.category,
    required this.userMessage,
    this.l10nKey,
    this.httpStatusCode,
    this.obdxCode,
    this.detail,
    this.requestId,
  });

  final ObdxErrorCategory category;
  final String? l10nKey;
  final int? httpStatusCode;
  final String? obdxCode;
  final String? detail;
  final String userMessage;
  final String? requestId;

  bool get isNetworkIssue =>
      category == ObdxErrorCategory.network ||
      category == ObdxErrorCategory.timeout;

  bool get isAuthFailure => category == ObdxErrorCategory.unauthorized;
}

enum ObdxErrorCategory {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  cancelled,
  certificate,
  unknown,
}
