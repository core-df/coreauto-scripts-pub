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
