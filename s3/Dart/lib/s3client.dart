// Copyright Core DF — Apache License 2.0
import 'dart:convert';
import 'dart:io';

import 'package:minio/minio.dart';

import 'result.dart';

class S3client {
  static String _env(String key, [String fallback = '']) {
    final value = Platform.environment[key] ?? '';
    return value.isEmpty ? fallback : value;
  }

  static String _bucket(String? explicit) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _env('S3_BUCKET');
  }

  static Minio _client() {
    final accessKey = _env('AWS_ACCESS_KEY_ID');
    final secretKey = _env('AWS_SECRET_ACCESS_KEY');
    final region = _env('AWS_REGION', _env('AWS_DEFAULT_REGION', 'us-east-1'));
    final endpoint = _env('S3_ENDPOINT_URL');

    if (endpoint.isNotEmpty) {
      final uri = Uri.parse(endpoint);
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      return Minio(
        endPoint: uri.host,
        port: port,
        accessKey: accessKey,
        secretKey: secretKey,
        useSSL: uri.scheme == 'https',
        region: region,
      );
    }

    return Minio(
      endPoint: 's3.$region.amazonaws.com',
      accessKey: accessKey,
      secretKey: secretKey,
      useSSL: true,
      region: region,
    );
  }

  static Map<String, dynamic> Init() {
    if (_env('AWS_ACCESS_KEY_ID').isEmpty && _env('AWS_PROFILE').isEmpty) {
      return CoreautoResult.missingEnv('AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE');
    }
    if (_env('S3_BUCKET').isEmpty) {
      return CoreautoResult.missingEnv('S3_BUCKET (or pass bucket per call)');
    }
    return {'status_code': 200};
  }

  static Future<Map<String, dynamic>> GetObject(String key, [String? bucketName]) async {
    final b = _bucket(bucketName);
    if (b.isEmpty) return CoreautoResult.missingEnv('S3_BUCKET');
    try {
      final stream = await _client().getObject(b, key);
      final chunks = <int>[];
      await for (final chunk in stream) {
        chunks.addAll(chunk);
      }
      final content = utf8.decode(chunks, allowMalformed: true);
      return {'status_code': 200, 'content': content};
    } catch (e) {
      return CoreautoResult.transportError(e.toString());
    }
  }

  static Future<Map<String, dynamic>> PutObject(String key, String content, [String? bucketName]) async {
    final b = _bucket(bucketName);
    if (b.isEmpty) return CoreautoResult.missingEnv('S3_BUCKET');
    try {
      await _client().putObject(b, key, Stream.value(utf8.encode(content)), size: utf8.encode(content).length);
      return {'status_code': 200};
    } catch (e) {
      return CoreautoResult.transportError(e.toString());
    }
  }

  static Future<Map<String, dynamic>> ListObjects([String prefix = '', String? bucketName]) async {
    final b = _bucket(bucketName);
    if (b.isEmpty) return CoreautoResult.missingEnv('S3_BUCKET');
    try {
      final keys = <String>[];
      await for (final item in _client().listObjectsV2(b, prefix: prefix)) {
        keys.add(item.key ?? '');
      }
      return {'status_code': 200, 'keys': keys.where((k) => k.isNotEmpty).toList()};
    } catch (e) {
      return CoreautoResult.transportError(e.toString());
    }
  }
}
