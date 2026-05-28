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
// Local file and SFTP helpers for Core Auto step scripts.

import fs from 'node:fs/promises';
import path from 'node:path';
import { missingEnv, transportError } from './lib/result.js';

async function sftpConnect() {
  let SftpClient;
  try {
    ({ default: SftpClient } = await import('ssh2-sftp-client'));
  } catch {
    return { error: { status_code: 500, error: 'ssh2-sftp-client package required for SFTP' } };
  }

  const host = process.env.SFTP_HOST || '';
  const user = process.env.SFTP_USER || '';
  const password = process.env.SFTP_PASSWORD || '';
  const port = parseInt(process.env.SFTP_PORT || '22', 10);
  const keyPath = process.env.SFTP_PRIVATE_KEY || '';

  if (!host || !user) {
    return { error: missingEnv('SFTP_HOST and SFTP_USER') };
  }

  const sftp = new SftpClient();
  const config = { host, port, username: user };
  if (keyPath) {
    config.privateKey = await fs.readFile(keyPath);
  } else if (password) {
    config.password = password;
  } else {
    return { error: missingEnv('SFTP_PASSWORD or SFTP_PRIVATE_KEY') };
  }

  try {
    await sftp.connect(config);
    return { sftp };
  } catch (exc) {
    return { error: transportError(String(exc.message || exc)) };
  }
}

export async function LocalRead(filePath, encoding = 'utf-8') {
  try {
    const content = await fs.readFile(filePath, encoding);
    return { status_code: 200, content };
  } catch (exc) {
    return { status_code: 500, error: String(exc.message) };
  }
}

export async function LocalWrite(filePath, content, encoding = 'utf-8') {
  try {
    await fs.mkdir(path.dirname(filePath), { recursive: true });
    await fs.writeFile(filePath, content, encoding);
    return { status_code: 200 };
  } catch (exc) {
    return { status_code: 500, error: String(exc.message) };
  }
}

export async function LocalMove(src, dest) {
  try {
    await fs.rename(src, dest);
    return { status_code: 200 };
  } catch (exc) {
    return { status_code: 500, error: String(exc.message) };
  }
}

export async function SftpGet(remotePath, localPath) {
  const conn = await sftpConnect();
  if (conn.error) return conn.error;
  try {
    await fs.mkdir(path.dirname(localPath), { recursive: true });
    await conn.sftp.fastGet(remotePath, localPath);
    await conn.sftp.end();
    return { status_code: 200 };
  } catch (exc) {
    await conn.sftp.end().catch(() => {});
    return transportError(String(exc.message || exc));
  }
}

export async function SftpPut(localPath, remotePath) {
  const conn = await sftpConnect();
  if (conn.error) return conn.error;
  try {
    await conn.sftp.fastPut(localPath, remotePath);
    await conn.sftp.end();
    return { status_code: 200 };
  } catch (exc) {
    await conn.sftp.end().catch(() => {});
    return transportError(String(exc.message || exc));
  }
}

export async function SftpList(remoteDir = '.') {
  const conn = await sftpConnect();
  if (conn.error) return conn.error;
  try {
    const files = await conn.sftp.list(remoteDir);
    await conn.sftp.end();
    return { status_code: 200, files: files.map((f) => f.name) };
  } catch (exc) {
    await conn.sftp.end().catch(() => {});
    return transportError(String(exc.message || exc));
  }
}
