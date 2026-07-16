import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models.dart';
import 'notification_service.dart';
import 'direct_device_service.dart';

const _kWifiUrl   = 'wifi_url';
const _kMobileUrl = 'mobile_url';
const _kServerKey = 'server_url'; // legacy fallback
const _kAuthToken = 'auth_token';
const _kDirectMode = 'direct_mode';
const _kDirectIp   = 'direct_ip';

const defaultWifiUrl   = 'http://nperiannan-nas.freemyip.com:1880';
const defaultMobileUrl = 'http://nperiannan-nas.freemyip.com:1880';

const mobileAppVersion = '2.10.1';

class TankService extends ChangeNotifier {
  // ── Auth ─────────────────────────────────────────────────────────────────
  String? authToken;
  bool unauthorized = false;
  Device? currentDevice;
  bool isAdmin = false;
  String? currentUsername;

  // ── Version info ────────────────────────────────────────────────────
  String? webAppVersion;

  // ── Update check ─────────────────────────────────────────────────────────
  String? latestAppVersion;
  bool updateAvailable = false;
  String? latestApkUrl;  // ── URL configuration ────────────────────────────────────────────────────
  String wifiUrl   = defaultWifiUrl;
  String mobileUrl = defaultMobileUrl;
  String _activeUrl = '';

  // ── Direct mode (ESP32 HTTP API) ─────────────────────────────────────────
  bool directMode = false;
  String directIp = '';
  DirectDeviceService? _directService;
  Timer? _pollTimer;

  Status? status;
  bool connected = false;
  bool connecting = false; // true while the first WS handshake is in flight
  String? error;

  // ── Motor notification tracking ──────────────────────────────────────────
  bool _prevUgMotor = false;
  bool _prevOhMotor = false;
  bool _hasReceivedFirstStatus = false;
  bool motorNotifyEnabled = false;

  // Optimistic setting overrides: status-JSON key → {value, expiresAt}.
  // Applied in the WS listener so the UI doesn't flicker back to the old
  // value when a stale status arrives before the ESP32 processes the change.
  final Map<String, _PendingSetting> _pendingSettings = {};
  Map<String, dynamic>? _lastRawStatus; // last received WS payload (pre-pending)

  // Cached WiFi list (per active device) so the WiFi card shows instantly and
  // refreshes in the background instead of reloading blank on every expand.
  Map<String, dynamic>? _wifiCache;
  bool _wifiCacheLoaded = false;
  Timer? _wifiPollTimer;
  Map<String, dynamic>? get wifiCache => _wifiCache;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  StreamSubscription? _netSub;
  bool _disposed = false;
  bool _reconnecting = false;

  String get serverUrl => _activeUrl;

  // ── Persistence ─────────────────────────────────────────────────────────

