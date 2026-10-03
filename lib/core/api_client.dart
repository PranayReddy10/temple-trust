import 'dart:convert';

import 'package:http/http.dart' as http;

/// Errors the UI can name: a 404 reads differently from a lost connection.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, List<String>> errors;

  bool get isNotFound => statusCode == 404;
  bool get isUnauthenticated => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidation => statusCode == 422;

  /// The first message for a field, for showing under that input.
  String? field(String name) => errors[name]?.first;

  /// Every validation message, one per line, or the plain message.
  String get details => errors.isEmpty ? message : errors.values.expand((e) => e).join('\n');

  @override
  String toString() => details;
}

/// A file to send in a multipart request. Bytes rather than a path, so the
/// same code works on the web build, where there is no file system.
class UploadFile {
  const UploadFile({required this.field, required this.filename, required this.bytes});

  final String field;
  final String filename;
  final List<int> bytes;
}

/// Thin HTTP layer over `/api/v1/trust`.
class ApiClient {
  ApiClient({required String baseUrl, http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _baseUrl = _trim(baseUrl),
        _http = client ?? http.Client();

  String _baseUrl;
  final http.Client _http;
  final Duration timeout;
  String? token;

  /// Recorded against each sign-in for the admin's analytics screen.
  String platform = 'trust-app';
  String appVersion = '0.1.0';

  /// The interface language, sent as Accept-Language so labels the server
  /// writes (statuses, option lists) come back in the same tongue.
  String language = 'en';

  /// Called when the server says the token is no longer good, so the app
  /// can return to the sign-in screen instead of failing screen by screen.
  void Function()? onUnauthenticated;

  String get baseUrl => _baseUrl;
  set baseUrl(String v) => _baseUrl = _trim(v);

  static String _trim(String v) {
    var s = v.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final q = <String, String>{
      if (query != null)
        for (final e in query.entries)
          if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return Uri.parse('$_baseUrl/api/v1/trust/$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Platform': platform,
        'X-App-Version': appVersion,
        'Accept-Language': language,
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// A read always reaches the server. A CDN or host cache set to keep
  /// everything would otherwise answer with a copy from before a change was
  /// saved; a unique query string is a URL no cache has seen.
  static Uri _fresh(Uri uri) => uri.replace(queryParameters: {...uri.queryParameters, '_': '${DateTime.now().microsecondsSinceEpoch}'});

  Future<Map<String, dynamic>> get(String path, [Map<String, String?>? query]) async {
    return _guard(() => _http.get(_fresh(_uri(path, query)), headers: _headers).timeout(timeout));
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic> body = const {}]) async {
    return _guard(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body)).timeout(timeout));
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    return _guard(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body)).timeout(timeout));
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    return _guard(() => _http.put(_uri(path), headers: _headers, body: jsonEncode(body)).timeout(timeout));
  }

  Future<Map<String, dynamic>> delete(String path) async {
    return _guard(() => _http.delete(_uri(path), headers: _headers).timeout(timeout));
  }

  /// Multipart POST: plain fields plus files. Booleans are sent as 1 and 0,
  /// and null as an empty string, which the API reads as null — so a field
  /// cleared in a form is cleared on the server rather than left as it was.
  Future<Map<String, dynamic>> multipart(String path, {Map<String, dynamic> fields = const {}, List<UploadFile> files = const []}) async {
    final req = http.MultipartRequest('POST', _uri(path))..headers.addAll({..._headers}..remove('Content-Type'));
    for (final e in fields.entries) {
      final v = e.value;
      req.fields[e.key] = v == null ? '' : (v is bool ? (v ? '1' : '0') : '$v');
    }
    for (final f in files) {
      req.files.add(http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.filename));
    }
    return _guard(() async => http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 90))));
  }

  Future<Map<String, dynamic>> _guard(Future<http.Response> Function() send) async {
    final http.Response res;
    try {
      res = await send();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Could not reach the server. Check the connection and try again.');
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = const {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // Non-JSON body: a maintenance page or a proxy error.
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    if (res.statusCode == 401 && token != null) onUnauthenticated?.call();

    final errors = <String, List<String>>{};
    final raw = body['errors'];
    if (raw is Map) {
      for (final e in raw.entries) {
        errors['${e.key}'] = (e.value is List ? e.value as List : [e.value]).map((v) => '$v').toList();
      }
    }
    throw ApiException(
      body['message']?.toString() ?? 'Request failed (${res.statusCode})',
      statusCode: res.statusCode,
      errors: errors,
    );
  }
}
