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
// Notification helpers: Slack, Microsoft Teams, email, PagerDuty.

import nodemailer from 'nodemailer';
import { missingEnv, transportError } from './lib/result.js';

async function postJson(url, payload) {
  try {
    const resp = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const text = await resp.text();
    if (resp.status >= 400) {
      return { status_code: resp.status, error: text };
    }
    return { status_code: 200, raw: text };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}

export async function Slack(text, webhookUrl = null) {
  const url = webhookUrl || process.env.SLACK_WEBHOOK_URL || '';
  if (!url) return missingEnv('SLACK_WEBHOOK_URL');
  const result = await postJson(url, { text });
  if (result.status_code !== 200) return result;
  return { status_code: 200 };
}

export async function Teams(text, webhookUrl = null) {
  const url = webhookUrl || process.env.TEAMS_WEBHOOK_URL || '';
  if (!url) return missingEnv('TEAMS_WEBHOOK_URL');
  const payload = {
    '@type': 'MessageCard',
    '@context': 'http://schema.org/extensions',
    text,
  };
  const result = await postJson(url, payload);
  if (result.status_code !== 200) return result;
  return { status_code: 200 };
}

export async function Email(subject, body, toAddrs, fromAddr = null) {
  const host = process.env.SMTP_HOST || '';
  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const user = process.env.SMTP_USER || '';
  const password = process.env.SMTP_PASSWORD || '';
  const sender = fromAddr || process.env.SMTP_FROM || user;
  if (!host || !sender) {
    return missingEnv('SMTP_HOST and SMTP_FROM (or from_addr)');
  }
  try {
    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: user && password ? { user, pass: password } : undefined,
    });
    await transporter.sendMail({
      from: sender,
      to: toAddrs.split(',').map((a) => a.trim()),
      subject,
      text: body,
    });
    return { status_code: 200 };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}

export async function PagerDuty(summary, routingKey = null, severity = 'error') {
  const key = routingKey || process.env.PAGERDUTY_ROUTING_KEY || '';
  if (!key) return missingEnv('PAGERDUTY_ROUTING_KEY');
  const result = await postJson('https://events.pagerduty.com/v2/enqueue', {
    routing_key: key,
    event_action: 'trigger',
    payload: { summary, severity, source: 'coreauto-step' },
  });
  if (result.status_code !== 200) return result;
  try {
    return { status_code: 200, body: JSON.parse(result.raw || '{}') };
  } catch {
    return { status_code: 200 };
  }
}
