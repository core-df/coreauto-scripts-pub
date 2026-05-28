// Copyright (c) Core DF. All rights reserved.
//
// Documentation: https://coreauto.coredf.com/resources

import 'dart:io';
import 'wbs.dart';

final _sess = WbsSession();

String _env(String name) => Platform.environment[name] ?? '';

Future<WbsResult> init() async {
  final env = _env('ENV');
  final accessCode = _env('CA_ACCESS_CODE');
  final baseUrl = _env('CA_WBS_URL');
  if ([env, accessCode, baseUrl].any((v) => v.isEmpty)) {
    return WbsSession.missingEnv('ENV, CA_ACCESS_CODE, CA_WBS_URL');
  }
  return _sess.authenticate(env, accessCode, baseUrl);
}

Future<WbsResult> getKeystore(String keylist) => _sess.getKeystore(keylist);
