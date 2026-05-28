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
// RabbitMQ helpers for Core Auto. Publish from step scripts; Consume for ingress bridges.

import amqp from 'amqplib';
import { missingEnv, transportError } from './lib/result.js';

function connectionUrl() {
  if (process.env.RABBITMQ_URL) return process.env.RABBITMQ_URL;
  const host = process.env.RABBITMQ_HOST || '';
  if (!host) return '';
  const user = encodeURIComponent(process.env.RABBITMQ_USER || 'guest');
  const pass = encodeURIComponent(process.env.RABBITMQ_PASSWORD || 'guest');
  const port = process.env.RABBITMQ_PORT || '5672';
  const vhost = encodeURIComponent(process.env.RABBITMQ_VHOST || '/');
  return `amqp://${user}:${pass}@${host}:${port}/${vhost}`;
}

function encode(value) {
  if (Buffer.isBuffer(value)) return value;
  if (typeof value === 'object') return Buffer.from(JSON.stringify(value));
  return Buffer.from(String(value));
}

function decode(raw) {
  const text = raw.toString('utf-8');
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export function Init() {
  if (!connectionUrl()) return missingEnv('RABBITMQ_URL or RABBITMQ_HOST');
  return { status_code: 200 };
}

export async function Publish(queue, value, durable = true) {
  const url = connectionUrl();
  if (!url) return missingEnv('RABBITMQ_URL or RABBITMQ_HOST');
  try {
    const conn = await amqp.connect(url);
    const ch = await conn.createChannel();
    await ch.assertQueue(queue, { durable });
    ch.sendToQueue(queue, encode(value));
    await ch.close();
    await conn.close();
    return { status_code: 200 };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}

export async function Consume(queue, timeoutSec = 30, maxMessages = 1, autoAck = true, durable = true) {
  const url = connectionUrl();
  if (!url) return missingEnv('RABBITMQ_URL or RABBITMQ_HOST');
  const messages = [];
  try {
    const conn = await amqp.connect(url);
    const ch = await conn.createChannel();
    await ch.assertQueue(queue, { durable });
    let deadline = timeoutSec * 1000;
    while (messages.length < maxMessages && deadline > 0) {
      const msg = await ch.get(queue, { noAck: autoAck });
      if (!msg) {
        await new Promise((r) => setTimeout(r, 1000));
        deadline -= 1000;
        continue;
      }
      messages.push({ queue, delivery_tag: msg.fields.deliveryTag, value: decode(msg.content) });
      if (autoAck) ch.ack(msg);
    }
    await ch.close();
    await conn.close();
    return { status_code: 200, messages };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}
