// Copyright Core DF

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Shared HTTP helpers for the Core Auto Collector (cawbs) Dart client.

import 'dart:convert';
import 'package:http/http.dart' as http;

class WbsResult {
  final int statusCode;
  final dynamic error;
  final dynamic payload;
  final Map<String, dynamic>? answer;

  WbsResult({
    required this.statusCode,
    this.error,
    this.payload,
    this.answer,
  });

  Map<String, dynamic> toMap() => {
        'status_code': statusCode,
        if (error != null) 'error': error,
        if (payload != null) 'payload': payload,
        if (answer != null) 'answer': answer,
      };
}

class WbsSession {
  bool _initialized = false;
  String _baseUrl = '';
  String _env = '';
  String _token = '';

  static WbsResult missingEnv(String vars) => WbsResult(
        statusCode: 601,
        error: 'Environment variables $vars should be defined',
      );

  String _trimUrl(String url) => url.replaceAll(RegExp(r'^[/ ]+|[/ ]+$'), '');

  Future<({int statusCode, dynamic body, bool transportError})> _request(
    String method,
    String url, {
    String? body,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Environment': _env,
    };
    if (_token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    try {
      late http.Response resp;
      if (method == 'GET') {
        resp = await http.get(Uri.parse(url), headers: headers);
      } else {
        resp = await http.post(Uri.parse(url), headers: headers, body: body);
      }
      dynamic parsed;
      if (resp.body.isNotEmpty) {
        try {
          parsed = jsonDecode(resp.body);
        } catch (_) {
          parsed = null;
        }
      }
      return (statusCode: resp.statusCode, body: parsed, transportError: false);
    } catch (_) {
      return (statusCode: 0, body: null, transportError: true);
    }
  }

  WbsResult _apiError(int statusCode, dynamic body) => WbsResult(
        statusCode: statusCode,
        error: body ?? 'inaccessible',
      );

  Future<WbsResult> authenticate(String env, String accessCode, String baseUrl) async {
    if (_initialized) {
      return WbsResult(statusCode: 602, error: 'init already called');
    }
    _env = env;
    _baseUrl = _trimUrl(baseUrl);
    final out = await _request(
      'POST',
      '$_baseUrl/v1/auth/apicode',
      body: jsonEncode({'apiCode': accessCode}),
    );
    if (out.transportError) {
      return WbsResult(statusCode: out.statusCode, error: 'inaccessible');
    }
    if (out.statusCode >= 400) return _apiError(out.statusCode, out.body);
    final token = (out.body as Map?)?['token'];
    if (token is! String || token.isEmpty) {
      return WbsResult(statusCode: out.statusCode, error: 'inaccessible');
    }
    _token = token;
    _initialized = true;
    return WbsResult(statusCode: out.statusCode);
  }

  Future<WbsResult> getEventPayload(String actionId) async {
    if (!_initialized) return WbsResult(statusCode: 603, error: 'Init required');
    final out = await _request('GET', '$_baseUrl/v1/rtevent/$actionId');
    if (out.transportError) return WbsResult(statusCode: out.statusCode, error: 'inaccessible');
    if (out.statusCode >= 400) return _apiError(out.statusCode, out.body);
    if (out.body is! Map) return WbsResult(statusCode: out.statusCode, error: 'inaccessible');
    return WbsResult(statusCode: out.statusCode, payload: out.body['payload']);
  }

  Future<WbsResult> putStepPayload(String actionId, String stepName, dynamic payload) async {
    if (!_initialized) return WbsResult(statusCode: 603, error: 'Init required');
    final out = await _request(
      'POST',
      '$_baseUrl/v1/rtstep/payload',
      body: jsonEncode({'actionId': actionId, 'stepname': stepName, 'payload': payload}),
    );
    if (out.transportError) return WbsResult(statusCode: out.statusCode, error: 'inaccessible');
    if (out.statusCode >= 400) return _apiError(out.statusCode, out.body);
    return WbsResult(statusCode: out.statusCode);
  }

  Future<WbsResult> getStepPayload(String actionId, String stepName) async {
    if (!_initialized) return WbsResult(statusCode: 603, error: 'Init required');
    final out = await _request('GET', '$_baseUrl/v1/rtstep/payload/$actionId/$stepName');
    if (out.transportError) return WbsResult(statusCode: out.statusCode, error: 'inaccessible');
    if (out.statusCode >= 400) return _apiError(out.statusCode, out.body);
    if (out.body is! Map) return WbsResult(statusCode: out.statusCode, error: 'inaccessible');
    return WbsResult(statusCode: out.statusCode, payload: out.body['payload']);
  }

  Future<WbsResult> getKeystore(String keylist) async {
    if (!_initialized) return WbsResult(statusCode: 603, error: 'Init required');
    final keys = keylist.replaceAll(' ', '');
    final out = await _request('GET', '$_baseUrl/v1/keystore/$keys');
    if (out.transportError) return WbsResult(statusCode: out.statusCode, error: 'inaccessible');
    if (out.statusCode >= 400) return _apiError(out.statusCode, out.body);
    if (out.body is! Map<String, dynamic>) {
      return WbsResult(statusCode: out.statusCode, error: 'inaccessible');
    }
    for (final key in keys.split(',')) {
      if (key.isEmpty) continue;
      if (!out.body.containsKey(key)) {
        return WbsResult(statusCode: 605, error: '$key not found');
      }
    }
    return WbsResult(statusCode: out.statusCode, answer: Map<String, dynamic>.from(out.body));
  }
}
