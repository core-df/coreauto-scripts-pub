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
// Kafka helpers for Core Auto. Produce from step scripts; Consume for ingress bridges.

import { Kafka } from 'kafkajs';
import { missingEnv, transportError } from './lib/result.js';

function encode(value) {
  if (typeof value === 'object' && value !== null) return JSON.stringify(value);
  return String(value);
}

function decode(raw) {
  const text = raw.toString('utf-8');
  try { return JSON.parse(text); } catch { return text; }
}

function config() {
  const cfg = { brokers: (process.env.KAFKA_BOOTSTRAP_SERVERS || '').split(',') };
  if (process.env.KAFKA_SASL_USERNAME) {
    cfg.sasl = {
      mechanism: process.env.KAFKA_SASL_MECHANISM || 'plain',
      username: process.env.KAFKA_SASL_USERNAME,
      password: process.env.KAFKA_SASL_PASSWORD || '',
    };
    cfg.ssl = process.env.KAFKA_SECURITY_PROTOCOL?.includes('SSL') ?? false;
  }
  return cfg;
}

export function Init() {
  if (!process.env.KAFKA_BOOTSTRAP_SERVERS) return missingEnv('KAFKA_BOOTSTRAP_SERVERS');
  return { status_code: 200 };
}

export async function Produce(topic, value, key = null) {
  if (!process.env.KAFKA_BOOTSTRAP_SERVERS) return missingEnv('KAFKA_BOOTSTRAP_SERVERS');
  const kafka = new Kafka(config());
  const producer = kafka.producer();
  try {
    await producer.connect();
    await producer.send({
      topic,
      messages: [{ key: key ?? undefined, value: encode(value) }],
    });
    return { status_code: 200 };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  } finally {
    await producer.disconnect().catch(() => {});
  }
}

export async function Consume(topic, timeoutSec = 30, maxMessages = 1, groupId = null) {
  if (!process.env.KAFKA_BOOTSTRAP_SERVERS) return missingEnv('KAFKA_BOOTSTRAP_SERVERS');
  const kafka = new Kafka(config());
  const consumer = kafka.consumer({
    groupId: groupId || process.env.KAFKA_GROUP_ID || 'coreauto-step',
  });
  const messages = [];
  try {
    await consumer.connect();
    await consumer.subscribe({ topic, fromBeginning: true });
    await consumer.run({
      eachMessage: async ({ message }) => {
        messages.push({
          topic,
          partition: message.partition,
          offset: message.offset,
          key: message.key ? message.key.toString('utf-8') : null,
          value: decode(message.value),
        });
        if (messages.length >= maxMessages) await consumer.stop();
      },
    });
    await new Promise((r) => setTimeout(r, timeoutSec * 1000));
    await consumer.stop();
    return { status_code: 200, messages };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  } finally {
    await consumer.disconnect().catch(() => {});
  }
}
