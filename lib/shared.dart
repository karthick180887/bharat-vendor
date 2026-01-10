import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiResult {
  final int statusCode;
  final dynamic data;
  final String? message;
  final Map<String, String>? headers;

  const ApiResult({
    required this.statusCode,
    this.data,
    this.message,
    this.headers,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class BaseApiClient {
  BaseApiClient({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'https://api.bharatonewaytaxi.com',
            );

  final String baseUrl;

  Future<ApiResult> get(
    String path, {
    String? token,
    Map<String, String>? queryParams,
  }) {
    return _send('GET', path, token: token, queryParams: queryParams);
  }

  Future<ApiResult> post(
    String path,
    Object? body, {
    String? token,
    Map<String, String>? queryParams,
  }) {
    return _send('POST', path, body: body, token: token, queryParams: queryParams);
  }

  Future<ApiResult> put(
    String path,
    Object? body, {
    String? token,
    Map<String, String>? queryParams,
  }) {
    return _send('PUT', path, body: body, token: token, queryParams: queryParams);
  }

  Future<ApiResult> patch(
    String path,
    Object? body, {
    String? token,
    Map<String, String>? queryParams,
  }) {
    return _send('PATCH', path, body: body, token: token, queryParams: queryParams);
  }

  Future<ApiResult> delete(
    String path,
    Object? body, {
    String? token,
    Map<String, String>? queryParams,
  }) {
    return _send('DELETE', path, body: body, token: token, queryParams: queryParams);
  }

  Map<String, String> _headers({String? token}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final resolved = _resolvePath(path);
    final uri = Uri.parse(resolved);
    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParams,
    });
  }

  String _resolvePath(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (baseUrl.isEmpty) {
      return path;
    }
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBase$normalizedPath';
  }

  Future<ApiResult> _send(
    String method,
    String path, {
    Object? body,
    String? token,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(path, queryParams);
    if (!uri.hasScheme) {
      return const ApiResult(
        statusCode: 0,
        message: 'Missing API base URL. Set API_BASE_URL or pass baseUrl.',
      );
    }

    final client = http.Client();
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(_headers(token: token));

      if (body != null) {
        request.body = json.encode(body);
      }

      final streamed = await client.send(request);
      final response = await http.Response.fromStream(streamed);
      final parsed = _parseBody(response.body);

      return ApiResult(
        statusCode: response.statusCode,
        data: parsed,
        message: _extractMessage(parsed),
        headers: response.headers,
      );
    } catch (e) {
      return ApiResult(statusCode: 0, message: e.toString());
    } finally {
      client.close();
    }
  }

  dynamic _parseBody(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      return json.decode(body);
    } catch (_) {
      return body;
    }
  }

  String? _extractMessage(dynamic parsed) {
    if (parsed is Map<String, dynamic>) {
      final message = parsed['message'];
      if (message is String) {
        return message;
      }
      final error = parsed['error'];
      if (error is String) {
        return error;
      }
    }
    return null;
  }
}
