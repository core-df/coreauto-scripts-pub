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
// Generic HTTP client helpers for Core Auto step scripts (non-Collector REST calls).

import { transportError } from './lib/result.js';

function parseBody(text) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function request(method, url, headers = {}, body) {
  const init = { method, headers: { ...headers } };
  if (body !== undefined) {
    init.body = typeof body === 'string' ? body : JSON.stringify(body);
  }
  let resp;
  try {
    resp = await fetch(url, init);
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
  const text = await resp.text();
  const parsed = parseBody(text);
  if (resp.status >= 400) {
    return { status_code: resp.status, error: parsed ?? 'inaccessible' };
  }
  return { status_code: resp.status, body: parsed };
}

export async function Get(url, headers = null, params = null) {
  let target = url;
  if (params) {
    const qs = new URLSearchParams(params).toString();
    target = qs ? `${url}?${qs}` : url;
  }
  return request('GET', target, headers ?? {});
}

export async function Post(url, jsonBody = null, data = null, headers = null) {
  const hdrs = { ...(headers ?? {}) };
  if (jsonBody !== null && jsonBody !== undefined && !('Content-Type' in hdrs)) {
    hdrs['Content-Type'] = 'application/json';
  }
  const body = jsonBody !== null && jsonBody !== undefined ? jsonBody : data;
  return request('POST', url, hdrs, body);
}

export async function Put(url, jsonBody = null, headers = null) {
  const hdrs = { ...(headers ?? {}) };
  if (jsonBody !== null && jsonBody !== undefined && !('Content-Type' in hdrs)) {
    hdrs['Content-Type'] = 'application/json';
  }
  return request('PUT', url, hdrs, jsonBody);
}

export async function Delete(url, headers = null) {
  return request('DELETE', url, headers ?? {});
}
