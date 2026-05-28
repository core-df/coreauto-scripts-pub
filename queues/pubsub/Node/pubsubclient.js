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
// Google Cloud Pub/Sub helpers for Core Auto. Publish from step scripts; Pull for ingress bridges.

import { PubSub } from '@google-cloud/pubsub';
import { missingEnv, transportError } from './lib/result.js';

function projectId() {
  return process.env.PUBSUB_PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT || '';
}

function topicId(explicit) {
  return explicit || process.env.PUBSUB_TOPIC_ID || '';
}

function subscriptionId(explicit) {
  return explicit || process.env.PUBSUB_SUBSCRIPTION_ID || '';
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
  if (!projectId()) return missingEnv('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT');
  return { status_code: 200 };
}

export async function Publish(value, topic = null) {
  const project = projectId();
  const topicName = topicId(topic);
  if (!project) return missingEnv('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT');
  if (!topicName) return missingEnv('PUBSUB_TOPIC_ID');
  try {
    const pubsub = new PubSub({ projectId: project });
    const messageId = await pubsub.topic(topicName).publishMessage({ data: encode(value) });
    return { status_code: 200, message_id: messageId };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}

export async function Pull(subscription = null, maxMessages = 1, timeoutSec = 30, ack = true) {
  const project = projectId();
  const subName = subscriptionId(subscription);
  if (!project) return missingEnv('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT');
  if (!subName) return missingEnv('PUBSUB_SUBSCRIPTION_ID');
  try {
    const pubsub = new PubSub({ projectId: project });
    const [received] = await pubsub
      .subscription(subName)
      .pull({ maxMessages: Math.max(1, Math.min(maxMessages, 1000) });
    const messages = received.map((msg) => ({
      subscription: subName,
      message_id: msg.id,
      value: decode(msg.data),
    }));
    if (ack && received.length > 0) {
      await pubsub.subscription(subName).ack(received);
    }
    return { status_code: 200, messages };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}
