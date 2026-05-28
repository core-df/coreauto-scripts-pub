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
// S3-compatible object storage helpers (AWS S3, MinIO, etc.).

import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  ListObjectsV2Command,
} from '@aws-sdk/client-s3';
import { missingEnv, transportError } from './lib/result.js';

function client() {
  const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'us-east-1';
  const config = { region };
  if (process.env.S3_ENDPOINT_URL) {
    config.endpoint = process.env.S3_ENDPOINT_URL;
    config.forcePathStyle = true;
  }
  return new S3Client(config);
}

function bucket(explicit) {
  return explicit || process.env.S3_BUCKET || '';
}

export function Init() {
  if (!process.env.AWS_ACCESS_KEY_ID && !process.env.AWS_PROFILE) {
    return missingEnv('AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE');
  }
  if (!process.env.S3_BUCKET) {
    return missingEnv('S3_BUCKET (or pass bucket per call)');
  }
  return { status_code: 200 };
}

export async function GetObject(key, bucketName = null) {
  const b = bucket(bucketName);
  if (!b) return missingEnv('S3_BUCKET');
  try {
    const resp = await client().send(new GetObjectCommand({ Bucket: b, Key: key }));
    const body = await resp.Body.transformToString();
    return { status_code: 200, content: body };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}

export async function PutObject(key, content, bucketName = null) {
  const b = bucket(bucketName);
  if (!b) return missingEnv('S3_BUCKET');
  try {
    await client().send(
      new PutObjectCommand({ Bucket: b, Key: key, Body: Buffer.from(content, 'utf-8') }),
    );
    return { status_code: 200 };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}

export async function ListObjects(prefix = '', bucketName = null) {
  const b = bucket(bucketName);
  if (!b) return missingEnv('S3_BUCKET');
  try {
    const resp = await client().send(
      new ListObjectsV2Command({ Bucket: b, Prefix: prefix }),
    );
    const keys = (resp.Contents || []).map((o) => o.Key);
    return { status_code: 200, keys };
  } catch (exc) {
    return transportError(String(exc.message || exc));
  }
}
