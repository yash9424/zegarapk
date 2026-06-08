import 'dart:convert';

import 'package:http/http.dart' as http;

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

  String? _token;

  /// True once a successful login has stored a Bearer token.
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// Store / clear the access token used for authenticated calls.
  void setToken(String? token) => _token = token;

  Map<String, String> _headers({bool auth = true, bool jsonBody = false}) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Company-ID': ApiConfig.companyId,
    };
    if (jsonBody) h['Content-Type'] = 'application/json';
    if (auth && isAuthenticated) h['Authorization'] = 'Bearer $_token';
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

  /// POST sending `multipart/form-data` (the backend's login/punch/etc.
  /// all use form fields, not JSON).
  Future<dynamic> postForm(
    String path,
    Map<String, String> fields, {
    bool auth = true,
  }) async {
    return _send(() async {
      final req = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers(auth: auth))
        ..fields.addAll(fields);
      final streamed = await req.send().timeout(ApiConfig.timeout);
      return http.Response.fromStream(streamed);
    });
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
