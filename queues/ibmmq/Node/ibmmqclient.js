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
// IBM MQ helpers for Core Auto. Put from step scripts; Get for ingress bridges.

import { missingEnv, transportError } from './lib/result.js';

function queueName(explicit) {
  return explicit || process.env.MQ_QUEUE || '';
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

async function loadMq() {
  try {
    return await import('ibmmq');
  } catch {
    return null;
  }
}

function connectOptions(mq) {
  const cno = new mq.MQCNO();
  const cd = new mq.MQCD();
  cd.ConnectionName = `${process.env.MQ_HOST}(${process.env.MQ_PORT || '1414'})`;
  cd.ChannelName = process.env.MQ_CHANNEL || 'SYSTEM.DEF.SVRCONN';
  cno.ClientConn = cd;
  if (process.env.MQ_USER) {
    const csp = new mq.MQCSP();
    csp.UserId = process.env.MQ_USER;
    csp.Password = process.env.MQ_PASSWORD || '';
    cno.SecurityParms = csp;
  }
  return cno;
}

export function Init() {
  if (!process.env.MQ_HOST || !process.env.MQ_QUEUE_MANAGER) {
    return missingEnv('MQ_HOST and MQ_QUEUE_MANAGER');
  }
  if (!process.env.MQ_QUEUE) {
    return missingEnv('MQ_QUEUE (or pass queue per call)');
  }
  return { status_code: 200 };
}

export async function Put(value, queue = null) {
  const qname = queueName(queue);
  if (!qname) return missingEnv('MQ_QUEUE');
  const mq = await loadMq();
  if (!mq) {
    return {
      status_code: 500,
      error: 'ibmmq package required (IBM MQ client libraries must be installed)',
    };
  }
  return new Promise((resolve) => {
    mq.Connx(process.env.MQ_QUEUE_MANAGER, connectOptions(mq), (err, hConn) => {
      if (err) return resolve(transportError(String(err)));
      mq.Open(hConn, qname, mq.MQC.MQOO_OUTPUT, (err2, hObj) => {
        if (err2) {
          mq.Disc(hConn, () => {});
          return resolve(transportError(String(err2)));
        }
        const msg = mq.MQMD();
        mq.Put(hObj, msg, encode(value), (err3) => {
          mq.Close(hObj, 0, () => {
            mq.Disc(hConn, () => {
              if (err3) resolve(transportError(String(err3)));
              else resolve({ status_code: 200 });
            });
          });
        });
      });
    });
  });
}

export async function Get(queue = null, timeoutSec = 30, maxMessages = 1) {
  const qname = queueName(queue);
  if (!qname) return missingEnv('MQ_QUEUE');
  const mq = await loadMq();
  if (!mq) {
    return {
      status_code: 500,
      error: 'ibmmq package required (IBM MQ client libraries must be installed)',
    };
  }
  const messages = [];
  return new Promise((resolve) => {
    mq.Connx(process.env.MQ_QUEUE_MANAGER, connectOptions(mq), (err, hConn) => {
      if (err) return resolve(transportError(String(err)));
      mq.Open(hConn, qname, mq.MQC.MQOO_INPUT_AS_Q_DEF, (err2, hObj) => {
        if (err2) {
          mq.Disc(hConn, () => {});
          return resolve(transportError(String(err2)));
        }
        const gmo = new mq.MQGMO();
        gmo.Options = mq.MQC.MQGMO_WAIT | mq.MQC.MQGMO_NO_SYNCPOINT;
        gmo.WaitInterval = Math.floor(timeoutSec * 1000);
        const pullNext = (remaining) => {
          if (remaining <= 0) {
            mq.Close(hObj, 0, () => mq.Disc(hConn, () => resolve({ status_code: 200, messages })));
            return;
          }
          mq.Get(hObj, new mq.MQMD(), gmo, (err3, _md, _gmo, data) => {
            if (err3) {
              if (err3.mqrc === mq.MQC.MQRC_NO_MSG_AVAILABLE) {
                mq.Close(hObj, 0, () => mq.Disc(hConn, () => resolve({ status_code: 200, messages })));
                return;
              }
              mq.Close(hObj, 0, () => mq.Disc(hConn, () => resolve(transportError(String(err3)))));
              return;
            }
            messages.push({ queue: qname, value: decode(data) });
            pullNext(remaining - 1);
          });
        };
        pullNext(Math.max(1, maxMessages));
      });
    });
  });
}