  Future<void> loadSavedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    wifiUrl   = prefs.getString(_kWifiUrl)
              ?? prefs.getString(_kServerKey)  // legacy single-URL migration
              ?? defaultWifiUrl;
    mobileUrl = prefs.getString(_kMobileUrl) ?? defaultMobileUrl;
    directMode = prefs.getBool(_kDirectMode) ?? false;
    directIp   = prefs.getString(_kDirectIp) ?? '';
  }

  // Legacy compat used by old startup path
  Future<String?> loadSavedUrl() async {
    await loadSavedUrls();
    return wifiUrl.isNotEmpty ? wifiUrl : null;
  }

  Future<void> saveUrls({String? wifi, String? mobile}) async {
    if (wifi   != null) wifiUrl   = wifi.trimRight().replaceAll(RegExp(r'/$'), '');
    if (mobile != null) mobileUrl = mobile.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWifiUrl,   wifiUrl);
    await prefs.setString(_kMobileUrl, mobileUrl);
  }

  Future<void> saveDirectMode(bool enabled, String ip) async {
    directMode = enabled;
    directIp   = ip.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDirectMode, directMode);
    await prefs.setString(_kDirectIp, directIp);
  }

  // ── Auth persistence ─────────────────────────────────────────────────────

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString(_kAuthToken);
  }

  Future<bool> login(String username, String password) async {
    error = null;
    try {
      final url = await _pickUrl();
      final res = await http.post(
        Uri.parse('$url/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        authToken = data['token'] as String?;
        if (authToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kAuthToken, authToken!);
          isAdmin = data['is_admin'] as bool? ?? false;
          currentUsername = data['username'] as String?;
          unauthorized = false;
          notifyListeners();
          return true;
        }
      }
      error = res.statusCode == 401 ? 'Invalid username or password' : 'Login failed (${res.statusCode})';
      notifyListeners();
      return false;
    } catch (e) {
      error = 'Cannot reach server: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    authToken = null;
    currentDevice = null;
    isAdmin = false;
    currentUsername = null;
    unauthorized = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthToken);
    disconnect();
    notifyListeners();
  }

  // ── Network detection ────────────────────────────────────────────────────

  /// Returns the active URL, picking based on connectivity if WS not yet connected.
  Future<String> _resolveUrl() async {
    if (_activeUrl.isNotEmpty) return _activeUrl;
    await loadSavedUrls();
    final url = await _pickUrl();
    return url.trimRight().replaceAll(RegExp(r'/$'), '');
  }

  /// Builds a per-device path when a device is selected, falling back to legacy.
  String _devicePath(String legacy, String sub) {
    final mac = currentDevice?.mac;
    return mac != null ? '/api/devices/$mac/$sub' : legacy;
  }

  Future<String> _pickUrl() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ? wifiUrl : mobileUrl;
  }

  // ── Auto-connect (always picks URL based on current network) ─────────────

  Future<void> connectAuto() async {
    // In direct mode, use polling instead of WebSocket
    if (directMode && directIp.isNotEmpty) {
      connectDirect(directIp);
      return;
    }

    final url = await _pickUrl();
    connect(url);

    // React to network changes (WiFi ↔ mobile) while app is open
    _netSub?.cancel();
    _netSub = Connectivity().onConnectivityChanged.listen((results) async {
      if (_disposed) return;
      final newUrl = results.contains(ConnectivityResult.wifi) ? wifiUrl : mobileUrl;
      if (newUrl != _activeUrl) {
        connect(newUrl); // switch and reconnect with correct URL
      }
    });
  }

  // ── Direct mode (ESP32 HTTP polling) ─────────────────────────────────────

  void connectDirect(String ip) {
    disconnect();
    final base = ip.startsWith('http') ? ip : 'http://$ip';
    _activeUrl = base;
    _directService = DirectDeviceService(base);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollOnce(); // immediate first poll
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_disposed || _directService == null) return;
    try {
      final s = await _directService!.fetchStatus();
      if (_disposed) return;
      if (s != null) {
        status = s;
        _checkMotorStateChange();
        if (!connected) connected = true;
        error = null;
      } else {
        connected = false;
      }
    } catch (_) {
      connected = false;
    }
    notifyListeners();
  }

  /// Expose a direct service for screens that need controller HTTP APIs
  /// (WiFi management, history, MQTT config, factory reset).
  /// In direct mode, returns the active service.
  /// In cloud mode, creates one on-the-fly from the device's IP if available.
  DirectDeviceService? get directService {
    if (_directService != null) return _directService;
    final ip = status?.mgmtIp;
    if (ip != null && ip.isNotEmpty) {
      return DirectDeviceService('http://$ip');
    }
    return null;
  }

  // ── WebSocket ────────────────────────────────────────────────────────────

  /// Fetches the backend's last-known device status over REST so the dashboard
  /// can show data and "Live" immediately, without waiting for the WS handshake.
  Future<void> _primeStatusFromBackend() async {
    if (directMode) return;
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      final res = await http.get(
        Uri.parse('$_activeUrl${_devicePath('/api/status', 'status')}'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));
      if (_disposed || connected) return; // WS already took over
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body) as Map<String, dynamic>;
        if (raw.containsKey('oh_state') || raw.containsKey('ug_state')) {
          _lastRawStatus = raw;
          status = Status.fromJson(_applyPending(Map<String, dynamic>.from(raw)));
          connected = true; // backend reachable + has device data
          connecting = false;
          fetchVersion(); // web app version (WS handler would otherwise skip it)
          fetchMe();      // isAdmin + username
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void connect(String url) {
    _reconnecting = false;
    _closeChannel();
    _activeUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    webAppVersion = null; // reset on reconnect
    connecting = true; // show "Connecting…" instead of a false "Offline"
    notifyListeners();
    // Immediately pull the last-known status from the backend so the dashboard
    // shows data (and "Live") right away instead of waiting for the WebSocket.
    _primeStatusFromBackend();

    var wsUrl = _activeUrl
        .replaceFirst(RegExp(r'^http://'), 'ws://')
        .replaceFirst(RegExp(r'^https://'), 'wss://');

    final mac = currentDevice?.mac;
    final wsPath = mac != null ? '/ws/$mac' : '/ws';
    if (authToken != null) {
      wsUrl = '$wsUrl$wsPath?token=${Uri.encodeComponent(authToken!)}';
    } else {
      wsUrl = '$wsUrl$wsPath';
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _sub = _channel!.stream.listen(
        (data) {
          if (_disposed) return;
          try {
            final raw = jsonDecode(data as String) as Map<String, dynamic>;
            _lastRawStatus = raw; // store pre-pending snapshot
            status = Status.fromJson(_applyPending(raw));
            _checkMotorStateChange();
            if (!connected) {
              connected = true;
              connecting = false;
              fetchVersion(); // fire and forget
              fetchMe();      // restore isAdmin + currentUsername from token
            }
            error = null;
            notifyListeners();
          } catch (_) {}
        },
        onError: (e) {
          if (_disposed) return;
          // Detect 401 unauthorized from WS upgrade failure
          final msg = e.toString().toLowerCase();
          if (msg.contains('401') || msg.contains('unauthorized')) {
            unauthorized = true;
            authToken = null;
            SharedPreferences.getInstance().then((p) => p.remove(_kAuthToken));
            connected = false;
            connecting = false;
            notifyListeners();
            return;
          }
          connected = false;
          connecting = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          if (_disposed) return;
          connected = false;
          connecting = false;
          notifyListeners();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (_disposed) return;
      connected = false;
      connecting = false;
      error = e.toString();
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnecting) return;
    _reconnecting = true;
    Future.delayed(const Duration(seconds: 5), () {
      if (_disposed || !_reconnecting) return;
      _reconnecting = false;
      connectAuto(); // re-detect network on every reconnect attempt
    });
  }

  void _closeChannel() {
    _sub?.cancel();
    _channel?.sink.close();
    _sub = null;
    _channel = null;
  }

  void disconnect() {
    _reconnecting = false;
    _netSub?.cancel();
    _netSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _directService = null;
    _closeChannel();
    connected = false;
    status = null;
    notifyListeners();
  }

  /// Call this when app comes back to foreground
  void reconnectIfNeeded() {
    if (!_disposed && !connected && !_reconnecting) {
      connectAuto();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _wifiPollTimer?.cancel();
    disconnect();
    super.dispose();
  }

  // ── Multi-device management ────────────────────────────────────────────

  Future<void> connectToDevice(Device device) async {
    currentDevice = device;
    // Reset per-device WiFi cache so the new device loads its own.
    _wifiCache = null;
    _wifiCacheLoaded = false;
    await connectAuto();
  }

  Future<bool> register(String username, String password) async {
    error = null;
    try {
      final baseUrl = await _resolveUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        authToken = data['token'] as String?;
        if (authToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kAuthToken, authToken!);
          isAdmin = data['is_admin'] as bool? ?? false;
          currentUsername = data['username'] as String?;
          unauthorized = false;
          notifyListeners();
          return true;
        }
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      error = (body['error'] as String?) ?? 'Registration failed (${res.statusCode})';
      notifyListeners();
      return false;
    } catch (e) {
      error = 'Cannot reach server: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<List<Device>> listDevices() async {
    try {
      final baseUrl = await _resolveUrl();
      if (authToken == null) return [];
      final res = await http.get(
        Uri.parse('$baseUrl/api/devices'),
        headers: {'Authorization': 'Bearer $authToken'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (res.statusCode == 401) {
        unauthorized = true;
        authToken = null;
        SharedPreferences.getInstance().then((p) => p.remove(_kAuthToken));
        notifyListeners();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> claimDevice(String mac, String displayName, {String? typeId}) async {
    error = null;
    try {
      final baseUrl = await _resolveUrl();
      final body = <String, dynamic>{
        'mac': mac.toUpperCase(),
        'display_name': displayName,
        if (typeId != null && typeId.isNotEmpty) 'type_id': typeId,
      };
      final res = await http.post(
        Uri.parse('$baseUrl/api/devices/claim'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      final errBody = jsonDecode(res.body) as Map<String, dynamic>;
      error = (errBody['error'] as String?) ?? 'Claim failed (${res.statusCode})';
      notifyListeners();
      return false;
    } catch (e) {
      error = 'Cannot reach server: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameDevice(String mac, String displayName) async {
    error = null;
    try {
      final baseUrl = await _resolveUrl();
      final res = await http.patch(
        Uri.parse('$baseUrl/api/devices/$mac'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'display_name': displayName}),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unclaimDevice(String mac) async {
    error = null;
    try {
      final baseUrl = await _resolveUrl();
      final res = await http.delete(
        Uri.parse('$baseUrl/api/devices/${mac.toUpperCase()}'),
        headers: {
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));
      // 200/204 = removed; 404 = already not in your list → goal achieved.
      if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) {
        return true;
      }
      error = 'Remove failed (HTTP ${res.statusCode})';
      notifyListeners();
      return false;
    } catch (e) {
      error = 'Cannot reach server: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ── Control API ──────────────────────────────────────────────────────────
  Future<void> fetchVersion() async {
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      final res = await http.get(
        Uri.parse('$_activeUrl/api/version'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        webAppVersion = data['web_version'] as String?;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Refresh isAdmin + currentUsername from the server using the saved token.
  /// Called on every WS first-connect so the values are correct even after
  /// the app is re-opened with a persisted token (no fresh login).
  Future<void> fetchMe() async {
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      final res = await http.get(
        Uri.parse('$_activeUrl/api/auth/me'),
        headers: headers,
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        isAdmin = data['is_admin'] as bool? ?? false;
        currentUsername = data['username'] as String?;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> checkForUpdate() async {
    try {
      // Fetch all releases and find the latest MobileApp/ tag
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/nperiannan/TankMonitor/releases?per_page=20'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final releases = jsonDecode(res.body) as List<dynamic>;
        for (final r in releases) {
          final tagName = (r['tag_name'] as String?) ?? '';
          if (!tagName.startsWith('MobileApp/')) continue;
          // Strip "MobileApp/v" or "MobileApp/" prefix
          final tag = tagName.replaceFirst('MobileApp/', '').replaceFirst('v', '');
          final assets = r['assets'] as List<dynamic>? ?? [];
          for (final a in assets) {
            if ((a['name'] as String).endsWith('.apk')) {
              latestApkUrl = a['browser_download_url'] as String;
              break;
            }
          }
          latestAppVersion = tag;
          updateAvailable = _isNewerVersion(tag, mobileAppVersion);
          notifyListeners();
          break; // first matching MobileApp/ release is the latest
        }
      }
    } catch (_) {}
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final l = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      for (var i = 0; i < 3; i++) {
        final lv = i < l.length ? l[i] : 0;
        final cv = i < c.length ? c[i] : 0;
        if (lv > cv) return true;
        if (lv < cv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
  Future<bool> uploadFirmware(
    List<int> bytes, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final uri = Uri.parse('$_activeUrl${_devicePath('/api/ota/upload', 'ota/upload')}');
      const boundary = '----TankMonitorOTABoundary';
      final headerStr =
          '--$boundary\r\nContent-Disposition: form-data; name="firmware"; filename="firmware.bin"\r\nContent-Type: application/octet-stream\r\n\r\n';
      final footerStr = '\r\n--$boundary--\r\n';
      final headerBytes = utf8.encode(headerStr);
      final footerBytes = utf8.encode(footerStr);
      final total = headerBytes.length + bytes.length + footerBytes.length;

      final request = http.StreamedRequest('POST', uri);
      request.headers['Content-Type'] = 'multipart/form-data; boundary=$boundary';
      request.headers['Content-Length'] = '$total';
      request.contentLength = total;
      if (authToken != null) request.headers['Authorization'] = 'Bearer $authToken';

      // Stream chunks and report upload progress
      Future.microtask(() async {
        request.sink.add(headerBytes);
        const chunkSize = 65536;
        int sent = headerBytes.length;
        for (int i = 0; i < bytes.length; i += chunkSize) {
          final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          request.sink.add(bytes.sublist(i, end));
          sent += (end - i);
          onProgress?.call(sent / total);
          await Future.delayed(Duration.zero);
        }
        request.sink.add(footerBytes);
        await request.sink.close();
      });

      final client = http.Client();
      try {
        final response =
            await client.send(request).timeout(const Duration(minutes: 5));
        final body = await response.stream.bytesToString();
        if (response.statusCode == 401) {
          unauthorized = true;
          authToken = null;
          SharedPreferences.getInstance()
              .then((p) => p.remove(_kAuthToken));
          notifyListeners();
          return false;
        }
        if (response.statusCode == 200) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          return data['ok'] == true;
        }
        return false;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> triggerOta() async {
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      await http.post(
        Uri.parse('$_activeUrl${_devicePath('/api/ota/trigger', 'ota/trigger')}'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> triggerRollback() async {
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      await http.post(
        Uri.parse('$_activeUrl${_devicePath('/api/ota/rollback', 'ota/rollback')}'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> setLcdMode(int mode) async {
    const modes = ['auto', 'always_on', 'always_off'];
    setPendingSetting('lcd_bl_mode', mode);
    await sendControl({'cmd': 'set_lcd_mode', 'mode': modes[mode.clamp(0, 2)]});
  }

  Future<void> setMqttCreds(String pass) async {
    await sendControl({'cmd': 'set_mqtt_creds', 'pass': pass});
  }

  Future<void> setLogLevel(String level) async {
    setPendingSetting('log_level', level);
    await sendControl({'cmd': 'set_log_level', 'level': level});
  }

  /// Send a boolean setting toggle and immediately store an optimistic override
  /// so the UI doesn't flicker on the next incoming WS status message.
  Future<void> sendSettingControl(String statusKey, bool value) async {
    setPendingSetting(statusKey, value);
    await sendControl({'cmd': 'set_setting', 'key': statusKey, 'value': value});
  }

  /// Store an optimistic value for [key] that overrides incoming WS status for [seconds].
  /// Also immediately updates the current status so the UI responds without waiting for
  /// the next WS message.
  void setPendingSetting(String key, dynamic value, {int seconds = 4}) {
    _pendingSettings[key] = _PendingSetting(
      value: value,
      expiresAt: DateTime.now().add(Duration(seconds: seconds)),
    );
    // Immediately reflect the change in the UI
    if (_lastRawStatus != null) {
      status = Status.fromJson(_applyPending(Map<String, dynamic>.from(_lastRawStatus!)));
      notifyListeners();
    }
  }

  /// Check if motor states changed and fire notifications.
  void _checkMotorStateChange() {
    final s = status;
    if (s == null) return;

    if (!_hasReceivedFirstStatus) {
      // First status — just record, don't notify.
      _prevUgMotor = s.ugMotor;
      _prevOhMotor = s.ohMotor;
      _hasReceivedFirstStatus = true;
      return;
    }

    if (!motorNotifyEnabled) {
      _prevUgMotor = s.ugMotor;
      _prevOhMotor = s.ohMotor;
      return;
    }

    if (s.ugMotor != _prevUgMotor) {
      final action = s.ugMotor ? 'turned ON' : 'turned OFF';
      NotificationService.showMotorNotification(
        title: 'UG Motor $action',
        body: 'Underground motor has $action',
      );
    }

    if (s.ohMotor != _prevOhMotor) {
      final action = s.ohMotor ? 'turned ON' : 'turned OFF';
      NotificationService.showMotorNotification(
        title: 'OH Motor $action',
        body: 'Overhead motor has $action',
      );
    }

    _prevUgMotor = s.ugMotor;
    _prevOhMotor = s.ohMotor;
  }

  /// Patch a raw status JSON map with non-expired pending overrides.
  Map<String, dynamic> _applyPending(Map<String, dynamic> json) {
    final now = DateTime.now();
    _pendingSettings.removeWhere((_, v) => now.isAfter(v.expiresAt));
    // Hand control back to the device as soon as it confirms a change:
    // drop any override whose value the raw status already matches.
    _pendingSettings.removeWhere((k, v) => json.containsKey(k) && json[k] == v.value);
    // Once the motor is actually running, the buzzer/countdown phase is over —
    // drop a lingering buzzer override so it doesn't keep showing CANCEL.
    if (json['oh_motor'] == true) _pendingSettings.remove('oh_buzzer');
    if (json['ug_motor'] == true) _pendingSettings.remove('ug_buzzer');
    if (_pendingSettings.isEmpty) return json;
    final patched = Map<String, dynamic>.from(json);
    for (final entry in _pendingSettings.entries) {
      patched[entry.key] = entry.value.value;
    }
    return patched;
  }

  Future<Map<String, dynamic>?> fetchOtaStatus() async {
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      final res = await http.get(
        Uri.parse('$_activeUrl${_devicePath('/api/ota/status', 'ota/status')}'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchLogs() async {
    // ── Direct mode: fetch logs from ESP32 HTTP ──────────────────────────
    if (directMode && _directService != null) {
      try {
        final logs = await _directService!.fetchLogs();
        return {'logs': logs};
      } catch (_) {}
      return null;
    }

    // ── Cloud mode ──────────────────────────────────────────────────────
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      final res = await http.get(
        Uri.parse('$_activeUrl${_devicePath('/api/logs', 'logs')}'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 401) {
        unauthorized = true;
        authToken = null;
        SharedPreferences.getInstance().then((p) => p.remove(_kAuthToken));
        notifyListeners();
        return null;
      }
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ── Admin ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> adminListUsers() async {
    try {
      final baseUrl = await _resolveUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/admin/users'),
        headers: {if (authToken != null) 'Authorization': 'Bearer $authToken'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  // ── WiFi management (cloud + direct) ─────────────────────────────────────

  Future<Map<String, dynamic>> fetchWifiList() async {
    // Direct mode: HTTP to ESP32
    if (directMode && _directService != null) {
      return _directService!.fetchWifiList();
    }
    // Cloud mode: cache-first. Return the last-known list immediately and
    // refresh in the background so the card never reloads blank.
    await _ensureWifiCacheLoaded();
    if (_wifiCache != null) {
      refreshWifiInBackground();
      _startWifiPolling();
      return _wifiCache!;
    }
    // No cache yet — do a full fetch and store it.
    final data = await _doWifiFetch();
    if (data != null) {
      _wifiCache = data;
      _persistWifiCache();
    }
    _startWifiPolling();
    return _wifiCache ?? {};
  }

  /// Sends wifi_list and reads the device's reply from the backend cache.
  Future<Map<String, dynamic>?> _doWifiFetch() async {
    await sendControl({'cmd': 'wifi_list'});
    await Future.delayed(const Duration(seconds: 2));
    return _fetchWifiResponse();
  }

  /// Refreshes the WiFi list without blocking the UI; updates cache + notifies.
  Future<void> refreshWifiInBackground() async {
    if (directMode) return;
    final data = await _doWifiFetch();
    if (data != null && data.isNotEmpty) {
      _wifiCache = data;
      _persistWifiCache();
      notifyListeners();
    }
  }

  void _startWifiPolling() {
    _wifiPollTimer ??= Timer.periodic(const Duration(minutes: 5), (_) {
      if (!directMode && connected) refreshWifiInBackground();
    });
  }

  String get _wifiPrefsKey => 'wifi_cache_${currentDevice?.mac ?? 'default'}';

  Future<void> _ensureWifiCacheLoaded() async {
    if (_wifiCacheLoaded && _wifiCache != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_wifiPrefsKey);
      if (raw != null) {
        _wifiCache = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    _wifiCacheLoaded = true;
  }

  Future<void> _persistWifiCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_wifiCache != null) {
        await prefs.setString(_wifiPrefsKey, jsonEncode(_wifiCache));
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> scanWifi() async {
    if (directMode && _directService != null) {
      return _directService!.scanWifi();
    }
    await sendControl({'cmd': 'wifi_scan'});
    // Scan takes longer on ESP32
    await Future.delayed(const Duration(seconds: 6));
    final resp = await _fetchWifiResponse();
    if (resp != null && resp['type'] == 'wifi_scan') {
      return (resp['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<bool> addWifi(String ssid, String password) async {
    if (directMode && _directService != null) {
      return _directService!.addWifi(ssid, password);
    }
    await sendControl({'cmd': 'wifi_add', 'ssid': ssid, 'pass': password});
    return true;
  }

  Future<bool> deleteWifi(String ssid) async {
    if (directMode && _directService != null) {
      return _directService!.deleteWifi(ssid);
    }
    await sendControl({'cmd': 'wifi_delete', 'ssid': ssid});
    return true;
  }

  Future<bool> setWifiPriority(String ssid, int priority) async {
    if (directMode && _directService != null) {
      return _directService!.setWifiPriority(ssid, priority);
    }
    await sendControl({'cmd': 'wifi_set_priority', 'ssid': ssid, 'priority': priority});
    return true;
  }

  // ── Event history (cloud + direct) ───────────────────────────────────────

  /// Registers this device's FCM push token with the backend (cloud mode only).
  Future<void> registerPushToken(String token) async {
    if (authToken == null || directMode) return;
    try {
      final baseUrl = await _resolveUrl();
      await http.post(
        Uri.parse('$baseUrl/api/push/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> fetchHistory({bool triggerRefresh = true}) async {
    if (directMode && _directService != null) {
      return _directService!.fetchHistory();
    }
    // History is derived and stored server-side from the status stream, so we
    // just read it straight from the backend DB — fast, always available.
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      final res = await http.get(
        Uri.parse('$_activeUrl${_devicePath('/api/history', 'history')}'),
        headers: headers,
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['type'] == 'history_list') {
          return body['data'] as Map<String, dynamic>? ?? {'count': 0, 'records': []};
        }
      }
    } catch (_) {}
    return {'count': 0, 'records': []};
  }

  /// Fetches the latest `controller_firmware/*` GitHub release asset.
  /// Returns the firmware.bin download URL and version, or null if none found.
  Future<({String url, String version})?> fetchLatestControllerFirmware() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/nperiannan/TankMonitor/releases?per_page=30'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final releases = jsonDecode(res.body) as List<dynamic>;
        for (final r in releases) {
          final tagName = (r['tag_name'] as String?) ?? '';
          if (!tagName.startsWith('controller_firmware/')) continue;
          final version = tagName.replaceFirst('controller_firmware/', '').replaceFirst('v', '');
          final assets = r['assets'] as List<dynamic>? ?? [];
          for (final a in assets) {
            if ((a['name'] as String?)?.endsWith('.bin') == true) {
              return (url: a['browser_download_url'] as String, version: version);
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> clearHistory() async {
    if (directMode && _directService != null) {
      return _directService!.clearHistory();
    }
    await sendControl({'cmd': 'history_clear'});
    // Also clear the backend DB archive so it matches the device.
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      await http.delete(
        Uri.parse('$_activeUrl${_devicePath('/api/history', 'history')}'),
        headers: headers,
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}
    return true;
  }

  /// Fetches the latest WiFi response from the backend cache.
  Future<Map<String, dynamic>?> _fetchWifiResponse() async {
    try {
      final headers = <String, String>{};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      final res = await http.get(
        Uri.parse('$_activeUrl${_devicePath('/api/wifi', 'wifi')}'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> sendControl(Map<String, dynamic> cmd) async {
    // Optimistic UI: reflect motor ON/OFF immediately so the button responds
    // without waiting for the next status round-trip from the device.
    //
    // When buzzer mode is enabled the motor doesn't start right away — it first
    // enters a buzzer countdown (the button shows CANCEL). In that case we must
    // NOT force the motor "on", or we'd skip the CANCEL state; we let the real
    // status drive it. OFF/cancel always clears both immediately.
    final buzzerMode = status?.buzzerDelay == true;
    switch (cmd['cmd'] as String? ?? '') {
      case 'oh_on':
        // Instant feedback: in buzzer mode show CANCEL (buzzer countdown),
        // otherwise show the motor running.
        if (buzzerMode) {
          setPendingSetting('oh_buzzer', true, seconds: 8);
        } else {
          setPendingSetting('oh_motor', true, seconds: 10);
        }
        break;
      case 'oh_off':
        setPendingSetting('oh_motor', false, seconds: 8);
        setPendingSetting('oh_buzzer', false, seconds: 8);
        // Clear the shared buzzer flag too, otherwise the legacy "both motors
        // blink" fallback would briefly light up the OTHER motor's CANCEL state.
        if (!(status?.ugBuzzer ?? false)) setPendingSetting('buzzer_active', false, seconds: 8);
        break;
      case 'ug_on':
        if (buzzerMode) {
          setPendingSetting('ug_buzzer', true, seconds: 8);
        } else {
          setPendingSetting('ug_motor', true, seconds: 10);
        }
        break;
      case 'ug_off':
        setPendingSetting('ug_motor', false, seconds: 8);
        setPendingSetting('ug_buzzer', false, seconds: 8);
        if (!(status?.ohBuzzer ?? false)) setPendingSetting('buzzer_active', false, seconds: 8);
        break;
    }
    // ── Direct mode: translate commands to controller HTTP endpoints ──────
    if (directMode && _directService != null) {
      try {
        final c = cmd['cmd'] as String? ?? '';
        bool ok = false;
        switch (c) {
          case 'oh_on':  ok = await _directService!.motorOH(true); break;
          case 'oh_off': ok = await _directService!.motorOH(false); break;
          case 'ug_on':  ok = await _directService!.motorUG(true); break;
          case 'ug_off': ok = await _directService!.motorUG(false); break;
          case 'set_setting':
            final key = cmd['key'] as String? ?? '';
            final value = cmd['value'];
            ok = await _directService!.setConfig(
              ohDispOnly: key == 'oh_disp_only' ? value as bool : null,
              ugDispOnly: key == 'ug_disp_only' ? value as bool : null,
              ugIgnore: key == 'ug_ignore' ? value as bool : null,
              buzzerDelay: key == 'buzzer_delay' ? value as bool : null,
              manualAutoStop: key == 'manual_auto_stop' ? value as bool : null,
              ohStartLevel: key == 'oh_start_level' ? value as int : null,
              ohStopLevel: key == 'oh_stop_level' ? value as int : null,
              ohMaxRun: key == 'oh_max_run_min' ? value as int : null,
            );
            break;
          case 'set_lcd_mode':
            ok = await _directService!.setLcdMode(cmd['mode'] as String? ?? 'auto');
            break;
          case 'set_log_level':
            ok = await _directService!.setLogLevel(cmd['level'] as String? ?? 'info');
            break;
          case 'set_mqtt_creds':
            ok = await _directService!.setMqttPass(cmd['pass'] as String? ?? '');
            break;
          case 'sync_ntp':  ok = await _directService!.syncNtp(); break;
          case 'reboot':   ok = await _directService!.reboot(); break;
          case 'sched_clear': ok = await _directService!.clearSchedules(); break;
          case 'get_logs': break; // logs fetched separately in direct mode
          default:
            // sched_add / sched_remove not easily mapped to bulk API;
            // handled separately by WiFi/History screens.
            break;
        }
        if (!ok && c != 'get_logs') {
          error = 'Command failed';
          notifyListeners();
          Future.delayed(const Duration(seconds: 4), () { error = null; notifyListeners(); });
        }
        _pollOnce(); // refresh status immediately after a command
      } catch (e) {
        error = e.toString();
        notifyListeners();
        Future.delayed(const Duration(seconds: 4), () { error = null; notifyListeners(); });
      }
      return;
    }

    // ── Cloud mode: send via web backend ──────────────────────────────────
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      final res = await http.post(
        Uri.parse('$_activeUrl${_devicePath('/api/control', 'control')}'),
        headers: headers,
        body: jsonEncode(cmd),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 401) {
        unauthorized = true;
        authToken = null;
        SharedPreferences.getInstance().then((p) => p.remove(_kAuthToken));
        notifyListeners();
        return;
      }
      if (res.statusCode != 200) {
        error = 'Control failed (${res.statusCode}): ${res.body}';
        notifyListeners();
        Future.delayed(const Duration(seconds: 4), () { error = null; notifyListeners(); });
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
      Future.delayed(const Duration(seconds: 4), () { error = null; notifyListeners(); });
    }
  }
}

// Internal helper — holds an optimistic setting value until it expires.
class _PendingSetting {
  final dynamic value;
  final DateTime expiresAt;
  const _PendingSetting({required this.value, required this.expiresAt});
}
