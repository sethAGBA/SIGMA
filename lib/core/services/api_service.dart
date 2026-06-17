// lib/core/services/api_service.dart
//
// Client HTTP pour communiquer avec le backend FastAPI.
// Utilisé en mode réseau LAN (serveur local).
// L'app bascule automatiquement entre SQLite local et API selon
// la disponibilité du serveur (offline-first).

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── Configuration ─────────────────────────────────────────────────────────

  /// URL de base du serveur. Peut être modifiée depuis la configuration.
  static String _baseUrl = 'http://localhost:8000/api/v1';
  static const String _prefKeyUrl = 'api_server_url';
  static const Duration _timeout = Duration(seconds: 10);

  String get baseUrl => _baseUrl;

  /// Charge l'URL serveur depuis les préférences (définie dans Configuration)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKeyUrl);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
    }
  }

  /// Sauvegarde une nouvelle URL serveur
  Future<void> setServerUrl(String url) async {
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUrl, _baseUrl);
  }

  // ── Token JWT ──────────────────────────────────────────────────────────────

  String? _accessToken;

  void setToken(String token) => _accessToken = token;
  void clearToken() => _accessToken = null;

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // ── Vérification disponibilité du serveur ──────────────────────────────────

  /// Retourne true si le serveur répond dans le délai imparti.
  Future<bool> isServerAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('${_baseUrl.replaceAll('/api/v1', '')}/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Authentification ───────────────────────────────────────────────────────

  /// Login via l'API. Retourne le token JWT si succès, null sinon.
  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _accessToken = data['access_token'];
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Méthodes HTTP génériques ───────────────────────────────────────────────

  Future<http.Response?> get(String path) async {
    try {
      return await http
          .get(Uri.parse('$_baseUrl$path'), headers: _authHeaders)
          .timeout(_timeout);
    } on SocketException {
      return null; // Pas de réseau
    } on HttpException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response?> post(String path, Map<String, dynamic> body) async {
    try {
      return await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _authHeaders,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  Future<http.Response?> put(String path, Map<String, dynamic> body) async {
    try {
      return await http
          .put(
            Uri.parse('$_baseUrl$path'),
            headers: _authHeaders,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  Future<http.Response?> delete(String path) async {
    try {
      return await http
          .delete(Uri.parse('$_baseUrl$path'), headers: _authHeaders)
          .timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Décode la réponse JSON ou retourne null si erreur.
  static dynamic decodeResponse(http.Response? response) {
    if (response == null) return null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }
    return null;
  }

  /// Retourne true si la réponse est un succès.
  static bool isSuccess(http.Response? response) {
    return response != null &&
        response.statusCode >= 200 &&
        response.statusCode < 300;
  }
}
