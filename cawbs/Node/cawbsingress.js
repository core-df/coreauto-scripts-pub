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
// Core Auto Web Services — ingress client for the Core Auto Collector.
//
// Use outside step scripts (queue bridges, schedulers, file watchers) to submit
// events and flags that trigger Core Auto real-time or batch workflows.
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

export async function PostEvent(eventName, payload, eventSource) {
  return sess.postEvent(eventName, payload, eventSource);
}

export async function GetEventStatus(actionId) {
  return sess.getEventStatus(actionId);
}

export async function GetEventList() {
  return sess.getEventList();
}

export async function SubmitFlag(name, systemName, sourceSystemName, date) {
  return sess.submitFlag(name, systemName, sourceSystemName, date);
}

export async function GetKeystore(keylist) {
  return sess.getKeystore(keylist);
}
