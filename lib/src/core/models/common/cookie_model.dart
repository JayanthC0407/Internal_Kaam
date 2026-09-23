class CookieModel {
  CookieModel({this.secretKey, this.jsessionId});

  factory CookieModel.fromJson(Map<String, dynamic> json) {
    return CookieModel(
      secretKey: json['secretKey']?.toString(),
      jsessionId: json['jsessionId']?.toString(),
    );
  }

  final String? secretKey;
  final String? jsessionId;

  Map<String, dynamic> toJson() => {
        'secretKey': secretKey,
        'jsessionId': jsessionId,
      };
}
