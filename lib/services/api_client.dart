import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Thrown for any non-2xx response, carrying the server's own JSON
/// message (Laravel's validation/auth error responses all shape their
/// message the same way) so the UI can show it directly rather than a
/// generic "something went wrong."
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  /// Optional machine-readable error code the server can attach (e.g.
  /// 'recording_too_large') so the UI can special-case it instead of
  /// only matching on human-readable message text.
  final String? errorCode;

  ApiException(this.statusCode, this.message, [this.errors, this.errorCode]);

  @override
  String toString() => message;
}

/// One shared client for every API call in the app. Reads the Sanctum
/// token from secure storage and attaches it as a Bearer header
/// automatically — screens/services never touch the token directly.
class MultipartUploadFile {
  final String fieldName;
  final List<int> bytes;
  final String fileName;
  final String? contentType;

  const MultipartUploadFile({
    required this.fieldName,
    required this.bytes,
    required this.fileName,
    this.contentType,
  });
}

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
    if (!remember) {
      _inMemoryToken = token;
      await _safeDeleteStoredToken();
      return;
    }

    try {
      await _storage.write(key: _tokenKey, value: token);
      _inMemoryToken = null;
    } on PlatformException catch (e) {
      // Some Android phones can lose/decrypt the Keystore-backed key after
      // OS restore/update. Do not let that prevent login or app startup.
      // Keep the token for this app process and repair the broken storage.
      _inMemoryToken = token;
      await _recoverBrokenSecureStorage(e);
    } catch (_) {
      // Secure persistence is preferable, but the app must remain usable if
      // the device's secure storage provider is temporarily unavailable.
      _inMemoryToken = token;
    }
  }

  Future<String?> getToken() async {
    if (_inMemoryToken != null) return _inMemoryToken;

    try {
      return await _storage.read(key: _tokenKey);
    } on PlatformException catch (e) {
      await _recoverBrokenSecureStorage(e);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    _inMemoryToken = null;
    await _safeDeleteStoredToken();
  }

  Future<void> _safeDeleteStoredToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } on PlatformException catch (e) {
      await _recoverBrokenSecureStorage(e);
    } catch (_) {}
  }

  Future<void> _recoverBrokenSecureStorage(PlatformException error) async {
    final message = '${error.message ?? ''} ${error.details ?? ''}'
        .toLowerCase();
    final looksLikeDecryptFailure =
        message.contains('decrypt') ||
        message.contains('encryptedsharedpreferences') ||
        message.contains('keystore');

    if (!looksLikeDecryptFailure) return;

    try {
      // Broken encrypted values cannot be recovered. Clearing them is safer
      // than crashing every startup. The user is simply asked to sign in once.
      await _storage.deleteAll();
    } catch (_) {}
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
  static DateTime? lastSuccessfulSyncAt;
  static bool lastWriteWasRetried = false;

  /// [cacheable] is opt-in, not the default — most GET endpoints
  /// either shouldn't be cached at all (reminders/due-now, which is
  /// explicitly meant to reflect right-now) or don't matter enough to
  /// bother (one-off lookups). Only pass true for screens where
  /// showing yesterday's data is clearly better than showing nothing
  /// — Dashboard, module lists, etc. On a genuine network failure
  /// (no connection at all — NOT a 4xx/5xx from a reachable server),
  /// falls back to whatever was last successfully cached for this
  /// exact path, if anything.
  Future<dynamic> get(
    String path, {
    bool auth = true,
    bool cacheable = false,
  }) async {
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

  String _cacheKey(String path) =>
      'api_cache_${path.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

  /// GET that renders instantly when a previous response is cached, then
  /// refreshes in the background and calls [onRefresh] with the fresh payload
  /// once the network responds. When nothing is cached yet it behaves like a
  /// normal cacheable [get], so screens can use it as a drop-in "fast"
  /// loader without special-casing the very first load. The background refresh
  /// is best-effort: any failure (offline, server error, bad payload) keeps
  /// the already-served cached data and is swallowed silently.
  Future<dynamic> getFast(
    String path, {
    bool auth = true,
    void Function(dynamic data)? onRefresh,
  }) async {
    final cached = await _readCache(path);
    if (cached != null) {
      unawaited(_silentRefresh(path, auth: auth, onRefresh: onRefresh));
      return cached;
    }
    return get(path, auth: auth, cacheable: true);
  }

  Future<void> _silentRefresh(
    String path, {
    required bool auth,
    void Function(dynamic data)? onRefresh,
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/$path'), headers: await _headers(auth: auth))
          .timeout(requestTimeout);
      final decoded = _handle(response);
      await _writeCache(path, decoded);
      if (onRefresh != null) {
        try {
          onRefresh(decoded);
        } catch (_) {
          // A wrong-shape payload must not crash the background refresh.
        }
      }
    } catch (_) {
      // Silent refresh failure: keep whatever content the UI already shows.
    }
  }

  Future<void> _writeCache(String path, dynamic decoded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(path), jsonEncode(decoded));
      await prefs.setString(
        '${_cacheKey(path)}_at',
        DateTime.now().toIso8601String(),
      );
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
      lastServedFromCacheAt = timestamp != null
          ? DateTime.tryParse(timestamp)
          : null;

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
    headers.remove(
      'Content-Type',
    ); // this is a GET with no body, not a JSON request
    final response = await http
        .get(Uri.parse('$baseUrl/$path'), headers: headers)
        .timeout(requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Could not download the file.');
    }

    return response.bodyBytes;
  }

  Future<void> _invalidateApiCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('api_cache_'))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {
      // Cache invalidation must never make a successful write look failed.
    }
  }

  static bool isTransientNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;

  bool _isTransientNetworkError(Object error) => isTransientNetworkError(error);

  Future<dynamic> _performJsonWrite(
    String path,
    Future<http.Response> Function(Map<String, String> headers) send, {
    bool auth = true,
    String? fixedIdempotencyKey,
    String? baseUpdatedAt,
  }) async {
    final key = fixedIdempotencyKey ?? const Uuid().v4();
    lastWriteWasRetried = false;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _headers(auth: auth);
        headers['X-Idempotency-Key'] = key;
        if (baseUpdatedAt != null && baseUpdatedAt.isNotEmpty) {
          headers['X-Offline-Base-Updated-At'] = baseUpdatedAt;
        }
        final response = await send(headers).timeout(requestTimeout);
        final decoded = _handle(response);
        lastSuccessfulSyncAt = DateTime.now();
        await _invalidateApiCaches();
        return decoded;
      } catch (error) {
        if (attempt == 0 && _isTransientNetworkError(error)) {
          lastWriteWasRetried = true;
          await Future<void>.delayed(const Duration(milliseconds: 650));
          continue;
        }
        rethrow;
      }
    }
    throw StateError('Unreachable write retry state.');
  }

  /// Replays a mutation previously saved by OfflineMutationQueue. The original
  /// idempotency key is deliberately reused across reconnect attempts so a
  /// lost response can never create the same record twice.
  Future<dynamic> replayOfflineMutation(
    String method,
    String path,
    Map<String, dynamic> body, {
    required String idempotencyKey,
    String? baseUpdatedAt,
  }) {
    final upper = method.toUpperCase();
    return _performJsonWrite(
      path,
      (headers) {
        final uri = Uri.parse('$baseUrl/$path');
        final encoded = body.isEmpty ? null : jsonEncode(body);
        return switch (upper) {
          'POST' => http.post(uri, headers: headers, body: encoded),
          'PUT' => http.put(uri, headers: headers, body: encoded),
          'PATCH' => http.patch(uri, headers: headers, body: encoded),
          'DELETE' => http.delete(uri, headers: headers, body: encoded),
          _ => throw ArgumentError(
            'Unsupported offline mutation method: $method',
          ),
        };
      },
      fixedIdempotencyKey: idempotencyKey,
      baseUpdatedAt: baseUpdatedAt,
    );
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) => _performJsonWrite(
    path,
    (headers) => http.post(
      Uri.parse('$baseUrl/$path'),
      headers: headers,
      body: jsonEncode(body),
    ),
    auth: auth,
  );

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) => _performJsonWrite(
    path,
    (headers) => http.put(
      Uri.parse('$baseUrl/$path'),
      headers: headers,
      body: jsonEncode(body),
    ),
    auth: auth,
  );

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) => _performJsonWrite(
    path,
    (headers) => http.patch(
      Uri.parse('$baseUrl/$path'),
      headers: headers,
      body: jsonEncode(body),
    ),
    auth: auth,
  );

  Future<dynamic> deleteWithBody(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) => _performJsonWrite(
    path,
    (headers) => http.delete(
      Uri.parse('$baseUrl/$path'),
      headers: headers,
      body: jsonEncode(body),
    ),
    auth: auth,
  );

  Future<dynamic> delete(String path, {bool auth = true}) => _performJsonWrite(
    path,
    (headers) => http.delete(Uri.parse('$baseUrl/$path'), headers: headers),
    auth: auth,
  );

  /// Sends multipart/form-data. Used by profile/meeting uploads and by the
  /// Social Media Planner where the same request can contain normal fields,
  /// arrays (encoded by the caller as platforms[0], platforms[1], ...), and
  /// an optional image/video attachment. Multipart uploads are always sent as
  /// POST so PHP/Laravel reliably populate uploaded files on every host.
  Future<dynamic> multipart(
    String path, {
    String method = 'POST',
    String? fileFieldName,
    List<int>? fileBytes,
    String? fileName,
    String? contentType,
    Map<String, String> fields = const {},
    List<MultipartUploadFile> files = const [],
  }) async {
    final idempotencyKey = const Uuid().v4();
    lastWriteWasRetried = false;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final request = http.MultipartRequest(
          method.toUpperCase(),
          Uri.parse('$baseUrl/$path'),
        );
        final token = await getToken();
        request.headers['Accept'] = 'application/json';
        request.headers['X-Idempotency-Key'] = idempotencyKey;
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
        request.fields.addAll(fields);

        if (fileFieldName != null &&
            fileBytes != null &&
            fileName != null &&
            fileBytes.isNotEmpty) {
          request.files.add(
            http.MultipartFile.fromBytes(
              fileFieldName,
              fileBytes,
              filename: fileName,
              contentType: contentType != null
                  ? MediaType.parse(contentType)
                  : null,
            ),
          );
        }

        for (final upload in files) {
          if (upload.bytes.isEmpty) continue;

          request.files.add(
            http.MultipartFile.fromBytes(
              upload.fieldName,
              upload.bytes,
              filename: upload.fileName,
              contentType:
                  upload.contentType != null &&
                      upload.contentType!.trim().isNotEmpty
                  ? MediaType.parse(upload.contentType!)
                  : null,
            ),
          );
        }

        final streamedResponse = await request.send().timeout(
          const Duration(minutes: 5),
        );
        final response = await http.Response.fromStream(streamedResponse);
        final decoded = _handle(response);
        lastSuccessfulSyncAt = DateTime.now();
        await _invalidateApiCaches();
        return decoded;
      } catch (error) {
        if (attempt == 0 && _isTransientNetworkError(error)) {
          lastWriteWasRetried = true;
          await Future<void>.delayed(const Duration(milliseconds: 900));
          continue;
        }
        rethrow;
      }
    }
    throw StateError('Unreachable upload retry state.');
  }

  Future<dynamic> postMultipart(
    String path, {
    required String fileFieldName,
    required List<int> fileBytes,
    required String fileName,
    String? contentType,
    Map<String, String> fields = const {},
  }) => multipart(
    path,
    fileFieldName: fileFieldName,
    fileBytes: fileBytes,
    fileName: fileName,
    contentType: contentType,
    fields: fields,
  );

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
      if (decoded == null && response.body.isNotEmpty) {
        throw ApiException(
          response.statusCode,
          'The provider responded, but the reply was not valid JSON. The selected model or endpoint may not support JSON mode; check it in AI Providers, then retry.',
        );
      }
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

    final errorCode = decoded is Map && decoded['error_code'] is String
        ? decoded['error_code'] as String
        : null;

    throw ApiException(response.statusCode, message, errors, errorCode);
  }
}
