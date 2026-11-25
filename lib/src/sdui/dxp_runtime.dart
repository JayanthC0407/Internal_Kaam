import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dxp_api.dart';
import 'dxp_cache.dart';
import 'dxp_config.dart';
import 'live/browser_sse.dart';
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

/// What a connection attempt found.
enum _Online { connected, unreachable, refused }

/// A screen whose hash is not the one its manifest lists.
class _StaleScreen implements Exception {
  const _StaleScreen();
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
/// published configuration as one change: on a live signal (SSE, every
/// platform), on every app resume, and on a slow fallback check while the
/// live channel is down.
class DxpRuntime extends ChangeNotifier with WidgetsBindingObserver {
  DxpRuntime({DxpApi? api, bool? enabled, bool live = true, DxpCache cache = const DxpCache()})
      : _api = api ?? DxpApi(),
        _enabled = enabled ?? DxpConfig.isOn,
        _liveEnabled = live,
        _cache = cache;

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

  /// Opens the platform session (CONTRACT-OBDX §1.1). Never throws.
  ///
  /// When the platform cannot be reached, the last good configuration saved
  /// on this device is drawn instead ([offline]) and the platform is retried
  /// quietly; with no saved copy, or when the platform refuses the app (a
  /// wrong key, a user type out of scope), the app stays native.
  Future<void> start({
    required DxpHost host,
    required String userId,
    required String userType,
    String? segment,
  }) async {
    if (!_enabled || status == DxpStatus.starting) return;
    this.host = host;
    status = DxpStatus.starting;
    _userType = userType;
    _session = {
      'contract': DxpConfig.contract,
      'userType': userType,
      'segment': segment ?? userType,
      'userRef': userRefFor(userId),
      'deviceId': await _deviceId(),
      'platform': _platformName(),
      'appVersion': DxpConfig.appVersion,
      'widgets': supportedWidgets,
    };
    final outcome = await _goOnline();
    if (outcome == _Online.unreachable && await _restoreCache()) {
      debugPrint('DXP offline: drawing the saved configuration');
      offline = true;
      status = DxpStatus.ready;
      WidgetsBinding.instance.addObserver(this);
      _scheduleReconnect();
    } else if (outcome != _Online.connected) {
      status = DxpStatus.unavailable;
    }
    notifyListeners();
  }

  /// Drawing the saved configuration because the platform is unreachable.
  /// New releases arrive once it answers again.
  bool offline = false;

  String? _userType;
  Map<String, dynamic>? _session;
  Timer? _reconnectTimer;

  /// Handshake + manifest. On success the runtime is [DxpStatus.ready] and
  /// live; the platform's answer is saved for offline use.
  Future<_Online> _goOnline() async {
    final body = _session;
    if (body == null) return _Online.refused;
    try {
      _token = await _api.openSession(body);
      await _checkManifest();
      await _prefetchAndSave();
      final wasOffline = offline;
      offline = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      if (status != DxpStatus.ready || wasOffline) {
        status = DxpStatus.ready;
        WidgetsBinding.instance.removeObserver(this);
        WidgetsBinding.instance.addObserver(this);
        if (_liveEnabled) {
          _startLive();
          _flushTimer?.cancel();
          _flushTimer = Timer.periodic(const Duration(seconds: 3), (_) => flush());
        }
      }
      return _Online.connected;
    } catch (e) {
      debugPrint('DXP unavailable: $e');
      _token = null;
      final code = e is DioException ? e.response?.statusCode : null;
      // The platform answered and said no: that is a decision, not an outage.
      return code != null && code >= 400 && code < 500
          ? _Online.refused
          : _Online.unreachable;
    }
  }

