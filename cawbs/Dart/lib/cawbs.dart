// Copyright (c) Core DF. All rights reserved.
//
// Documentation: https://coreauto.coredf.com/resources

import 'dart:io';
import 'wbs.dart';

final _sess = WbsSession();

String _env(String name) => Platform.environment[name] ?? '';

Future<WbsResult> init() async {
  final env = _env('ENV');
  final actionId = _env('ACTIONID');
  final accessCode = _env('CA_ACCESS_CODE');
  final baseUrl = _env('CA_WBS_URL');
  final stepName = _env('STEPNAME');
  if ([env, actionId, accessCode, baseUrl, stepName].any((v) => v.isEmpty)) {
    return WbsSession.missingEnv('ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME');
  }
  return _sess.authenticate(env, accessCode, baseUrl);
}

Future<WbsResult> getEventPayload() => _sess.getEventPayload(_env('ACTIONID'));

Future<WbsResult> putStepPayload(dynamic payload) =>
    _sess.putStepPayload(_env('ACTIONID'), _env('STEPNAME'), payload);

Future<WbsResult> getStepPayload(String stepname) =>
    _sess.getStepPayload(_env('ACTIONID'), stepname);

Future<WbsResult> getKeystore(String keylist) => _sess.getKeystore(keylist);
