// Copyright Core DF
//
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
// Queue ingress bridge — consume from a queue and submit Core Auto events via cawbsingress.

import { missingEnv } from './lib/result.js';

async function loadCawbsIngress() {
  const cawbsPath =
    process.env.CAWBS_NODE ||
    new URL('../../../cawbs/Node/cawbsingress.js', import.meta.url).href;
  return import(cawbsPath);
}

export async function TriggerEvent(payload, eventName = null, eventSource = null) {
  const name = eventName || process.env.CA_EVENT_NAME || '';
  if (!name) return missingEnv('CA_EVENT_NAME (or pass event_name)');

  const source =
    eventSource !== null && eventSource !== undefined
      ? eventSource
      : process.env.CA_EVENT_SOURCE || '';

  const cawbs = await loadCawbsIngress();
  const init = await cawbs.Init();
  if ((init.status_code || 0) >= 400) return init;

  const kwargs = { eventName: name, payload };
  if (source) kwargs.eventSource = source;
  return cawbs.PostEvent(kwargs.eventName, kwargs.payload, kwargs.eventSource);
}

export async function ForwardMessages(consumeResult) {
  if (consumeResult.status_code !== 200) return consumeResult;

  const forwarded = [];
  for (const msg of consumeResult.messages || []) {
    const value = msg.value !== undefined ? msg.value : msg;
    const result = await TriggerEvent(value);
    if ((result.status_code || 0) >= 400) return result;
    forwarded.push({ actionId: result.actionId, eventId: result.eventId });
  }
  return { status_code: 200, forwarded };
}

export async function RunBridge(consumeFn, ...args) {
  return ForwardMessages(await consumeFn(...args));
}