  /// While [offline]: try the platform again every minute (and on resume).
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_liveEnabled) return;
    _reconnectTimer = Timer.periodic(const Duration(minutes: 1), (_) => _reconnectPlatform());
  }

  bool _reconnecting = false;

  Future<void> _reconnectPlatform() async {
    if (!offline || _reconnecting) return;
    _reconnecting = true;
    try {
      final outcome = await _goOnline();
      if (outcome == _Online.connected) {
        notifyListeners();
      } else if (outcome == _Online.refused) {
        // The platform now refuses this app: stop drawing its old designs.
        await stop();
      }
    } finally {
      _reconnecting = false;
    }
  }

  // ------------------------------------------------------- device cache

  final DxpCache _cache;

  Future<bool> _restoreCache() async {
    final userType = _userType;
    if (userType == null) return false;
    final saved = await _cache.load(userType);
    if (saved == null) return false;
    _manifest = saved.manifest;
    _etag = saved.etag;
    theme = DxpTheme.fromJson(
      saved.manifest['theme'] is Map ? Map<String, dynamic>.from(saved.manifest['theme']) : null,
    );
    _screens
      ..clear()
      ..addAll(saved.screens);
    revision++;
    return true;
  }

  /// Fetches every screen the manifest names (so all of them work offline),
  /// then saves the whole configuration. A screen that fails is simply left
  /// out of the saved copy.
  Future<void> _prefetchAndSave() async {
    final token = _token;
    final userType = _userType;
    if (token == null || userType == null) return;
    for (final id in _screenHashes.keys) {
      if (_screens.containsKey(id)) continue;
      try {
        _screens[id] = await _fetchScreen(token, id, _manifest);
      } catch (_) {}
    }
    await _cache.save(
      userType,
      DxpCachedConfig(manifest: _manifest, screens: Map.of(_screens), etag: _etag),
    );
  }

  /// Ends the platform session (OBDX logout or the dashboard closing). The
  /// OBDX session is not touched.
  Future<void> stop() async {
    final token = _token;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    offline = false;
    _session = null;
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
        // Keep the device copy in step with what is now on screen.
        await _prefetchAndSave();
      }
    } catch (e) {
      // Keep drawing the last good configuration.
      debugPrint('DXP manifest check failed: $e');
    }
  }

  /// [_checkManifestOnce], retried once if a screen turned out to belong to
  /// a different release than the manifest (a release published mid-way).
  Future<bool> _checkManifest() async {
    try {
      return await _checkManifestOnce();
    } on _StaleScreen {
      return _checkManifestOnce();
    }
  }

  /// Fetches screen [id] as it stood in [manifest]'s release, and checks it
  /// against the hash the manifest lists (CONTRACT-OBDX §2). A mismatch
  /// throws [_StaleScreen]: the screen and the manifest must never come from
  /// two different releases.
  Future<Map<String, dynamic>> _fetchScreen(
    String token,
    String id,
    Map<String, dynamic> manifest,
  ) async {
    final release = manifest['releaseNo'];
    final doc = await _api.screen(
      token,
      id,
      release: release is num ? release.toInt() : int.tryParse('${release ?? ''}'),
    );
    final listed = manifest['screens'] is Map ? (manifest['screens'] as Map)[id]?.toString() : null;
    if (doc.hash != null && listed != null && doc.hash != listed) {
      throw const _StaleScreen();
    }
    return doc.json;
  }

  Future<bool> _checkManifestOnce() async {
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
        fetched[entry.key] = await _fetchScreen(token, entry.key, next);
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
    return _inFlight[id] ??= _fetchScreen(token, id, _manifest).then((doc) {
      _screens[id] = doc;
      return doc;
    }, onError: (Object e) {
      // A newer release exists: catch up, then the screen loads from it.
      if (e is _StaleScreen) refresh();
      throw e;
    }).whenComplete(() => _inFlight.remove(id));
  }

  /// Cached copy only, for drawing without a loading flash.
  Map<String, dynamic>? cachedScreen(String id) => _screens[id];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (offline) {
        _reconnectPlatform();
        return;
      }
      refresh();
      if (_liveEnabled && _live == null && _browserLive == null) _connect();
    }
  }

  // --------------------------------------------------------------- live
  //
  // "Push a signal, pull the delta" (DXP blueprint §7.2): a Server-Sent
  // Events channel tells the app a release was published, and the app then
  // checks the manifest (ETag) and fetches only what changed. SSE on every
  // platform: the browser's EventSource on web, a Dio stream elsewhere.
  // Safety nets: a check on every resume, and a slow poll that only runs
  // while the channel is down.

  CancelToken? _live;
  StreamSubscription<String>? _liveSub;
  BrowserSse? _browserLive;
  Timer? _poll;
  Timer? _retry;
  int _attempt = 0;
  final Random _random = Random();

  /// True while the live channel is open and receiving.
  bool liveConnected = false;

  /// The fallback poll's interval. Slow on purpose: it only runs while the
  /// live channel is down, and every app polling often costs the platform
  /// a steady stream of requests for nothing.
  static const fallbackPollInterval = Duration(minutes: 5);

  static const _liveEvents = ['hello', 'config.published', 'session.revoked'];

  void _startLive() {
    _poll ??= Timer.periodic(fallbackPollInterval, (_) {
      if (!liveConnected) refresh();
    });
    _connect();
  }

  Future<void> _connect() async {
    final token = _token;
    if (token == null) return;
    // A resume may connect before a scheduled retry: never hold two.
    _retry?.cancel();
    _retry = null;
    if (kIsWeb) {
      _browserLive?.close();
      _browserLive = openBrowserSse(
        _api.liveUrl(token),
        events: _liveEvents,
        onOpen: _onLiveOpen,
        onEvent: (event, data) {
          _onLiveOpen();
          _onLive(event, data);
        },
        onClosed: _reconnect,
      );
      if (_browserLive != null) return;
    }
    final cancel = CancelToken();
    _live = cancel;
    String? event;
    try {
      final lines = await _api.live(token, cancel);
      _liveSub = lines.listen(
        (line) {
          _onLiveOpen(); // any line, pings included, proves the channel works
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

  void _onLiveOpen() {
    liveConnected = true;
    _attempt = 0;
  }

  void _onLive(String event, String data) {
    switch (event) {
      case 'hello':
        try {
          final v = _asInt((jsonDecode(data) as Map)['configVersion']);
          if (v > configVersion) _refreshSoon();
        } catch (_) {}
      case 'config.published':
        _refreshSoon();
      case 'session.revoked':
        // Ends DXP only; the customer stays logged in to OBDX (§8).
        stop();
    }
  }

  /// Refresh after a short random delay (up to 1.5 s), so that a release,
  /// or the platform coming back, does not make every app fetch in the same
  /// instant.
  void _refreshSoon() {
    Timer(Duration(milliseconds: _random.nextInt(1500)), refresh);
  }

  void _reconnect() {
    liveConnected = false;
    _liveSub?.cancel();
    _liveSub = null;
    _live = null;
    _browserLive?.close();
    _browserLive = null;
    if (_token == null) return;
    _retry?.cancel();
    // Back-off 2, 4, 8, 16, 30 s, each plus up to half again at random, so
    // apps that lost the platform together do not all return together.
    final base = min(30, 2 << _attempt.clamp(0, 4));
    final wait = Duration(milliseconds: base * 1000 + _random.nextInt(base * 500));
    _attempt++;
    _retry = Timer(wait, _connect);
  }

  void _stopLive() {
    liveConnected = false;
    _retry?.cancel();
    _retry = null;
    _poll?.cancel();
    _poll = null;
    _liveSub?.cancel();
    _liveSub = null;
    _live?.cancel();
    _live = null;
    _browserLive?.close();
    _browserLive = null;
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
