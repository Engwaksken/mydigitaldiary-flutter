import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown for any non-2xx response, carrying the server's own JSON
/// message (Laravel's validation/auth error responses all shape their
/// message the same way) so the UI can show it directly rather than a
/// generic "something went wrong."
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  ApiException(this.statusCode, this.message, [this.errors]);

  @override
  String toString() => message;
}

/// One shared client for every API call in the app. Reads the Sanctum
/// token from secure storage and attaches it as a Bearer header
/// automatically — screens/services never touch the token directly.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  // "Remember Me" unchecked -> token lives here only, for the current
  // app process, and is never written to secure storage at all — a
  // full app restart then requires logging in again, since there's
  // nothing to read back. This is mobile's equivalent of the web
  // app's Auth::login($user, $remember) session-cookie behavior, given
  // Sanctum tokens have no built-in "remember" concept of their own.
  static String? _inMemoryToken;

  /// CHANGE THIS to your actual server. 10.0.2.2 is the Android emulator's
  /// alias for the host machine's localhost — a physical device needs your
  /// computer's real LAN IP (e.g. http://192.168.1.50:8000/api) instead,
  /// and production needs your real domain over https.
  static const String baseUrl = 'https://my-digital-diary.com/api';

  // A connected Wi-Fi/mobile interface does not guarantee the API server is
  // reachable. Never let a socket keep the app on the splash screen for
  // minutes. Normal API requests fail fast and can then use cache/retry UI.
  static const Duration requestTimeout = Duration(seconds: 15);

  Future<void> saveToken(String token, {bool remember = true}) async {
    if (remember) {
      await _storage.write(key: _tokenKey, value: token);
    } else {
      _inMemoryToken = token;
      // Explicitly cleared rather than left stale — otherwise a
      // PREVIOUS "remembered" login's token could still be read back
      // by getToken() below even after choosing not to remember this one.
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<String?> getToken() async => _inMemoryToken ?? await _storage.read(key: _tokenKey);

  Future<void> clearToken() async {
    _inMemoryToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Tracks the most recent cache fallback across the whole app —
  /// screens/widgets (see ConnectivityGate) can read this to show a
  /// "showing saved data from [time]" indicator without each screen
  /// needing its own plumbing for it.
  static DateTime? lastServedFromCacheAt;

  /// [cacheable] is opt-in, not the default — most GET endpoints
  /// either shouldn't be cached at all (reminders/due-now, which is
  /// explicitly meant to reflect right-now) or don't matter enough to
  /// bother (one-off lookups). Only pass true for screens where
  /// showing yesterday's data is clearly better than showing nothing
  /// — Dashboard, module lists, etc. On a genuine network failure
  /// (no connection at all — NOT a 4xx/5xx from a reachable server),
  /// falls back to whatever was last successfully cached for this
  /// exact path, if anything.
  Future<dynamic> get(String path, {bool auth = true, bool cacheable = false}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/$path'), headers: await _headers(auth: auth))
          .timeout(requestTimeout);
      final decoded = _handle(response);
      if (cacheable) await _writeCache(path, decoded);
      return decoded;
    } on SocketException catch (_) {
      if (cacheable) {
        final cached = await _readCache(path);
        if (cached != null) return cached;
      }
      rethrow;
    } on http.ClientException catch (_) {
      if (cacheable) {
        final cached = await _readCache(path);
        if (cached != null) return cached;
      }
      rethrow;
    } on TimeoutException catch (_) {
      if (cacheable) {
        final cached = await _readCache(path);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  String _cacheKey(String path) => 'api_cache_${path.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

  Future<void> _writeCache(String path, dynamic decoded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(path), jsonEncode(decoded));
      await prefs.setString('${_cacheKey(path)}_at', DateTime.now().toIso8601String());
    } catch (_) {
      // Caching is a nice-to-have, not a critical path — a failure to
      // write it (e.g. storage full) shouldn't affect the actual
      // response the caller is waiting on.
    }
  }

  Future<dynamic> _readCache(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(path));
      if (raw == null) return null;

      final timestamp = prefs.getString('${_cacheKey(path)}_at');
      lastServedFromCacheAt = timestamp != null ? DateTime.tryParse(timestamp) : null;

      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// For PDFs and other binary responses — everything else in this
  /// client assumes JSON, which doesn't apply here, so this bypasses
  /// _handle() and just returns the raw bytes on success.
  Future<List<int>> downloadBytes(String path, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    headers.remove('Content-Type'); // this is a GET with no body, not a JSON request
    final response = await http
        .get(Uri.parse('$baseUrl/$path'), headers: headers)
        .timeout(requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Could not download the file.');
    }

    return response.bodyBytes;
  }

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/$path'),
          headers: await _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return _handle(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/$path'),
          headers: await _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return _handle(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/$path'),
          headers: await _headers(auth: auth),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return _handle(response);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/$path'), headers: await _headers(auth: auth))
        .timeout(requestTimeout);
    return _handle(response);
  }

  /// For endpoints that accept a file — business card photo, meeting
  /// audio. [fields] are the other form values (Laravel reads these the
  /// same as a normal POST body when the request is multipart), [file]
  /// is raw bytes with the field name the backend expects (e.g. 'photo',
  /// 'audio'). Does NOT set Content-Type manually — MultipartRequest
  /// sets its own with the correct boundary, which a manual
  /// 'application/json' header (like every other method here uses)
  /// would silently break.
  Future<dynamic> postMultipart(
    String path, {
    required String fileFieldName,
    required List<int> fileBytes,
    required String fileName,
    String? contentType,
    Map<String, String> fields = const {},
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/$path'));
    final token = await getToken();
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        fileFieldName,
        fileBytes,
        filename: fileName,
        contentType: contentType != null ? MediaType.parse(contentType) : null,
      ),
    );

    // File uploads (especially meeting recordings on mobile data) need longer
    // than normal JSON calls. Keep splash/list requests fast, but allow
    // multipart uploads up to five minutes.
    final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);
    return _handle(response);
  }

  dynamic _handle(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded is Map && decoded['message'] != null
        ? decoded['message'].toString()
        : response.body.trim().isNotEmpty && response.body.length < 300
            ? response.body.trim()
            : 'Something went wrong (HTTP ${response.statusCode}).';

    final errors = decoded is Map && decoded['errors'] is Map
        ? Map<String, dynamic>.from(decoded['errors'] as Map)
        : null;

    throw ApiException(response.statusCode, message, errors);
  }
}
