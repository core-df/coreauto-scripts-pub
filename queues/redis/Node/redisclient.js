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
// Redis list helpers for Core Auto. Push from step scripts; Pop for ingress bridges.

import { createClient } from 'redis';
import { missingEnv, transportError } from './lib/result.js';

function connectionUrl() {
  if (process.env.REDIS_URL) return process.env.REDIS_URL;
  const host = process.env.REDIS_HOST || '';
  if (!host) return '';
  const port = process.env.REDIS_PORT || '6379';
  const password = process.env.REDIS_PASSWORD || '';
  const db = process.env.REDIS_DB || '0';
  return password
    ? `redis://:${password}@${host}:${port}/${db}`
    : `redis://${host}:${port}/${db}`;
}

function encode(v) {
  if (Buffer.isBuffer(v)) return v;
  if (typeof v === 'object') return JSON.stringify(v);
  return String(v);
}

function decode(raw) {
  const text = typeof raw === 'string' ? raw : raw.toString('utf-8');
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export function Init() {
  if (!connectionUrl()) return missingEnv('REDIS_URL or REDIS_HOST');
  return { status_code: 200 };
}

export async function Push(queue, value) {
  if (!connectionUrl()) return missingEnv('REDIS_URL or REDIS_HOST');
  const client = createClient({ url: connectionUrl() });
  try {
    await client.connect();
    await client.lPush(queue, encode(value));
    return { status_code: 200 };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  } finally {
    await client.quit().catch(() => {});
  }
}

export async function Pop(queue, timeoutSec = 30, maxMessages = 1) {
  if (!connectionUrl()) return missingEnv('REDIS_URL or REDIS_HOST');
  const client = createClient({ url: connectionUrl() });
  const messages = [];
  try {
    await client.connect();
    let remaining = Math.max(1, maxMessages);
    let deadline = timeoutSec;
    while (remaining > 0) {
      const wait = remaining === maxMessages ? Math.max(1, Math.floor(deadline)) : 1;
      const item = await client.brPop(queue, wait);
      if (!item) break;
      messages.push({ queue, value: decode(item.element) });
      remaining -= 1;
      deadline -= wait;
      if (deadline <= 0) break;
    }
    return { status_code: 200, messages };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  } finally {
    await client.quit().catch(() => {});
  }
}
