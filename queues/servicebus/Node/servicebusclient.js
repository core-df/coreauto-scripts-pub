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
// Azure Service Bus helpers for Core Auto. Send from step scripts; Receive for ingress bridges.

import { ServiceBusClient, ServiceBusMessage } from '@azure/service-bus';
import { missingEnv, transportError } from './lib/result.js';

function connectionString() {
  return process.env.SERVICE_BUS_CONNECTION_STRING || '';
}

function queueName(explicit) {
  return explicit || process.env.SERVICE_BUS_QUEUE_NAME || '';
}

function encode(value) {
  if (Buffer.isBuffer(value)) return value;
  if (typeof value === 'object') return Buffer.from(JSON.stringify(value));
  return Buffer.from(String(value));
}

function decode(raw) {
  const buf = Buffer.isBuffer(raw) ? raw : Buffer.concat(raw);
  const text = buf.toString('utf-8');
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export function Init() {
  if (!connectionString()) return missingEnv('SERVICE_BUS_CONNECTION_STRING');
  if (!process.env.SERVICE_BUS_QUEUE_NAME) {
    return missingEnv('SERVICE_BUS_QUEUE_NAME (or pass queue per call)');
  }
  return { status_code: 200 };
}

export async function Send(value, queue = null) {
  const conn = connectionString();
  const q = queueName(queue);
  if (!conn) return missingEnv('SERVICE_BUS_CONNECTION_STRING');
  if (!q) return missingEnv('SERVICE_BUS_QUEUE_NAME');
  try {
    const client = new ServiceBusClient(conn);
    const sender = client.createSender(q);
    await sender.sendMessages(new ServiceBusMessage(encode(value)));
    await sender.close();
    await client.close();
    return { status_code: 200 };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}

export async function Receive(queue = null, timeoutSec = 30, maxMessages = 1, complete = true) {
  const conn = connectionString();
  const q = queueName(queue);
  if (!conn) return missingEnv('SERVICE_BUS_CONNECTION_STRING');
  if (!q) return missingEnv('SERVICE_BUS_QUEUE_NAME');
  try {
    const client = new ServiceBusClient(conn);
    const receiver = client.createReceiver(q);
    const batch = await receiver.receiveMessages(Math.max(1, maxMessages), {
      maxWaitTimeInMs: timeoutSec * 1000,
    });
    const messages = batch.map((msg) => ({
      queue: q,
      message_id: msg.messageId ? String(msg.messageId) : null,
      value: decode(msg.body),
    }));
    if (complete) {
      for (const msg of batch) {
        await receiver.completeMessage(msg);
      }
    }
    await receiver.close();
    await client.close();
    return { status_code: 200, messages };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}
