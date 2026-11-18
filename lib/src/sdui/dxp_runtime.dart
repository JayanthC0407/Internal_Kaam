import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dxp_api.dart';
import 'dxp_config.dart';
import 'render/widgets/widget_registry.dart';
import 'theme/dxp_theme.dart';

/// What the host app lends the runtime: its data, its screens and the
/// signed-in customer's display name. The runtime itself knows nothing about
/// OBDX or Retail (CONTRACT-OBDX §6, §7); the Retail binding implements this.
abstract class DxpHost {
  /// Data for a source name, in the shapes of CONTRACT-OBDX §6, or null when
  /// the source is unknown or its call failed.
  Future<dynamic> resolveData(String source);

  /// Opens an existing screen for a `nativeRoute` route. False when the
  /// route is not in this app's route table.
  bool openNative(String route);

  /// `customer` in the render context: display fields only.
  Map<String, dynamic> get customer;

  /// The app's own widgets a screen may place by name (`AppWidget`).
  Map<String, Widget Function()> get appWidgets;
}

enum DxpStatus {
  /// Flag off, or not started: the app is today's app.
  off,
  starting,
  ready,

  /// The platform could not be reached or refused us. Same as [off] for the
  /// user (CONTRACT-OBDX rule 0.4); kept apart so it can be logged.
  unavailable,
}

/// The DXP session for one signed-in customer.
///
/// Opens the platform session after the OBDX login, keeps the manifest and
/// the screens it names (cached by content hash), and applies a newly
/// published configuration as one change: on a live signal on mobile, on a
/// 15-second ETag check on web, and on every app resume.
class DxpRuntime extends ChangeNotifier with WidgetsBindingObserver {
  DxpRuntime({DxpApi? api, bool? enabled, bool live = true})
      : _api = api ?? DxpApi(),
        _enabled = enabled ?? DxpConfig.isOn,
        _liveEnabled = live;

  final DxpApi _api;

  /// [DxpConfig.isOn] unless a test says otherwise.
  final bool _enabled;

  /// Live signal and web polling; tests turn them off.
  final bool _liveEnabled;

  DxpStatus status = DxpStatus.off;
  DxpHost? host;

  /// Bumped every time a configuration is applied; screens rebuild on it.
  int revision = 0;

  String? _token;
  String? _etag;
  Map<String, dynamic> _manifest = const {};
  DxpTheme theme = DxpTheme.fallback();
  final Map<String, Map<String, dynamic>> _screens = {};
  final Map<String, Future<Map<String, dynamic>>> _inFlight = {};

  int get configVersion => _asInt(_manifest['configVersion']);
  String? get homeScreen => _manifest['home']?.toString();

  /// Menu entries added to the host's menu (CONTRACT-OBDX §10).
  List<Map<String, dynamic>> get menu {
    final m = _manifest['menu'];
    if (m is! List) return const [];
    return m.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, String> get _screenHashes {
    final s = _manifest['screens'];
    if (s is! Map) return const {};
    return s.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  bool hasScreen(String id) => _screenHashes.containsKey(id);

  /// The published home is the whole Home body (`"layout": "full"`), not a
  /// section above the native one. Known once the home screen is cached,
  /// which [start] does before reporting [DxpStatus.ready].
  bool get homeIsFullLayout {
    final home = homeScreen;
    if (status != DxpStatus.ready || home == null) return false;
    return cachedScreen(home)?['layout'] == 'full';
  }

  // ------------------------------------------------------------ session

  /// Opens the platform session (CONTRACT-OBDX §1.1). Never throws: any
  /// failure leaves the runtime [DxpStatus.unavailable] and the app native.
  Future<void> start({
    required DxpHost host,
    required String userId,
    required String userType,
    String? segment,
  }) async {
    if (!_enabled || status == DxpStatus.starting) return;
    this.host = host;
    status = DxpStatus.starting;
    try {
      _token = await _api.openSession({
        'contract': DxpConfig.contract,
        'userType': userType,
        'segment': segment ?? userType,
        'userRef': userRefFor(userId),
        'deviceId': await _deviceId(),
        'platform': _platformName(),
        'appVersion': DxpConfig.appVersion,
        'widgets': supportedWidgets,
      });
      await _checkManifest();
      status = DxpStatus.ready;
      WidgetsBinding.instance.addObserver(this);
      if (_liveEnabled) {
        _startLive();
        _flushTimer = Timer.periodic(const Duration(seconds: 3), (_) => flush());
      }
    } catch (e) {
      debugPrint('DXP unavailable: $e');
      _token = null;
      status = DxpStatus.unavailable;
    }
    notifyListeners();
  }

  /// Ends the platform session (OBDX logout or the dashboard closing). The
  /// OBDX session is not touched.
  Future<void> stop() async {
    final token = _token;
    _stopLive();
    _flushTimer?.cancel();
    _flushTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    if (token != null) {
      await flush();
      try {
        await _api.endSession(token);
      } catch (_) {
        // The platform token expires by itself.
      }
    }
    _token = null;
    _etag = null;
    _manifest = const {};
    _screens.clear();
    _inFlight.clear();
    host = null;
    status = DxpStatus.off;
    notifyListeners();
  }

  /// `u_` + SHA-256 of salt and OBDX user id: lets the console group one
  /// user's events without knowing who it is (CONTRACT-OBDX §1.1).
  static String userRefFor(String userId) {
    final digest = sha256.convert(
      utf8.encode('${DxpConfig.userRefSalt}:${userId.trim().toLowerCase()}'),
    );
    return 'u_$digest';
  }

  static Future<String> _deviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('dxp.deviceId');
      if (existing != null) return existing;
      final r = Random.secure();
      final id = List.generate(16, (_) => r.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await prefs.setString('dxp.deviceId', id);
      return id;
    } catch (_) {
      return 'unknown';
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'other',
    };
  }

  // ----------------------------------------------------------- manifest

  bool _checking = false;

  /// Checks for a newly published configuration and applies it as one
  /// change. A 304 changes nothing.
  Future<void> refresh() async {
    if (_token == null || _checking) return;
    try {
      final applied = await _checkManifest();
      if (applied) {
        track('CONFIG_APPLIED', payload: {'configVersion': configVersion});
        notifyListeners();
      }
    } catch (e) {
      // Keep drawing the last good configuration.
      debugPrint('DXP manifest check failed: $e');
    }
  }

  Future<bool> _checkManifest() async {
    final token = _token;
    if (token == null) return false;
    _checking = true;
    try {
      final result = await _api.manifest(token, etag: _etag);
      if (result.notModified) return false;
      final next = result.manifest!;
      final oldHashes = _screenHashes;
      // Fetch every changed screen first, then switch over at once.
      final nextHashes = (next['screens'] is Map)
          ? (next['screens'] as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString()))
          : <String, String>{};
      final fetched = <String, Map<String, dynamic>>{};
      for (final entry in nextHashes.entries) {
        if (oldHashes[entry.key] == entry.value &&
            _screens.containsKey(entry.key)) {
          continue;
        }
        if (entry.key != next['home'] && !_screens.containsKey(entry.key)) {
          continue; // fetched lazily when first opened
        }
        fetched[entry.key] = await _api.screen(token, entry.key);
      }
      _manifest = next;
      _etag = result.etag;
      theme = DxpTheme.fromJson(
        next['theme'] is Map ? Map<String, dynamic>.from(next['theme']) : null,
      );
      _screens.removeWhere((id, _) => !nextHashes.containsKey(id));
      for (final id in nextHashes.keys) {
        if (oldHashes[id] != nextHashes[id] && !fetched.containsKey(id)) {
          _screens.remove(id);
        }
      }
      _screens.addAll(fetched);
      revision++;
      return true;
    } finally {
      _checking = false;
    }
  }

