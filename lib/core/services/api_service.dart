// lib/core/services/api_service.dart
//
// Client HTTP pour communiquer avec le backend FastAPI.
// Phase 1 : persistance JWT, intercepteur Authorization, refresh automatique.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const _storage = FlutterSecureStorage();
  static const String accessTokenKey = 'sigma_access_token';
  static const String refreshTokenKey = 'sigma_refresh_token';

  static String _baseUrl = 'http://localhost:8000/api/v1';
  static const String _prefKeyUrl = 'api_server_url';
  static const Duration _timeout = Duration(seconds: 10);

  static const _noAuthPaths = {'/auth/login', '/auth/refresh'};

  String? _accessToken;
  bool _isRefreshing = false;
  final List<Completer<bool>> _refreshQueue = [];

  /// Appelé quand le refresh échoue — enregistré par AuthService dans init().
  Future<void> Function()? onSessionExpired;

  @visibleForTesting
  http.Client? httpClient;

  @visibleForTesting
  Future<bool> Function()? isServerAvailableOverride;

  @visibleForTesting
  Future<bool> Function()? tryRefreshOverride;

  http.Client get _client => httpClient ?? http.Client();

  String get baseUrl => _baseUrl;
  String? get currentAccessToken => _accessToken;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKeyUrl);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
    }
    _accessToken = await _storage.read(key: accessTokenKey);
  }

  Future<void> setServerUrl(String url) async {
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUrl, _baseUrl);
  }

  void setToken(String token) => _accessToken = token;

  void clearToken() {
    _accessToken = null;
  }

  Future<void> persistTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken;
    await _storage.write(key: accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> clearSecureTokens() async {
    _accessToken = null;
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
  }

  Future<String?> readRefreshToken() =>
      _storage.read(key: refreshTokenKey);

  Future<bool> isServerAvailable() async {
    if (isServerAvailableOverride != null) {
      return isServerAvailableOverride!();
    }
    try {
      final response = await _client
          .get(Uri.parse('${_baseUrl.replaceAll('/api/v1', '')}/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access_token'] as String?;
        final refresh = data['refresh_token'] as String?;
        if (access != null) {
          await persistTokens(
            accessToken: access,
            refreshToken: refresh,
          );
        }
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Tente un refresh avec le token fourni ou celui du secure storage.
  Future<bool> tryRefresh([String? refreshToken]) async {
    if (tryRefreshOverride != null) {
      return tryRefreshOverride!();
    }
    final token = refreshToken ?? await readRefreshToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': token}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final access = data['access_token'] as String?;
        final refresh = data['refresh_token'] as String?;
        if (access != null) {
          await persistTokens(
            accessToken: access,
            refreshToken: refresh ?? token,
          );
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Map<String, String> _headersFor(String path) {
    final inject =
        _accessToken != null && !_noAuthPaths.contains(path);
    return {
      'Content-Type': 'application/json',
      if (inject) 'Authorization': 'Bearer $_accessToken',
    };
  }

  @visibleForTesting
  Map<String, String> headersFor(String path) => _headersFor(path);

  Future<http.Response?> get(String path) =>
      _request(
        (headers) => _client.get(Uri.parse('$_baseUrl$path'), headers: headers),
        path,
      );

  Future<http.Response?> post(String path, Map<String, dynamic> body) =>
      _request(
        (headers) => _client.post(
          Uri.parse('$_baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        ),
        path,
      );

  Future<http.Response?> put(String path, Map<String, dynamic> body) =>
      _request(
        (headers) => _client.put(
          Uri.parse('$_baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        ),
        path,
      );

  Future<http.Response?> delete(String path) =>
      _request(
        (headers) =>
            _client.delete(Uri.parse('$_baseUrl$path'), headers: headers),
        path,
      );

  Future<http.Response?> _request(
    Future<http.Response> Function(Map<String, String> headers) send,
    String path, {
    bool allowRetry = true,
  }) async {
    try {
      var response = await send(_headersFor(path)).timeout(_timeout);

      if (response.statusCode == 401 &&
          allowRetry &&
          !_noAuthPaths.contains(path)) {
        final refreshed = await _handleUnauthorized();
        if (refreshed) {
          response = await send(_headersFor(path)).timeout(_timeout);
        }
      }

      return response;
    } on SocketException {
      return null;
    } on HttpException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _handleUnauthorized() async {
    if (_isRefreshing) {
      final completer = Completer<bool>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _isRefreshing = true;
    final success = await tryRefresh();
    _isRefreshing = false;
    _drainRefreshQueue(success);

    if (!success) {
      await clearSecureTokens();
      await onSessionExpired?.call();
    }

    return success;
  }

  void _drainRefreshQueue(bool success) {
    for (final completer in _refreshQueue) {
      if (!completer.isCompleted) {
        completer.complete(success);
      }
    }
    _refreshQueue.clear();
  }

  @visibleForTesting
  Future<bool> handleUnauthorizedForTesting() => _handleUnauthorized();

  static dynamic decodeResponse(http.Response? response) {
    if (response == null) return null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }
    return null;
  }

  static bool isSuccess(http.Response? response) {
    return response != null &&
        response.statusCode >= 200 &&
        response.statusCode < 300;
  }

  /// Décode le claim `exp` d'un JWT ; retourne true si expiré ou invalide.
  @visibleForTesting
  static bool isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return true;
      var payload = parts[1];
      final mod = payload.length % 4;
      if (mod > 0) payload += '=' * (4 - mod);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is! num) return false;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance._accessToken = null;
    _instance._isRefreshing = false;
    _instance._refreshQueue.clear();
    _instance.onSessionExpired = null;
    _instance.httpClient = null;
    _instance.isServerAvailableOverride = null;
    _instance.tryRefreshOverride = null;
  }
}
