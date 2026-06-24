import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Thrown when an API call fails (network error, non-2xx status, or the
/// backend returns `success: false`). [message] is safe to show to users.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Low-level HTTP wrapper around the ZedGift REST API.
///
/// Holds the Bearer token in memory for the session, attaches the standard
/// headers (`Accept`, `Authorization`, `Company-ID`) and unwraps the common
/// `{ success, message, data, meta }` envelope used by every endpoint.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  // The app keeps TWO tokens, both set at login from the same access token:
  //  * session token  — gates the admin panel; cleared on Log Out.
  //  * device token    — authorizes this device for kiosk attendance; it
  //                      survives Log Out so "Mark Attendance" keeps working.
  String? _token; // admin session
  String? _deviceToken; // kiosk / attendance
  static const String _tokenKey = 'zedgift_access_token';
  static const String _deviceKey = 'zedgift_device_token';

  /// True while an admin session is active (used to gate the admin panel).
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// True if this device can reach the API for attendance — either an admin
  /// is logged in, or it was set up once and still holds a device token.
  bool get hasDeviceAccess => _effectiveToken != null;

  String? get _effectiveToken {
    if (_token != null && _token!.isNotEmpty) return _token;
    if (_deviceToken != null && _deviceToken!.isNotEmpty) return _deviceToken;
    return null;
  }

  /// The company whose data calls return. Defaults to the configured one but
  /// can be switched at runtime (e.g. from the employee-list company filter).
  String companyId = ApiConfig.companyId;

  /// Store the access token in memory for the current session.
  void setToken(String? token) => _token = token;

  /// Persist the login token on the device (both the admin session token and
  /// the long-lived device token) so a kiosk stays authorized across restarts.
  Future<void> saveToken(String token) async {
    _token = token;
    _deviceToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_deviceKey, token);
  }

  /// Sign the admin out of the panel but KEEP the device authorized for
  /// attendance. Only clears the session token, not the device token.
  Future<void> signOutAdmin() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Fully de-authorize this device (clears every token). Use for a
  /// "reset device" action.
  Future<void> clearDevice() async {
    _token = null;
    _deviceToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_deviceKey);
  }

  /// Load any previously saved tokens into memory (call once at startup).
  Future<void> restoreToken() async {
    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getString(_tokenKey);
    final device = prefs.getString(_deviceKey);
    if (session != null && session.isNotEmpty) _token = session;
    if (device != null && device.isNotEmpty) _deviceToken = device;
  }

  Map<String, String> _headers({bool auth = true, bool jsonBody = false}) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Company-ID': companyId,
    };
    if (jsonBody) h['Content-Type'] = 'application/json';
    final token = _effectiveToken;
    if (auth && token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final qp = query
        ?.map((k, v) => MapEntry(k, v?.toString()))
      ?..removeWhere((_, v) => v == null || v.isEmpty);
    return Uri.parse('${ApiConfig.baseUrl}/$clean').replace(
      queryParameters: (qp == null || qp.isEmpty) ? null : qp,
    );
  }

  // ---- Verbs -------------------------------------------------------------

  /// GET that returns the decoded `data` field of the envelope.
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _send(() => _http
        .get(_uri(path, query), headers: _headers())
        .timeout(ApiConfig.timeout));
  }

  /// POST sending `multipart/form-data` (the backend's login/punch/face all
  /// use form fields, not JSON). [files] maps a field name to a local file
  /// path and is sent as a file part (e.g. `face_image`). [query] adds URL
  /// query params (some POST endpoints, e.g. leave approval, read from there).
  Future<dynamic> postForm(
    String path,
    Map<String, String> fields, {
    bool auth = true,
    Map<String, String>? files,
    Map<String, dynamic>? query,
  }) async {
    return _send(() async {
      final req = http.MultipartRequest('POST', _uri(path, query))
        ..headers.addAll(_headers(auth: auth))
        ..fields.addAll(fields);
      if (files != null) {
        for (final entry in files.entries) {
          req.files
              .add(await http.MultipartFile.fromPath(entry.key, entry.value));
        }
      }
      final streamed = await req.send().timeout(ApiConfig.timeout);
      return http.Response.fromStream(streamed);
    });
  }

  /// GET raw bytes from an endpoint (e.g. a salary-slip PDF), carrying the
  /// auth + Company-ID headers. Returns the response body bytes on 2xx,
  /// otherwise throws an [ApiException].
  Future<List<int>> getBytes(String path, {Map<String, dynamic>? query}) async {
    http.Response res;
    try {
      res = await _http
          .get(_uri(path, query), headers: _headers())
          .timeout(ApiConfig.timeout);
    } catch (_) {
      throw ApiException('Network error. Please try again.');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    throw ApiException('Could not download the file (${res.statusCode}).',
        statusCode: res.statusCode);
  }

  /// PUT with values passed as URL query params (the backend's update
  /// endpoints, e.g. `PUT /leaves/{id}`, read fields from the query string).
  Future<dynamic> put(String path, {Map<String, dynamic>? query}) async {
    return _send(() => _http
        .put(_uri(path, query), headers: _headers())
        .timeout(ApiConfig.timeout));
  }

  /// DELETE a resource (e.g. `DELETE /leaves/{id}`).
  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) async {
    return _send(() => _http
        .delete(_uri(path, query), headers: _headers())
        .timeout(ApiConfig.timeout));
  }

  // ---- Core --------------------------------------------------------------

  Future<dynamic> _send(Future<http.Response> Function() run) async {
    http.Response res;
    try {
      res = await run();
    } catch (e) {
      throw ApiException(
        'Network error. Please check your connection and try again.',
      );
    }

    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        // Non-JSON (e.g. an HTML error page from the server).
        throw ApiException(
          'Server error (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
    }

    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (body is Map<String, dynamic>) {
      final success = body['success'] == true;
      if (ok && success) return body['data'];
      throw ApiException(
        (body['message'] as String?) ?? 'Request failed.',
        statusCode: res.statusCode,
      );
    }

    if (!ok) {
      throw ApiException('Request failed.', statusCode: res.statusCode);
    }
    return body;
  }
}
