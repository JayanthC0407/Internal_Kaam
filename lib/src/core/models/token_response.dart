class TokenResponse {
  TokenResponse({
    required this.accessToken,
    this.tokenType = 'Bearer',
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: (json['token'] ??
              json['accessToken'] ??
              json['jwtToken'] ??
              '')
          .toString(),
      tokenType: (json['tokenType'] ?? 'Bearer').toString(),
    );
  }

  final String accessToken;
  final String tokenType;

  String get getTokenType => tokenType;

  Map<String, dynamic> toJson() => {
        'token': accessToken,
        'tokenType': tokenType,
      };
}
