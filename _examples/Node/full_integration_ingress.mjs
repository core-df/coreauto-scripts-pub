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
// Kafka ingress bridge — Node.js port.

import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(fileURLToPath(new URL('.', import.meta.url)), '../..');
const ingress = await import(join(ROOT, 'queues/ingress/Node/ingress.js'));
const kafka = await import(join(ROOT, 'queues/kafka/Node/kafkaclient.js'));

const topic = process.argv[2] ?? process.env.EXAMPLE_KAFKA_TOPIC ?? 'orders.inbound';
console.error(`Bridging Kafka topic ${topic} → Core Auto`);

while (true) {
  const result = await ingress.RunBridge(
    () => kafka.Consume(topic, { max_messages: 10 }),
  );
  const code = result?.status_code ?? 0;
  if (code >= 400 || code === 0) {
    console.error(JSON.stringify(result));
    await new Promise((r) => setTimeout(r, 5000));
    continue;
  }
  if (result.forwarded?.length) console.log(JSON.stringify({ forwarded: result.forwarded }));
}