  /// A screen document, from cache or the platform.
  Future<Map<String, dynamic>> screen(String id) {
    final cached = _screens[id];
    if (cached != null) return Future.value(cached);
    final token = _token;
    if (token == null) return Future.error(StateError('DXP not started'));
    return _inFlight[id] ??= _api.screen(token, id).then((doc) {
      _screens[id] = doc;
      return doc;
    }).whenComplete(() => _inFlight.remove(id));
  }

  /// Cached copy only, for drawing without a loading flash.
  Map<String, dynamic>? cachedScreen(String id) => _screens[id];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
      if (_liveEnabled && !kIsWeb && _live == null) _startLive();
    }
  }

  // --------------------------------------------------------------- live

  CancelToken? _live;
  StreamSubscription<String>? _liveSub;
  Timer? _poll;
  Timer? _retry;
  int _attempt = 0;

  void _startLive() {
    if (kIsWeb) {
      // Dio cannot stream on web: check the manifest instead. With an ETag
      // an unchanged configuration costs a 304 and no body.
      _poll ??= Timer.periodic(const Duration(seconds: 15), (_) => refresh());
      return;
    }
    _connect();
  }

  Future<void> _connect() async {
    final token = _token;
    if (token == null) return;
    final cancel = CancelToken();
    _live = cancel;
    String? event;
    try {
      final lines = await _api.live(token, cancel);
      _attempt = 0;
      _liveSub = lines.listen(
        (line) {
          if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            _onLive(event ?? 'message', line.substring(5).trim());
          } else if (line.isEmpty) {
            event = null;
          }
        },
        onDone: _reconnect,
        onError: (_) => _reconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _reconnect();
    }
  }

  void _onLive(String event, String data) {
    switch (event) {
      case 'hello':
        try {
          final v = _asInt((jsonDecode(data) as Map)['configVersion']);
          if (v > configVersion) refresh();
        } catch (_) {}
      case 'config.published':
        refresh();
      case 'session.revoked':
        // Ends DXP only; the customer stays logged in to OBDX (§8).
        stop();
    }
  }

  void _reconnect() {
    _liveSub?.cancel();
    _liveSub = null;
    _live = null;
    if (_token == null) return;
    _retry?.cancel();
    final seconds = min(30, 2 << _attempt.clamp(0, 4));
    _attempt++;
    _retry = Timer(Duration(seconds: seconds), _connect);
  }

  void _stopLive() {
    _retry?.cancel();
    _retry = null;
    _poll?.cancel();
    _poll = null;
    _liveSub?.cancel();
    _liveSub = null;
    _live?.cancel();
    _live = null;
  }

  // ------------------------------------------------------------- events

  final List<Map<String, dynamic>> _events = [];
  Timer? _flushTimer;

  /// Queues an event (CONTRACT-OBDX §9: no customer data in [payload]).
  void track(String type, {String? screen, Map<String, dynamic>? payload}) {
    if (_token == null) return;
    _events.add({
      'type': type,
      'ts': DateTime.now().toUtc().toIso8601String(),
      if (screen != null) 'screen': screen,
      'configVersion': configVersion,
      if (payload != null) 'payload': payload,
    });
    if (_events.length >= 20) flush();
  }

  Future<void> flush() async {
    final token = _token;
    if (token == null || _events.isEmpty) return;
    final batch = List<Map<String, dynamic>>.of(_events);
    _events.clear();
    try {
      await _api.postEvents(token, batch);
    } catch (_) {
      // Keep them for the next flush, bounded.
      _events.insertAll(0, batch.take(100));
    }
  }

  static int _asInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  void dispose() {
    _stopLive();
    _flushTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
