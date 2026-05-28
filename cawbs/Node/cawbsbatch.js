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
// Batch-oriented cawbs client for the Core Auto Collector.
//
// Documentation: https://coreauto.coredf.com/resources

import { missingEnv, Session } from './lib/wbs.js';

const sess = new Session();
const env = process.env.ENV;
const accessCode = process.env.CA_ACCESS_CODE;
const baseURL = process.env.CA_WBS_URL;

export async function Init() {
  if (!env || !accessCode || !baseURL) {
    return missingEnv('ENV, CA_ACCESS_CODE, CA_WBS_URL');
  }
  return sess.authenticate(env, accessCode, baseURL);
}

export async function GetKeystore(keylist) {
  return sess.getKeystore(keylist);
}
