// Copyright Core DF

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
// Shared HTTP helpers for the Core Auto Collector (cawbs) Node.js client.

export function missingEnv(vars) {
  return {
    status_code: 601,
    error: `Environment variables ${vars} should be defined`,
  };
}

function trimURL(url) {
  return url.replace(/^[/ ]+|[/ ]+$/g, '');
}

async function doRequest(method, url, headers, body) {
  const init = { method, headers: { ...headers } };
  if (body !== undefined) {
    init.body = body;
  }
  let resp;
  try {
    resp = await fetch(url, init);
  } catch {
    return { statusCode: 0, body: null, transportError: true };
  }
  const text = await resp.text();
  let parsed = null;
  if (text) {
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = null;
    }
  }
  return { statusCode: resp.status, body: parsed, raw: text };
}

function apiError(statusCode, body, raw) {
  if (body === null) {
    return { status_code: statusCode, error: 'inaccessible' };
  }
  return { status_code: statusCode, error: body };
}

export class Session {
  constructor() {
    this.initialized = false;
    this.baseURL = '';
    this.headers = {};
  }

  async authenticate(env, accessCode, baseURL) {
    if (this.initialized) {
      return { status_code: 602, error: 'init already called' };
    }

    this.baseURL = trimURL(baseURL);
    const headers = {
      'Content-Type': 'application/json',
      Environment: env,
    };
    const { statusCode, body, transportError } = await doRequest(
      'POST',
      `${this.baseURL}/v1/auth/apicode`,
      headers,
      JSON.stringify({ apiCode: accessCode }),
    );
    if (transportError) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    if (statusCode >= 400) {
      return apiError(statusCode, body);
    }
    if (!body || !body.token) {
      return { status_code: statusCode, error: 'inaccessible' };
    }

    this.headers = {
      ...headers,
      Authorization: `Bearer ${body.token}`,
    };
    this.initialized = true;
    return { status_code: statusCode };
  }

  async getEventPayload(actionID) {
    if (!this.initialized) {
      return { status_code: 603, error: 'Init required' };
    }
    const { statusCode, body, transportError } = await doRequest(
      'GET',
      `${this.baseURL}/v1/rtevent/${actionID}`,
      this.headers,
    );
    if (transportError) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    if (statusCode >= 400) {
      return apiError(statusCode, body);
    }
    if (body === null) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    return { status_code: statusCode, payload: body.payload };
  }

  async putStepPayload(actionID, stepName, payload) {
    if (!this.initialized) {
      return { status_code: 603, error: 'Init required' };
    }
    const { statusCode, body, transportError } = await doRequest(
      'POST',
      `${this.baseURL}/v1/rtstep/payload`,
      this.headers,
      JSON.stringify({ actionId: actionID, stepname: stepName, payload }),
    );
    if (transportError) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    if (statusCode >= 400) {
      return apiError(statusCode, body);
    }
    return { status_code: statusCode };
  }

  async getStepPayload(actionID, stepName) {
    if (!this.initialized) {
      return { status_code: 603, error: 'Init required' };
    }
    const { statusCode, body, transportError } = await doRequest(
      'GET',
      `${this.baseURL}/v1/rtstep/payload/${actionID}/${stepName}`,
      this.headers,
    );
    if (transportError) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    if (statusCode >= 400) {
      return apiError(statusCode, body);
    }
    if (body === null) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    return { status_code: statusCode, payload: body.payload };
  }

  async postEvent(eventName, payload, eventSource) {
    if (!this.initialized) {
      return { status_code: 603, error: 'Init required' };
    }
    const body = { eventName, payload };
    if (eventSource !== undefined && eventSource !== null) {
      body.eventSource = eventSource;
    }
    const { statusCode, body: respBody, transportError } = await doRequest(
      'POST',
      `${this.baseURL}/v1/rtevent`,
      this.headers,
      JSON.stringify(body),
    );
    if (transportError) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    if (statusCode >= 400) {
      return apiError(statusCode, respBody);
    }
    if (respBody === null) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    return {
      status_code: statusCode,
      eventId: respBody.eventId,
      actionId: respBody.actionId,
      createdAt: respBody.createdAt,
    };
  }

  async getEventStatus(actionId) {
    if (!this.initialized) {
      return { status_code: 603, error: 'Init required' };
    }
    const { statusCode, body, transportError } = await doRequest(
      'GET',
      `${this.baseURL}/v1/rtevent/status/${actionId}`,
      this.headers,
    );
    if (transportError) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    if (statusCode >= 400) {
      return apiError(statusCode, body);
    }
    if (body === null) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    return { status_code: statusCode, status: body };
  }

  async getEventList() {
    if (!this.initialized) {
      return { status_code: 603, error: 'Init required' };
    }
    const { statusCode, body, transportError } = await doRequest(
      'GET',
      `${this.baseURL}/v1/rtevent/list`,
      this.headers,
    );
    if (transportError) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    if (statusCode >= 400) {
      return apiError(statusCode, body);
    }
    if (body === null) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    return { status_code: statusCode, events: body };
  }

  async submitFlag(name, systemName, sourceSystemName, date) {
    if (!this.initialized) {
      return { status_code: 603, error: 'Init required' };
    }
    const { statusCode, body, transportError } = await doRequest(
      'POST',
      `${this.baseURL}/v1/flag`,
      this.headers,
      JSON.stringify({ name, systemName, sourceSystemName, date }),
    );
    if (transportError) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    if (statusCode >= 400) {
      return apiError(statusCode, body);
    }
    if (body === null) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    return { status_code: statusCode, flagStatus: body.status };
  }

  async getKeystore(keylist) {
    if (!this.initialized) {
      return { status_code: 603, error: 'Init required' };
    }
    const keys = keylist.replace(/ /g, '');
    const { statusCode, body, transportError } = await doRequest(
      'GET',
      `${this.baseURL}/v1/keystore/${keys}`,
      this.headers,
    );
    if (transportError) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    if (statusCode >= 400) {
      return apiError(statusCode, body);
    }
    if (body === null) {
      return { status_code: statusCode, error: 'inaccessible' };
    }
    for (const key of keys.split(',')) {
      if (key && !(key in body)) {
        return { status_code: 605, error: `${key} not found` };
      }
    }
    return { status_code: statusCode, answer: body };
  }
}
