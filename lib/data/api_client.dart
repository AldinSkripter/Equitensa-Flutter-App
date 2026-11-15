import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Failure reported by the Equitensa backend (`{error, fields}`) or the network.
class ApiException implements Exception {
  const ApiException(this.status, this.code, [this.fields = const [], this.details = const {}]);
  final int status;
  final String code;
  final List<String> fields;
  final Map<String, dynamic> details;

  bool get isOffline => status == 0;
  bool get isAuth => status == 401 && code == 'AUTH_REQUIRED';
  bool get isConflict => code == 'FINANCE_VERSION_CONFLICT';
  bool get isUpgrade => code == 'FINANCE_PLAN_UPGRADE_REQUIRED';
  bool get isReleaseGate => code == 'FINANCE_RELEASE_NOT_ENABLED';
  bool get isUnverified => code == 'EMAIL_NOT_VERIFIED';

  @override
  String toString() => 'ApiException($status, $code)';
}

String defaultApiBase() {
  const configured = String.fromEnvironment('API_BASE');
  if (configured.isNotEmpty) return configured;
  // Web builds are served same-origin by a dev proxy; the Android emulator reaches the host via 10.0.2.2.
  if (kIsWeb) return '';
  return Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
}

/// Minimal HTTP client with the web cookie session used by the development backend.
/// This is NOT native OAuth/PKCE; it is replaced once the backend ships the mobile contract.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? client, this.persist = true})
    : baseUrl = baseUrl ?? defaultApiBase(),
      _client = client ?? http.Client();

  final String baseUrl;
  final bool persist;
  final http.Client _client;
  String? _cookie;
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'equitensa_dev_session';

  /// Restores the development session cookie from the OS keychain/keystore (mobile only).
  Future<void> restore() async {
    if (kIsWeb || !persist) return;
    try {
      _cookie = await _storage.read(key: _storageKey);
    } catch (_) {
      _cookie = null;
    }
  }

  Future<void> _persist() async {
    if (kIsWeb || !persist) return;
    try {
      if (_cookie == null) {
        await _storage.delete(key: _storageKey);
      } else {
        await _storage.write(key: _storageKey, value: _cookie);
      }
    } catch (_) {}
  }

  /// Called when the server reports an expired or revoked session.
  void Function()? onSessionLost;

  bool get hasSession => _cookie != null;
  void clearSession() {
    _cookie = null;
    _persist();
  }

  Uri _uri(String path) => Uri.parse('$baseUrl/api$path');

  Map<String, String> _headers({bool json = false}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (!kIsWeb) {
      final uri = Uri.parse(baseUrl);
      h['Origin'] = '${uri.scheme}://${uri.authority}';
      if (_cookie != null) h['Cookie'] = _cookie!;
    }
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }

  void _storeCookie(http.BaseResponse r) {
    final raw = r.headers['set-cookie'];
    if (raw == null) return;
    final match = RegExp(r'equitensa_session=([^;]*)').firstMatch(raw);
    if (match == null) return;
    // An emptied cookie means logout.
    _cookie = match.group(1)!.isEmpty ? null : 'equitensa_session=${match.group(1)}';
    _persist();
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      final r = await call().timeout(const Duration(seconds: 70));
      _storeCookie(r);
      return r;
    } on SocketException {
      throw const ApiException(0, 'OFFLINE');
    } on http.ClientException {
      throw const ApiException(0, 'OFFLINE');
    } on TimeoutException {
      throw const ApiException(0, 'TIMEOUT');
    }
  }

  ApiException _error(http.Response r) {
    String code = 'HTTP_${r.statusCode}';
    var fields = <String>[];
    var details = <String, dynamic>{};
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map) {
        details = Map<String, dynamic>.from(j);
        code = (j['error'] ?? code).toString();
        if (j['fields'] is List) fields = [for (final f in j['fields'] as List) f.toString()];
      }
    } catch (_) {}
    final e = ApiException(r.statusCode, code, fields, details);
    if (e.isAuth) onSessionLost?.call();
    return e;
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final r = await _send(() => _client.get(_uri(path), headers: _headers()));
    if (r.statusCode >= 400) throw _error(r);
    return _decode(r);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final r = await _send(
      () => _client.post(
        _uri(path),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
    if (r.statusCode >= 400) throw _error(r);
    return _decode(r);
  }

  Future<Uint8List> getBytes(String path) async {
    final r = await _send(() => _client.get(_uri(path), headers: _headers()));
    if (r.statusCode >= 400) throw _error(r);
    return r.bodyBytes;
  }

  Future<Uint8List> postBytes(String path, Map<String, dynamic> body) async {
    final r = await _send(() => _client.post(_uri(path), headers: _headers(json: true), body: jsonEncode(body)));
    if (r.statusCode >= 400) throw _error(r);
    return r.bodyBytes;
  }

  Map<String, dynamic> _decode(http.Response r) {
    if (r.bodyBytes.isEmpty) return <String, dynamic>{};
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{'data': j};
  }
}
