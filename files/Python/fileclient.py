"""
Copyright Core DF

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Local file and SFTP helpers for Core Auto step scripts.
"""

import os
import shutil
from lib.result import transport_error


def LocalRead(path: str, encoding: str = "utf-8") -> dict:
    try:
        with open(path, "r", encoding=encoding) as fh:
            return {"status_code": 200, "content": fh.read()}
    except OSError as exc:
        return {"status_code": 500, "error": str(exc)}


def LocalWrite(path: str, content: str, encoding: str = "utf-8") -> dict:
    try:
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        with open(path, "w", encoding=encoding) as fh:
            fh.write(content)
        return {"status_code": 200}
    except OSError as exc:
        return {"status_code": 500, "error": str(exc)}


def LocalMove(src: str, dest: str) -> dict:
    try:
        shutil.move(src, dest)
        return {"status_code": 200}
    except OSError as exc:
        return {"status_code": 500, "error": str(exc)}


def _sftp_connect():
    import paramiko

    host = os.environ.get("SFTP_HOST", "")
    user = os.environ.get("SFTP_USER", "")
    password = os.environ.get("SFTP_PASSWORD", "")
    port = int(os.environ.get("SFTP_PORT", "22"))
    key_path = os.environ.get("SFTP_PRIVATE_KEY", "")

    if not host or not user:
        raise ValueError("SFTP_HOST and SFTP_USER required")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    if key_path:
        key = paramiko.RSAKey.from_private_key_file(key_path)
        client.connect(host, port=port, username=user, pkey=key, timeout=60)
    else:
        if not password:
            raise ValueError("SFTP_PASSWORD or SFTP_PRIVATE_KEY required")
        client.connect(host, port=port, username=user, password=password, timeout=60)
    return client, client.open_sftp()


def SftpGet(remote_path: str, local_path: str) -> dict:
    try:
        ssh, sftp = _sftp_connect()
        try:
            parent = os.path.dirname(local_path)
            if parent:
                os.makedirs(parent, exist_ok=True)
            sftp.get(remote_path, local_path)
        finally:
            sftp.close()
            ssh.close()
        return {"status_code": 200}
    except Exception as exc:
        return transport_error(str(exc))


def SftpPut(local_path: str, remote_path: str) -> dict:
    try:
        ssh, sftp = _sftp_connect()
        try:
            sftp.put(local_path, remote_path)
        finally:
            sftp.close()
            ssh.close()
        return {"status_code": 200}
    except Exception as exc:
        return transport_error(str(exc))


def SftpList(remote_dir: str = ".") -> dict:
    try:
        ssh, sftp = _sftp_connect()
        try:
            names = sftp.listdir(remote_dir)
        finally:
            sftp.close()
            ssh.close()
        return {"status_code": 200, "files": names}
    except Exception as exc:
        return transport_error(str(exc))
