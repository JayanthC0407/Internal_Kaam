import 'dart:convert';

import 'package:dio/dio.dart';

import 'dxp_config.dart';

/// Result of a manifest check: [notModified] for a 304.
class DxpManifestResult {
  const DxpManifestResult.notModified()
      : notModified = true,
        manifest = null,
        etag = null;

  const DxpManifestResult.changed(Map<String, dynamic> this.manifest, this.etag)
      : notModified = false;

  final bool notModified;
  final Map<String, dynamic>? manifest;
  final String? etag;
}

/// A screen document and the platform's hash of it (null from a platform
/// that does not send one).
class DxpScreenDoc {
  const DxpScreenDoc(this.json, this.hash);

  final Map<String, dynamic> json;
  final String? hash;
}

/// The platform's App API (`/api/app/v1`, CONTRACT-OBDX §1).
///
/// Its own Dio client, separate from the OBDX one: no OBDX cookies, headers
/// or interceptors ever reach the platform (CONTRACT-OBDX rule 0.2).
class DxpApi {
  DxpApi({Dio? dio}) : _injected = dio;

  final Dio? _injected;

  /// Created on first use: with DXP off there is no base URL, and Dio
  /// refuses an empty one on mobile, so building it eagerly would break
  /// the app that DXP must leave untouched (CONTRACT-OBDX rule 0.4).
  late final Dio _dio = _injected ??
      Dio(BaseOptions(
        baseUrl: '${DxpConfig.baseUrl}/api/app/v1',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        // 304 is a normal answer to a manifest check.
        validateStatus: (s) => s != null && s >= 200 && s < 400,
      ));

  Options _auth(String token, {Map<String, String>? extra}) =>
      Options(headers: {'Authorization': 'Bearer $token', ...?extra});

  /// §1.1 session handshake. Returns the platform token.
  Future<String> openSession(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/session',
      data: body,
      options: Options(headers: {'X-DXP-App-Key': DxpConfig.appKey}),
    );
    final token = res.data?['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('Platform session has no token');
    }
    return token;
  }

  Future<void> endSession(String token) async {
    await _dio.post<dynamic>('/session/end', options: _auth(token));
  }

  /// Manifest with `If-None-Match` (§2, prototype §2).
  Future<DxpManifestResult> manifest(String token, {String? etag}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/manifest',
      options: _auth(token, extra: {if (etag != null) 'If-None-Match': etag}),
    );
    if (res.statusCode == 304) return const DxpManifestResult.notModified();
    return DxpManifestResult.changed(
      res.data ?? const <String, dynamic>{},
      res.headers.value('etag'),
    );
  }

  /// A screen as it stood in [release] (the manifest's `releaseNo`), with the
  /// hash the platform computed for it (CONTRACT-OBDX §2).
  Future<DxpScreenDoc> screen(String token, String id, {int? release}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/screens/${Uri.encodeComponent(id)}',
      queryParameters: {if (release != null) 'release': release},
      options: _auth(token),
    );
    return DxpScreenDoc(
      res.data ?? const <String, dynamic>{},
      res.headers.value('x-dxp-screen-hash'),
    );
  }

  Future<void> postEvents(String token, List<Map<String, dynamic>> events) async {
    await _dio.post<dynamic>(
      '/events',
      data: {'events': events},
      options: _auth(token),
    );
  }

  /// The live channel's address, for the browser's own EventSource on web
  /// (Dio cannot stream a response there). The platform token goes in the
  /// query because EventSource cannot send headers (prototype §8).
  String liveUrl(String token) =>
      '${DxpConfig.baseUrl}/api/app/v1/live?token=${Uri.encodeQueryComponent(token)}';

  /// Server-Sent Events as text lines (§8), on Android and iOS.
  Future<Stream<String>> live(String token, CancelToken cancel) async {
    final res = await _dio.get<ResponseBody>(
      '/live',
      queryParameters: {'token': token},
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
        headers: {'Accept': 'text/event-stream'},
      ),
    );
    final body = res.data;
    if (body == null) return const Stream<String>.empty();
    return body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }
}
