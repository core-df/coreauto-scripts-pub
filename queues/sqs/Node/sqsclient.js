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
// Amazon SQS helpers for Core Auto. Send from step scripts; Receive for ingress bridges.

import {
  SQSClient,
  SendMessageCommand,
  ReceiveMessageCommand,
  DeleteMessageCommand,
} from '@aws-sdk/client-sqs';
import { missingEnv, transportError } from './lib/result.js';

function client() {
  const cfg = { region: process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'us-east-1' };
  if (process.env.SQS_ENDPOINT_URL) cfg.endpoint = process.env.SQS_ENDPOINT_URL;
  return new SQSClient(cfg);
}

function queueUrl(explicit) {
  return explicit || process.env.SQS_QUEUE_URL || '';
}

function encode(v) {
  return typeof v === 'string' ? v : JSON.stringify(v);
}

function decode(raw) {
  try {
    return JSON.parse(raw);
  } catch {
    return raw;
  }
}

export function Init() {
  if (!process.env.AWS_ACCESS_KEY_ID && !process.env.AWS_PROFILE) {
    return missingEnv('AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE');
  }
  if (!process.env.SQS_QUEUE_URL) {
    return missingEnv('SQS_QUEUE_URL (or pass queue_url per call)');
  }
  return { status_code: 200 };
}

export async function Send(value, queueUrlArg = null) {
  const url = queueUrl(queueUrlArg);
  if (!url) return missingEnv('SQS_QUEUE_URL');
  try {
    const resp = await client().send(
      new SendMessageCommand({ QueueUrl: url, MessageBody: encode(value) }),
    );
    return { status_code: 200, message_id: resp.MessageId };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}

export async function Receive(queueUrlArg = null, maxMessages = 1, waitTimeSec = 10, deleteMsg = true) {
  const url = queueUrl(queueUrlArg);
  if (!url) return missingEnv('SQS_QUEUE_URL');
  try {
    const resp = await client().send(
      new ReceiveMessageCommand({
        QueueUrl: url,
        MaxNumberOfMessages: Math.min(Math.max(maxMessages, 1), 10),
        WaitTimeSeconds: waitTimeSec,
      }),
    );
    const messages = [];
    for (const item of resp.Messages || []) {
      messages.push({
        message_id: item.MessageId,
        receipt_handle: item.ReceiptHandle,
        value: decode(item.Body || ''),
      });
      if (deleteMsg && item.ReceiptHandle) {
        await client().send(
          new DeleteMessageCommand({ QueueUrl: url, ReceiptHandle: item.ReceiptHandle }),
        );
      }
    }
    return { status_code: 200, messages };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}
