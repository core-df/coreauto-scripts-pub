// Copyright Core DF — Apache License 2.0
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'result.dart';

class Httpclient {
  static dynamic _parseBody(String raw) {
    if (raw.isEmpty) return null;
    try { return jsonDecode(raw); } catch (_) { return raw; }
  }

  static Future<Map<String, dynamic>> _request(String method, String url,
      {Map<String, String>? headers, String? body, Map<String, String>? params}) async {
    var u = Uri.parse(url);
    if (params != null && params.isNotEmpty) {
      u = u.replace(queryParameters: {...u.queryParameters, ...params});
    }
    final hdrs = Map<String, String>.from(headers ?? {});
    try {
      late http.Response resp;
      if (method == 'GET') resp = await http.get(u, headers: hdrs);
      else if (method == 'DELETE') resp = await http.delete(u, headers: hdrs);
      else if (method == 'PUT') resp = await http.put(u, headers: hdrs, body: body);
      else resp = await http.post(u, headers: hdrs, body: body);
      final parsed = _parseBody(resp.body);
      if (resp.statusCode >= 400) {
        return {'status_code': resp.statusCode, 'error': parsed ?? 'inaccessible'};
      }
      return {'status_code': resp.statusCode, 'body': parsed};
    } catch (e) {
      return CoreautoResult.transportError(e.toString());
    }
  }

  static Future<Map<String, dynamic>> Get(String url,
          {Map<String, String>? headers, Map<String, String>? params}) =>
      _request('GET', url, headers: headers, params: params);

  static Future<Map<String, dynamic>> Post(String url,
          {Object? jsonBody, String? data, Map<String, String>? headers}) async {
    final hdrs = Map<String, String>.from(headers ?? {});
    String? body;
    if (jsonBody != null) {
      hdrs.putIfAbsent('Content-Type', () => 'application/json');
      body = jsonEncode(jsonBody);
    } else if (data != null) body = data;
    return _request('POST', url, headers: hdrs, body: body);
  }

  static Future<Map<String, dynamic>> Put(String url,
          {Object? jsonBody, Map<String, String>? headers}) async {
    final hdrs = Map<String, String>.from(headers ?? {});
    String? body;
    if (jsonBody != null) {
      hdrs.putIfAbsent('Content-Type', () => 'application/json');
      body = jsonEncode(jsonBody);
    }
    return _request('PUT', url, headers: hdrs, body: body);
  }

  static Future<Map<String, dynamic>> Delete(String url,
          {Map<String, String>? headers}) =>
      _request('DELETE', url, headers: headers);
}
