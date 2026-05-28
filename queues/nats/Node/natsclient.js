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
// NATS helpers for Core Auto. Publish from step scripts; Subscribe for ingress bridges.

import { connect, StringCodec } from 'nats';
import { missingEnv, transportError } from './lib/result.js';

const sc = StringCodec();

function servers() {
  return process.env.NATS_URL || process.env.NATS_SERVERS || '';
}

function encode(value) {
  if (typeof value === 'object') return sc.encode(JSON.stringify(value));
  return sc.encode(String(value));
}

function decode(raw) {
  const text = sc.decode(raw);
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export function Init() {
  if (!servers()) return missingEnv('NATS_URL or NATS_SERVERS');
  return { status_code: 200 };
}

export async function Publish(subject, value) {
  if (!servers()) return missingEnv('NATS_URL or NATS_SERVERS');
  let nc;
  try {
    nc = await connect({ servers: servers().split(',') });
    nc.publish(subject, encode(value));
    await nc.flush();
    return { status_code: 200 };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  } finally {
    await nc?.drain().catch(() => {});
  }
}

export async function Subscribe(subject, timeoutSec = 30, maxMessages = 1) {
  if (!servers()) return missingEnv('NATS_URL or NATS_SERVERS');
  let nc;
  const messages = [];
  try {
    nc = await connect({ servers: servers().split(',') });
    const sub = nc.subscribe(subject);
    let deadline = timeoutSec * 1000;
    for await (const msg of sub) {
      messages.push({ subject: msg.subject, value: decode(msg.data) });
      if (messages.length >= maxMessages) break;
      deadline -= 100;
      if (deadline <= 0) break;
    }
    return { status_code: 200, messages };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  } finally {
    await nc?.drain().catch(() => {});
  }
}
