// Copyright Core DF — Apache License 2.0
import 'dart:convert';
import 'dart:io';

import 'result.dart';

class Fileclient {
  static Map<String, dynamic> LocalRead(String path, {String encoding = 'utf-8'}) {
    if (encoding.toLowerCase() != 'utf-8') {
      return {'status_code': 500, 'error': 'unsupported encoding: $encoding'};
    }
    try {
      final content = File(path).readAsStringSync(encoding: utf8);
      return {'status_code': 200, 'content': content};
    } catch (e) {
      return {'status_code': 500, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> LocalWrite(String path, String content, {String encoding = 'utf-8'}) {
    if (encoding.toLowerCase() != 'utf-8') {
      return {'status_code': 500, 'error': 'unsupported encoding: $encoding'};
    }
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content, encoding: utf8);
      return {'status_code': 200};
    } catch (e) {
      return {'status_code': 500, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> LocalMove(String src, String dest) {
    try {
      File(src).renameSync(dest);
      return {'status_code': 200};
    } catch (e) {
      return {'status_code': 500, 'error': e.toString()};
    }
  }
}
