#!/usr/bin/env node
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
// Core Auto real-time step — full integration example (Node.js port).

import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '../..');
const load = async (rel) => import(join(ROOT, rel));

const cawbs = await load('cawbs/Node/cawbs.js');
const files = await load('files/Node/fileclient.js');
const transform = await load('transform/Node/transformclient.js');
const kafka = await load('queues/kafka/Node/kafkaclient.js');
const rabbit = await load('queues/rabbit/Node/rabbitclient.js');
const sqs = await load('queues/sqs/Node/sqsclient.js');
const redis = await load('queues/redis/Node/redisclient.js');

function fail(result, label) {
  console.error(JSON.stringify({ step: label, error: result }, null, 2));
  process.exit(1);
}

function ok(result, label) {
  const code = result?.status_code ?? 0;
  if (code >= 400 || code === 0) fail(result, label);
  return result;
}

async function optional(label, fn) {
  const result = await fn();
  const code = result?.status_code ?? 0;
  const err = String(result?.error ?? '').toLowerCase();
  if ([601, 500].includes(code) && err.includes('missing')) {
    console.log(`[skip] ${label}: not configured`);
    return null;
  }
  if (code >= 400 || code === 0) {
    console.log(`[warn] ${label}:`, result?.error ?? result);
    return null;
  }
  console.log(`[ok] ${label}`);
  return result;
}

async function loadInput(event) {
  const order = { ...(event.payload ?? event) };
  const orderId = order.orderId ?? order.id ?? 'unknown';
  const csvPath = order.csvPath ?? process.env.EXAMPLE_CSV_PATH ?? '';
  if (csvPath) {
    const raw = ok(await files.LocalRead(csvPath), 'files.LocalRead');
    const rows = ok(await transform.CsvToRows(raw.content), 'transform.CsvToRows');
    if (rows.rows?.length) order.lineItems = rows.rows;
  }
  return { orderId, details: order };
}

async function publishAll(order) {
  const published = [];
  const topic = process.env.EXAMPLE_KAFKA_TOPIC ?? 'orders.enriched';
  const queue = process.env.EXAMPLE_QUEUE_NAME ?? 'orders';
  const backends = [
    ['kafka', () => kafka.Produce(topic, order)],
    ['rabbit', () => rabbit.Publish(queue, order)],
    ['sqs', () => sqs.Send(order)],
    ['redis', () => redis.Push(queue, order)],
  ];
  for (const [name, fn] of backends) {
    if (await optional(`queues.${name}`, fn)) published.push(name);
  }
  return published;
}

ok(await cawbs.Init(), 'cawbs.Init');
const event = ok(await cawbs.GetEventPayload(), 'cawbs.GetEventPayload');
const order = await loadInput(event);
const ackDir = process.env.EXAMPLE_ACK_DIR ?? '/tmp/coreauto-example';
mkdirSync(ackDir, { recursive: true });
const ackPath = join(ackDir, `${order.orderId}.json`);
const ackText = ok(await transform.JsonStringify(order), 'transform.JsonStringify(ack)');
ok(await files.LocalWrite(ackPath, ackText.text), 'files.LocalWrite');
const published = await publishAll(order);
const output = { orderId: order.orderId, queuesPublished: published, ackPath };
ok(await cawbs.PutStepPayload(output), 'cawbs.PutStepPayload');
console.log(JSON.stringify({ status_code: 200, result: output }, null, 2));
